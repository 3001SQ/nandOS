// -----------------------------------------------------------------------------
// terminal.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// TODO Proper implementation

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing terminal " + id + "\n");
	
	cdev_add(-1, "tty");
}

void handleInterrupt(vector<var> &in data)
{
	printk("Terminal interrupt");

	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Terminal Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Terminal Read PID " + f.pid + "\n");
	
	return 0;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Terminal Write PID " + f.pid + "\n");
	
	// We confirm that the data was received but don't do anything with it
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Terminal Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
