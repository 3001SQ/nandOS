// -----------------------------------------------------------------------------
// null.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing null " + id + "\n");
	
	cdev_add(-1, "null");
}

void handleInterrupt(vector<var> &in data)
{
	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Null Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	printk("Null Read PID " + f.pid + "\n");
	
	// We aren't writing anything out, return 0 as written length
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	printk("Null Write PID " + f.pid + "\n");
	
	// We confirm that the data was received but don't do anything with it
	return int(data.size());
}

int release(uint inode, file &in f)
{
	printk("Null Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
