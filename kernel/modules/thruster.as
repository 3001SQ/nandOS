// -----------------------------------------------------------------------------
// thruster.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"
#include "nandos/io.h"

// ---------------------------------------------------------

namespace ThrusterInstance
{
	// Device Id this driver instance is handling
	uint8 deviceId = 0;

	// Character device inode
	uint charInode = 0;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing thruster " + id + "\n");
	
	ThrusterInstance::deviceId = id;
	
	ThrusterInstance::charInode = cdev_add(id, "thruster");
	
	printk("Registered as " + ThrusterInstance::charInode + "\n");
}

void handleInterrupt(vector<var> &in data)
{
	printk("Thruster" + ThrusterInstance::deviceId + " Handling interrupt\n");

	// FIXME No thruster interrupts defined yet
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Thruster Open " + inode + "\n");
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Thruster " + ThrusterInstance::deviceId + ": Read\n");
	
	// TODO return proper error code as read is not supported
	
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Thruster "  + ThrusterInstance::deviceId + ": Write\n");
	
	outv(data);
	
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Thruster "  + ThrusterInstance::deviceId + ": Release(" + inode + ")\n");
	
	// TODO exclusive access, handle multpile applications
	
	return 0;
}
