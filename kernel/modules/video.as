// -----------------------------------------------------------------------------
// video.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

class DisplayConfiguration
{
	string label;

	// Text mode
	
	int textColumns;
	int textRows;
	
	// Bitmap mode
	
	bool bBitmapAvailable = false;
	
	int bitmapWidth;
	int bitmapHeight;
};

namespace VideoInstance
{
	// Device Id this driver instance is handling
	uint8 deviceId = 0;
	
	// Character device inode
	uint charInode = 0;
	
	// Displays registered in order of DisplayConnected  interrupts
	//vector<DisplayConfiguration>
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing Video Adapter " + id + "\n");
	
	VideoInstance::deviceId = id;
	
	VideoInstance::charInode = cdev_add(id, "iq");
	
	printk("Registered as " + VideoInstance::charInode + "\n");
}

// void handleInterrupt(vector<var> &in data)
void handleInterrupt(var[] &in data)
{
	if (int(data[0]) == Interrupt_Video_DisplayConnected && data.size() == 7)
	{
		int idx = data[1];
	
		DisplayConfiguration config;
		config.label = data[2];
		config.textColumns = data[3];
		config.textRows = data[4];
		config.bitmapWidth = data[5];
		config.bitmapHeight = data[6];

		printk("VideoAdapter " + VideoInstance::deviceId + " : Display connected : " +
			idx + " " + config.label);
	}
	else
	{
		printk("VideoAdapter " + VideoInstance::deviceId + ": < ! > Invalid interrupt " +
			data[0].dump() + " (" + int(data.size()) + ") vars");
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Video Adapter Open " + inode + "\n");
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}

ssize_t read(file &in f, var[] &out data, size_t maxOut)
{
	// printk("Video Adapter Read\n");
	
	// No data to return
	
	return 0;
}

ssize_t write(file &in f, var[] &in data)
{
	// printk("Video Adapter Write\n");
	
	// for (uint iData = 0; iData < data.size(); iData++)
	// {
		// printk(" " + data[iData].dump());
	// }
	
	outv(data);
	
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Video Adapter Release " + inode + "\n");
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}
