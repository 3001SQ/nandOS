// -----------------------------------------------------------------------------
// unittest.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/printk.h"

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing unittest " + id + "\n");
	
	cdev_add(-1, "unittest");
}

void handleInterrupt(vector<var> &in data)
{
	// Nothing to do
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Unittest Open " + inode + " PID " + f.pid + "\n");
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	printk("Unittest Read PID " + f.pid + "\n");
	
	data.push_back(false);
	data.push_back(123);
	data.push_back(uint64(456));
	data.push_back(789.1);
	data.push_back(vec2(1.1, 2.2));
	data.push_back(vec3(3.3, 4.4, 5.5));
	data.push_back(vec4(6.6, 7.7, 8.8, 9.9));
	data.push_back(quat(1.1, 2.2, 3.3, 4.4));
	data.push_back("some string");
	
	ssize_t r = ssize_t(data.size());
	
	return r;
}

ssize_t write(file &in f, vector<var> &in data)
{
	printk("Unittest Write PID " + f.pid + "\n");
	
	for (uint i = 0; i < data.size(); i++)
	{
		printk(" Received: " + i + " " + data[i].dump() + "\n");
	}
	
	// We confirm that the data was received but don't do anything with it
	
	ssize_t r = ssize_t(data.size());
	
	return r;
}

int release(uint inode, file &in f)
{
	printk("Unittest Release " + inode + " PID " + f.pid + "\n");
	return 0;
}
