// -----------------------------------------------------------------------------
// terminal.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// nandOS
#include "nandos/wait.h"
#include "nandos/io.h"
#include "nandos/cdev.h"

// ---------------------------------------------------------

class DeviceListener
{
	uint inode;
	file openFile;
	bool bPendingData;

	DeviceListener()
	{
	}
	
	DeviceListener(uint i, file &in f)
	{
		inode = i;
		openFile = f;
		bPendingData = true;
	}
}

namespace Shared
{
	// Device Id this driver instance is handling
	uint8 deviceId = 0;

	// Whether we have data to process by the second handler
	bool bInterruptData = false;
	
	// Character device inode
	uint charInode = 0;
	
	// Application PIDs reading data 
	vector<var> readPIDs;
	
	// Kernel processes waiting for incoming data
	wait_queue_head_t readerQueue;
	
	// ---------------------------------
	
	// Interrupt code
	int lastInterrupt;
	
	// Last key code
	int keyCode;
	
	// Last key data
	int keyData;
	
	// Last received scanned key character
	string scannedCharacter;
	
	// ---------------------------------
	
	// Processes that called open(), removed on release()
	vector<DeviceListener> listeners;
}

// ---------------------------------------------------------

// First handler context

void init(uint id)
{
	printk("Initializing terminal " + id + "\n");
	
	cdev_add(-1, "tty");
}

