// -----------------------------------------------------------------------------
// data-link.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"
#include "nandos/wait.h"
#include "nandos/io.h"
#include "nandos/cdev.h"

// ---------------------------------------------------------

namespace DataLinkInstance
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
	
	// Incoming data buffer
	vector<var> dataIn;
	
	// Outgoing data buffer
	vector<var> dataOut;
	
	// fnumbers of open files
	// vector<int> openFiles;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing DataLink " + id + "\n");
	
	DataLinkInstance::deviceId = id;
	
	DataLinkInstance::charInode = cdev_add(id, "wlan");
	
	printk("Registered as " + DataLinkInstance::charInode + "\n");
}

void handleInterrupt(vector<var> &in data)
{
	// printk("DataLink " + DataLinkInstance::deviceId + " Handling interrupt\n");
	// for (uint iData = 0; iData < data.size(); iData++)
	// {
	// 	printk(" > " + iData + " : " + data[iData].dump() + "\n");
	// }
	
	int irq = data[0];
	if (irq == Interrupt_DataLink_Data)
	{
		for (uint iData = 0; iData < data.size(); iData++)
		{
			DataLinkInstance::dataIn.push_back(data[iData]);
		}
		
		wake_up_interruptible(DataLinkInstance::readerQueue);
	}
	else if (irq == Interrupt_DataLink_ConnectionAvailable)
	{
		DataLinkInstance::dataIn.push_back(data[0]);
		DataLinkInstance::dataIn.push_back(data[1]);
		wake_up_interruptible(DataLinkInstance::readerQueue);
	}
	else if (irq == Interrupt_DataLink_ConnectionLost)
	{
		DataLinkInstance::dataIn.push_back(data[0]);
		DataLinkInstance::dataIn.push_back(data[1]);
		wake_up_interruptible(DataLinkInstance::readerQueue);
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("DataLink " + DataLinkInstance::deviceId + " Open " + inode + "\n");
	
	// for (uint iFile = 0; iFile < DataLinkInstance::openFiles.size(); iFile++)
	// {
		// if (f.fnumber == DataLinkInstance::openFiles[iFile])
		// {
			// printk("WARNING: File is already existing " + f.number + ": " + iFile);
			// break;
		// }
	// }

	// DataLinkInstance::openFiles.push_back(f.fnumber);
	// printk("Added file " + DataLinkInstance::openFiles.size() + ": " + f.number);
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	printk("DataLink " + DataLinkInstance::deviceId + " Read\n");

	// TODO non-blocking behaviour
	
	if (DataLinkInstance::dataIn.empty())
	{
		printk("DataLink " + DataLinkInstance::deviceId + " wait for data\n");

		// Wait for the first handler to receive data
		wait_event_interruptible(DataLinkInstance::readerQueue, 1);

		printk("DataLink " + DataLinkInstance::deviceId + " wake up\n");
	}

	// TODO Respect maxOut buffer limit
	data = DataLinkInstance::dataIn;
	
	// TODO Multiple users, for now clear after first read
	DataLinkInstance::dataIn.clear();

	return data.size();
}

ssize_t write(file &in f, vector<var> &in data)
{
	printk("DataLink " + DataLinkInstance::deviceId + " Write\n");
	
	// TODO Proper buffering, for now we are just writing out
	
	outv(data);
	
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("DataLink Release " + inode + "\n");
	
	// for (uint iFile = 0u; iFile < DataLinkInstance::openFiles.size(); iFile++)
	// {
		// if (f.number == DataLinkInstance::openFiles[iFile])
		// {
			// printk("Remove file " + iFile + ": " + f.number);
			// DataLinkInstance::openFiles.erase(iFile);
			// break;
		// }
	// }
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}
