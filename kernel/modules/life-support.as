// -----------------------------------------------------------------------------
// life-support.as
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
		case Model_LifeSupport_ActiveThermalControl:
			nodeName = "therm";
			break;
		case Model_LifeSupport_WaterCoolantLoop:
			nodeName = "wcl";
			break;
		case Model_LifeSupport_AirRevitalization:
			nodeName = "air";
			break;
		default:
			printk("Invalid model specified: " + id + "\n");
			return;
	}

	printk("Initializing " + nodeName + id + "\n");
	
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
	printk("LifeSupport Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("LifeSupport Read PID " + f.pid + "\n");
	
	// We aren't writing anything out, return 0 as written length
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("LifeSupport Write PID " + f.pid + "\n");
	
	outv(data);
	
	return int(data.size());
}

int release(uint inode, file &in f)
{
	printk("LifeSupport Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
