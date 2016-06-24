// -----------------------------------------------------------------------------
// button.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	cdev_add(id, "button");
}

void handleInterrupt(vector<var> &in data)
{
	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	// printk("Button Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Button Read PID " + f.pid + "\n");
	
	// We aren't writing anything out, return 0 as written length
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	printk("Button Write PID " + f.pid + "\n");
	
	outv(data);
	
	return int(data.size());
}

int release(uint inode, file &in f)
{
	printk("Button Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
