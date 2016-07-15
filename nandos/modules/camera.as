// -----------------------------------------------------------------------------
// camera.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing camera " + id + "\n");
	
	cdev_add(id, "camera");
}

void handleInterrupt(vector<var> &in data)
{
	printk("Camera interrupt\n");

	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Camera Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	printk("Camera Read PID " + f.pid + "\n");
	
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	printk("Camera Write PID " + f.pid + "\n");
	
	outv(data);
	
	// We confirm that the data was received but don't do anything with it
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Camera Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
