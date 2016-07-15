// -----------------------------------------------------------------------------
// sidestick.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "nandos/printk.h"
#include "nandos/wait.h"
#include "nandos/io.h"
#include "nandos/cdev.h"

// ---------------------------------------------------------

class DeviceListener
{
	uint inode;
	file openFile;
	bool bPendingData;

	DeviceListener()
	{
	}
	
	DeviceListener(uint i, file &in f)
	{
		inode = i;
		openFile = f;
		bPendingData = true;
	}
}

namespace Shared
{
	// Device Id this driver instance is handling
	uint8 deviceId = 0;

	// Whether we have data to process by the second handler
	bool bInterruptData = false;
	
	// Character device inode
	uint charInode = 0;
	
	// Application PIDs reading data 
	vector<var> readPIDs;
	
	// Kernel processes waiting for incoming data
	wait_queue_head_t readerQueue;
	
	// Last received axes values
	vec4 axes = vec4(0, 0, 0, 0);
	
	// Processes that called open(), removed on release()
	vector<DeviceListener> listeners;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing sidestick " + id + "\n");
	
	Shared::deviceId = id;
	
	Shared::charInode = cdev_add(-1, "sidestick");
	
	printk("Registered as " + Shared::charInode + "\n");
}

void handleInterrupt(vector<var> &in data)
{
	// printk("Sidestick" + Shared::deviceId + " Handling interrupt\n");
	
	int irq = data[0];
	if (irq == Interrupt_Sidestick_Update)
	{
		Shared::axes = data[1];
		
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Sidestick Open " + inode + " PID " + f.pid + "\n");
	
	Shared::listeners.push_back(DeviceListener(inode, f));
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Sidestick Read PID " + f.pid + " fnumber " + f.fnumber + "\n");

	uint iListener;
	for (iListener = 0; iListener < Shared::listeners.size(); iListener++)
	{
		if (Shared::listeners[iListener].openFile.fnumber == f.fnumber)
		{
			// ASSUMPTION We can have a listener application only once
			break;
		}
	}
	
	if (Shared::listeners[iListener].bPendingData)
	{
		// Skip to the end, read last data
	}
	else if (f.mode & O_NONBLOCK != 0)
	{
		// TODO Set error code
		
		return -1;
	}
	else
	{
		// Wait for the next event
		wait_event_interruptible(Shared::readerQueue, 1);
	}
	
	data.push_back(Shared::axes);
	ssize_t r = ssize_t(data.size());
	
	Shared::listeners[iListener].bPendingData = false;

	// printk("Read " + Shared::axes);
	
	return r;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Sidestick Write\n");
	
	return 0;
}

int release(uint inode, file &in f)
{
	printk("Sidestick Release " + inode + " PID " + f.pid + "\n");
	
	for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
	{
		if (Shared::listeners[iListener].openFile.fnumber == f.fnumber)
		{
			// ASSUMPTION We can have a listener application only once
			Shared::listeners.erase(iListener);
			break;
		}
	}
	
	return 0;
}
