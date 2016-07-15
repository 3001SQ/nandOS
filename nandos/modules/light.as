// -----------------------------------------------------------------------------
// light.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	// Extract device model and actual id
	int deviceModel = id / 100;
	int deviceId = id % 100;
	
	string nodeName;
	
	switch(deviceModel)
	{
		case Model_Light_Simple:
			nodeName = "light";
			break;
		case Model_Light_SpacecraftWarningLight:
			nodeName = "spacecraftWarningLight";
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
	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Light Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Light Read PID " + f.pid + "\n");
	
	// We aren't writing anything out, return 0 as written length
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Light Write PID " + f.pid + "\n");
	
	outv(data);
	
	return int(data.size());
}

int release(uint inode, file &in f)
{
	printk("Light Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
