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
	vector<DisplayConfiguration> displayConfigurations;
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
			
		VideoInstance::displayConfigurations.push_back(config);
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
	
	// -----------------------------------------------------
	// Special handling of bitmap mode memory objects
	// -----------------------------------------------------
	
	// Rewrite bitmap text id to incorporate PID shift
	// Each application can thereby have text labels in [0, 999] locally, while
	// it is referenced as (localId + PID * 1000) on global device memory
	int controlCode = int(data[0]);
	if (controlCode == Control_Video_CreateText ||
		controlCode == Control_Video_UpdateText ||
		controlCode == Control_Video_DeleteText ||
		controlCode == Control_Video_DrawText)
	{
		int localId = int(data[1]);
	
		// text id 0 is invalid for driver operations
		if (localId == 0)
		{
			log("Application " + f.pid + " tried to operate on text 0!");
			return -1;
		}
		
		// Make sure that font size is converted to float if the user specifiied int
		if (controlCode == Control_Video_DrawText &&
			data[4].getType() == Var_Type_Integer)
		{
			data[4] = float(int(data[4]));
		}

		data[1] = uint64(localId + f.pid * 1000);
	}
	
	outv(data);
	
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Video Adapter Release " + inode + "\n");
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}
