// -----------------------------------------------------------------------------
// keyboard.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
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
	
	// ---------------------------------
	
	// Interrupt code
	int lastInterrupt;
	
	// Last key code
	int keyCode;
	
	// Last key data
	int keyData;
	
	// Last received scanned key character
	string scannedCharacter;
	
	// ---------------------------------
	
	// Processes that called open(), removed on release()
	vector<DeviceListener> listeners;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	// NOTE For now we hard-code terminal keyboard event1, arm-display event2, sidestick event3
	
	// Extract device model and actual id
	int deviceModel = id / 100;
	int deviceId = id % 100;
	
	string nodeName;
	
	switch(deviceModel)
	{
		case Model_Keyboard_Terminal:
			nodeName = "event";
			deviceId = 1;
			break;
		case Model_Keyboard_ArmDisplay:
			nodeName = "event";
			deviceId = 2;
			break;
		default:
			printk("Invalid model specified: " + id + "\n");
			return;
	}

	printk("Initialising " + nodeName + deviceId + "\n");
	
	cdev_add(deviceId, nodeName);
}

void handleInterrupt(vector<var> &in data)
{
	Shared::lastInterrupt = data[0];
	
	if (Shared::lastInterrupt == Interrupt_Keyboard_Key)
	{
		Shared::keyCode = data[1];
		Shared::keyData = data[2];
		
		printk("Keyboard key: " + Shared::keyCode + " " + Shared::keyData + "\n");
	
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
	else if (Shared::lastInterrupt == Interrupt_Keyboard_Character)
	{
		Shared::scannedCharacter = data[1];
		
		printk("Keyboard character:" + Shared::scannedCharacter + "\n");
		
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
	else
	{
		printk("Keyboard: Invalid interrupt " + Shared::lastInterrupt + "\n");
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Keyboard Open " + inode + " PID " + f.pid + "\n");
	
	Shared::listeners.push_back(DeviceListener(inode, f));
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Keyboard Read PID " + f.pid + " fnumber " + f.fnumber + "\n");

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
	
	// NOTE For now we simply redirect the output
	if (Shared::lastInterrupt == Interrupt_Keyboard_Key)
	{
		data.push_back(Shared::lastInterrupt);
		data.push_back(Shared::keyCode);
		data.push_back(Shared::keyData);
	}
	else if (Shared::lastInterrupt == Interrupt_Keyboard_Character)
	{
		data.push_back(Shared::lastInterrupt);
		data.push_back(Shared::scannedCharacter);
	}

	ssize_t r = ssize_t(data.size());
	
	Shared::listeners[iListener].bPendingData = false;
	
	return r;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Keyboard Write\n");
	
	return 0;
}

int release(uint inode, file &in f)
{
	printk("Keyboard Release " + inode + " PID " + f.pid + "\n");
	
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