void handleInterrupt(vector<var> &in data)
{
	// NOTE We can't perform module context switches yet, so all incoming data
	//      is being duplicated from the first keyboard
	
	Shared::lastInterrupt = data[0];
	
	if (Shared::lastInterrupt == Interrupt_Keyboard_Key)
	{
		Shared::keyCode = data[1];
		Shared::keyData = data[2];
		
		printk("Terminal key: " + Shared::keyCode + " " + Shared::keyData + "\n");
	
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
	else if (Shared::lastInterrupt == Interrupt_Keyboard_Character)
	{
		Shared::scannedCharacter = data[1];
		
		printk("Terminal character:" + Shared::scannedCharacter + "\n");
		
		for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
		{
			Shared::listeners[iListener].bPendingData = true;
		}
		
		wake_up_interruptible(Shared::readerQueue);
	}
}

// ---------------------------------------------------------

// Second handler context

int open(uint inode, file &in f)
{
	printk("Terminal Open " + inode + " PID " + f.pid + "\n");
	
	Shared::listeners.push_back(DeviceListener(inode, f));
	
	return 0;
}

ssize_t read(file &in f, vector<var> &out data, size_t maxOut)
{
	// printk("Terminal Read PID " + f.pid + " fnumber " + f.fnumber + "\n");

	uint iListener;
	for (iListener = 0; iListener < Shared::listeners.size(); iListener++)
	{
		if (Shared::listeners[iListener].openFile.fnumber == f.fnumber)
		{
			// ASSUMPTION We can have a listener application only once
			break;
		}
	}
	
	if (Shared::listeners[iListener].bPendingData)
	{
		// Skip to the end, read last data
	}
	else if (f.mode & O_NONBLOCK != 0)
	{
		// TODO Set error code
		
		return -1;
	}
	else
	{
		// Wait for the next event
		wait_event_interruptible(Shared::readerQueue, 1);
	}
	
	// NOTE For now we simply redirect the output
	if (Shared::lastInterrupt == Interrupt_Keyboard_Key)
	{
		data.push_back(Shared::lastInterrupt);
		data.push_back(Shared::keyCode);
		data.push_back(Shared::keyData);
	}
	else if (Shared::lastInterrupt == Interrupt_Keyboard_Character)
	{
		data.push_back(Shared::lastInterrupt);
		data.push_back(Shared::scannedCharacter);
	}

	ssize_t r = ssize_t(data.size());
	
	Shared::listeners[iListener].bPendingData = false;
	
	return r;
}

ssize_t write(file &in f, vector<var> &in data)
{
	// printk("Terminal Write PID " + f.pid + "\n");

	// NOTE We can't perform module context switches yet, so all outgoing data
	//      will be routed to the first video device for now, assuming it is in text mode

	// NOTE We assume that the last argument is the format string, any previous ones
	//      need to be plugged in the former - so we're effectively implementing parts of printf() here
	
	vector<var> controlNewline = { Control_Video_Newline, 0 };	

	string s = data[data.size() - 1];
	
	if (data.size() > 1)
	{
		bool bValidReplacement = true;
		
		for (uint iVar = 0; iVar < data.size() - 1; iVar++)
		{
			// printk(" Replace " + string(data[iVar]) + "\n");
			
			size_t replacementStart = 0;
			
			if (data[iVar].getType() == Var_Type_String)
			{
				replacementStart = s.find("%s");
				if (replacementStart == string::npos)
				{
					bValidReplacement = false;
					break;
				}
				
				string v = data[iVar];
				s = s.substr(0, replacementStart) + v + s.substr(replacementStart + 2);
			}
			else if (data[iVar].getType() == Var_Type_Float)
			{
				replacementStart = s.find("%f");
				if (replacementStart == string::npos)
				{
					bValidReplacement = false;
					break;
				}
				
				float v = data[iVar];
				s = s.substr(0, replacementStart) + string(v) + s.substr(replacementStart + 2);
			}
			else if (data[iVar].getType() == Var_Type_Integer)
			{
				replacementStart = s.find("%d");
				if (replacementStart == string::npos)
				{
					replacementStart = s.find("%i");
				}
				if (replacementStart == string::npos)
				{
					replacementStart = s.find("%c");
				}
				if (replacementStart == string::npos)
				{
					bValidReplacement = false;
					break;
				}
				
				int v = data[iVar];			
				s = s.substr(0, replacementStart) + string(v) + s.substr(replacementStart + 2);
			}
			else if (data[iVar].getType() == Var_Type_Unsigned)
			{
				replacementStart = s.find("%u");
				if (replacementStart == string::npos)
				{
					bValidReplacement = false;
					break;
				}
				
				uint64 v = data[iVar];
				s = s.substr(0, replacementStart) + string(v) + s.substr(replacementStart + 2);
			}
			else
			{
				// Invalid type
				bValidReplacement = false;
				break;
			}
		}
		
		// The replacement failed, we won't write anything to the device
		if (!bValidReplacement)
		{
			// TODO Throw exception?
			log("Invalid printf() format/arguments!");
			return -1;
		}
	}
		
	// -------------------------------------------------------------------------
	
	// NOTE At this point we have the final string, may still need format expansion
		
	size_t lineStart = 0;
	size_t lineEnd = s.find("\n");
	
	while (lineStart < s.size())
	{
		// TODO Support special character sequences for colour changes, etc
		vector<var> displayAppend = 
		{
			Control_Video_AppendCharacters, 0,
			s.substr(lineStart, lineEnd - lineStart),
			Display_TextForeground_Default,
			Display_TextBackground_Default,
			Display_TextAttribute_Normal
		};
		outv(displayAppend);
		
		printk(" '" + s.substr(lineStart, lineEnd - lineStart) + "' \n");

		if (lineEnd == string::npos)
		{
			break;
		}			
		else
		{
			outv(controlNewline);
		}

		lineStart = lineEnd + 1;
		lineEnd = s.find("\n", lineStart);
	}
	
	// We confirm that the data was received but don't do anything with it
	return data.size();
}

int release(uint inode, file &in f)
{
	printk("Terminal Release " + inode + " PID " + f.pid + "\n");
	
	for (uint iListener = 0; iListener < Shared::listeners.size(); iListener++)
	{
		if (Shared::listeners[iListener].openFile.fnumber == f.fnumber)
		{
			// ASSUMPTION We can have a listener application only once
			Shared::listeners.erase(iListener);
			break;
		}
	}
	
	return 0;
}
