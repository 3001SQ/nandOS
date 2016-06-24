// -----------------------------------------------------------------------------
// navigation.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

class NavigationListener
{
	uint inode;
	file openFile;
	bool bPendingData;

	NavigationListener()
	{
	}
	
	NavigationListener(uint i, file &in f)
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
	
	// Kernel processes waiting for incoming data
	wait_queue_head_t readerQueue;
	
	// Last received update data
	vec3 position;
	vec3 orientationRadians;
	vec3 linearVelocity;
	vec3 angularVelocity;
	
	// Processes that called open(), removed on release()
	vector<NavigationListener> listeners;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing navigation " + id + "\n");
	
	Shared::deviceId = id;
	
	cdev_add(-1, "nav");
}

void handleInterrupt(vector<var> &in data)
{
	//printk("Navigation" + Shared::deviceId + " Handling interrupt\n");
	
	int irq = data[0];
	if (irq == Interrupt_Navigation_Update)
	{
		Shared::position = data[1];
		Shared::orientationRadians = data[2];
		Shared::linearVelocity = data[3];
		Shared::angularVelocity = data[4];
		
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
	else
	{
		printk("Invalid interrupt: " + irq);
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Navigation Open " + inode + " PID " + f.pid + "\n");
	
	Shared::listeners.push_back(NavigationListener(inode, f));
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Navigation Read PID " + f.pid + "\n");

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
	
	data.push_back(Shared::position);
	data.push_back(Shared::orientationRadians);
	data.push_back(Shared::linearVelocity);
	data.push_back(Shared::angularVelocity);
	
	ssize_t r = ssize_t(data.size());
	
	Shared::listeners[iListener].bPendingData = false;

	return r;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// TODO Set update interval, check for valid range
	
	return 0;
}

int release(uint inode, file &in f)
{
	printk("Navigation Release " + inode + " PID " + f.pid + "\n");
	
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
