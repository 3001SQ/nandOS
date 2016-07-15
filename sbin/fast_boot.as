// -----------------------------------------------------------------------------
// fast_boot.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "unistd.h"

// ---------------------------------------------------------
// MPS Device overview - may change with updates!
// ---------------------------------------------------------

// 
// Cockpit lights:
//
//    /dev/light0					Ceiling
//    /dev/light1					Seat
//    /dev/light2					Dashboard left
//    /dev/light3					Dashboard right
//

// 
// Output devices:
//
//    /dev/iq0				GPU, dispatches commands to displays
//

//
// MPS Display IDs (passed to GPU as target):
//
//    0 Terminal           54x23
//    1 Arm                58x20
//    2 DashBoard Left     23x24
//    3 DashBoard Center   23x24
//    4 DashBoard Right    23x24
//    5 Container          36x10
//    6 Log                12x14     
//    7 Overhead          101x12
//

//
// Input devices:
//
//    /dev/sidestick
//

//
// Environmental Control and Life Support System:
//
//    /dev/air0				Air Revitalisation System
//
//    /dev/therm0			Active Thermal Control Unit 0
//    /dev/therm1			Active Thermal Control Unit 1
//    /dev/therm2			Active Thermal Control Unit 2
//    /dev/therm3			Active Thermal Control Unit 3
//
//    /dev/wcl0				Water Coolant Loop 0
//    /dev/wcl1				Water Coolant Loop 1
//

//
// Attitude control thrusters:
//
//    Thruster firing directions relative to pilot seat reference system
//
//                 -- Front --
//    /dev/thruster0         Left Top Front     : Up
//    /dev/thruster1         Left Top Front     : Left
//    /dev/thruster2         Left Bottom Front  : Left
//    /dev/thruster3         Left Bottom Front  : Down
//    /dev/thruster4         Right Bottom Front : Down
//    /dev/thruster5         Right Bottom Front : Right
//    /dev/thruster6         Right Top Front    : Right
//    /dev/thruster7         Right Top Front    : Up
//                 --- Back ---
//    /dev/thruster9         Left Top Back      : Up
//    /dev/thruster10        Left Top Back      : Left
//    /dev/thruster11        Left Bottom Back   : Left
//    /dev/thruster12        Left Bottom Back   : Down
//    /dev/thruster13        Right Bottom Back  : Down
//    /dev/thruster14        Right Bottom Back  : Right
//    /dev/thruster15        Right Top Back     : Right
//    /dev/thruster16        Right Top Back     : Up
//

//
// Navigation Instruments:
//
//    /dev/nav				Navigation device (absolute position/angles)
//

// 
// Special:
//
//    /dev/button0			Indicates 3001SQ computer state
//

// ---------------------------------------------------------

// File descriptor of the GPU
int fdVideo = 0;

class TextResolution
{
	int columns;
	int rows;

	// Make sure to have a standard constructor to use types with vector<>
	TextResolution()
	{
	}
	
	TextResolution(int c, int r)
	{
		columns = c;
		rows = r;
	}
}

// Text resolutions of displays
vector<TextResolution> resolutions;

// --------------------------------------------------------

// General display helper functions

void setMode(int displayId, int mode)
{
	vector<var> control = 
	{
		Control_Video_DisplayMode,
		displayId,
		mode
	};
	write(fdVideo, control);
}

void clear(int displayId, int bg = Display_TextBackground_Black)
{
	vector<var> control = 
	{
		Control_Video_Clear,
		displayId,
		bg
	};
	write(fdVideo, control);
}
	
void printAppend(string message,
	int displayId = 0,
	int fg = Display_TextForeground_LightGray,
	int bg = Display_TextBackground_Default,
	int attr = Display_TextAttribute_Normal)
{
	{
		vector<var> control = 
		{
			Control_Video_AppendCharacters,
			displayId,
			message, 
			fg,
			bg,
			attr
		};
		write(fdVideo, control);
	}
}

void printLine(string message,
	int displayId = 0,
	int fg = Display_TextForeground_LightGray,
	int bg = Display_TextBackground_Default,
	int attr = Display_TextAttribute_Normal)
{
	printAppend(message, displayId, fg, bg, attr);

	{
		vector<var> control = 
		{
			Control_Video_Newline, 
			displayId
		};
		write(fdVideo, control);
	}
}

void initialiseDisplay(int displayId)
{
	setMode(displayId, Display_Mode_Text);
	clear(displayId, Display_TextBackground_Cyan);
	
	printLine(" /dev/iq0", displayId, Display_TextForeground_White);
	printLine(" Display: " + displayId, displayId, Display_TextForeground_White);
	markCorners(displayId, resolutions[displayId].columns,
		resolutions[displayId].rows);
}

void clearCockpitDisplays()
{
	for (int displayId = 1; displayId < 8; displayId++)
	{
		setMode(displayId, Display_Mode_Text);
		clear(displayId, Display_TextBackground_Black);
	}
}

void printSingleCharacter(string c, int column, int row, int displayId)
{
	vector<var> singleChar = {
		Control_Video_SetCharacter, displayId, c, column, row,
		Display_TextForeground_Black,
		Display_TextBackground_Yellow,
		Display_TextAttribute_Normal
	};
	write(fdVideo, singleChar);
}

void markCorners(int displayId, int columns, int rows)
{
	printSingleCharacter("0", 0, 0, displayId);
	printSingleCharacter("1", 0, rows-1, displayId);
	printSingleCharacter("2", columns-1, rows-1, displayId);
	printSingleCharacter("3", columns-1, 0, displayId);
}

// ---------------------------------------------------------

void drawTexture(int displayId, int textureHandle)
{
	vector<var> control = 
	{
		Control_Video_DrawTexture,
		displayId,
		textureHandle,
		vec4(0, 0, 1, 1)
	};
	write(fdVideo, control);
}

void swapBuffers(int displayId)
{
	vector<var> control = 
	{
		Control_Video_SwapBuffers,
		displayId
	};
	write(fdVideo, control);
}

void initialiseBitmapMode(int displayId)
{
	setMode(displayId, Display_Mode_Bitmap);
	drawTexture(displayId, displayId);
	swapBuffers(displayId);
}

// ---------------------------------------------------------

// Common messages

void printOk(int displayId = 0)
{
	printAppend("[   ", displayId, Display_TextForeground_LightGray);
	printAppend("OK", displayId, Display_TextForeground_Green, Display_TextBackground_Black);
	printLine("   ]", displayId, Display_TextForeground_LightGray);
}

void printFailed(int displayId = 0)
{
	printAppend("[ ", displayId, Display_TextForeground_LightGray);
	printAppend("FAILED", displayId, Display_TextForeground_Red, Display_TextBackground_Black);
	printLine(" ]", displayId, Display_TextForeground_LightGray);
}

void printDisabled(int displayId = 0)
{
	printAppend("[", displayId, Display_TextForeground_LightGray);
	printAppend("DISABLED", displayId, Display_TextForeground_Yellow, Display_TextBackground_Black);
	printLine("]", displayId, Display_TextForeground_LightGray);
}

// ---------------------------------------------------------

// General device power management helper functions
// NOTE In real-world programs we want to keep the descriptors open

void devicePowerOn(string nodePath)
{
	int fd = open(nodePath, O_WRONLY);
			
	if (fd == -1)
	{
		log("Failed to open " + nodePath);
		return;
	}

	vector<var> controlOn =
	{
		Control_Device_Power,
		Device_PowerMode_On
	};
	
	write(fd, controlOn);
	close(fd);
}

void devicePowerOff(string nodePath)
{
	int fd = open(nodePath, O_WRONLY);
			
	if (fd == -1)
	{
		log("Failed to open " + nodePath);
		return;
	}

	vector<var> controlOn =
	{
		Control_Device_Power,
		Device_PowerMode_Off
	};
	
	write(fd, controlOn);
	close(fd);
}

void deviceSleep(string nodePath)
{
	int fd = open(nodePath, O_WRONLY);
			
	if (fd == -1)
	{
		log("Failed to open " + nodePath);
		return;
	}

	vector<var> controlOn =
	{
		Control_Device_Power,
		Device_PowerMode_Sleep
	};
	
	write(fd, controlOn);
	close(fd);
}

void displayPowerOn(int fd, int idx)
{
	vector<var> controlOn =
	{
		Control_Device_Power,
		Device_PowerMode_On,
		idx
	};
	
	write(fd, controlOn);
}

void executeApplication(string path)
{
	int pid = fork();
	if (pid > 0)
	{
		vector<var> args;
		
		// WARNING fork() ... execv() workaround, doesn't functions
		//         as you would expect from a POSIX system yet!
		if (execv(path, args) == 0)
		{
			log("Started '" + path + "' " + pid);
		}
		else
		{
			log(" ! Failed to start '" + path + "'");
		}
	}
}

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
	
int main(uint argc, vector<var> &in argv)
{
	log("Fast boot...");

	// -----------------------------------------------------

	devicePowerOn("/dev/button0");

	// -----------------------------------------------------
	
	fdVideo = open("/dev/iq0", O_WRONLY);

	displayPowerOn(fdVideo, 0);
	
	setMode(0, Display_Mode_Text);
	clear(0);
	
	clearCockpitDisplays();
	
	// -----------------------------------------------------
	
	usleep(250000);
	printLine("nandOS 1.0rc1", 0, Display_TextForeground_White);
	
	sleep(1);
	printAppend("Fast Boot                                  ");
	
	// ------------
	
	devicePowerOn("/dev/light1");		// Seat
	devicePowerOn("/dev/light2");		// Front left
	devicePowerOn("/dev/light3");		// Front right
	
	devicePowerOn("/dev/light0");		// Top light panels

	// ------------
	
	devicePowerOn("/dev/air0");
	
	// ------------
	
	devicePowerOn("/dev/therm0");
	devicePowerOn("/dev/therm1");
	devicePowerOn("/dev/therm2");
	devicePowerOn("/dev/therm3");
	
	// ------------
	
	devicePowerOn("/dev/wcl0");
	
	// ------------

	resolutions.push_back(TextResolution(54, 23));
	resolutions.push_back(TextResolution(58, 20));
	resolutions.push_back(TextResolution(23, 24));
	resolutions.push_back(TextResolution(23, 24));
	resolutions.push_back(TextResolution(23, 24));
	resolutions.push_back(TextResolution(36, 10));
	resolutions.push_back(TextResolution(12, 14));
	resolutions.push_back(TextResolution(101, 12));
	
	// We have 8 configured display screens
	
	// markCorners(0, resolutions[0].columns, resolutions[0].rows);
	for (uint iDisplay = 1; iDisplay < 8; iDisplay++)
	{
		displayPowerOn(fdVideo, iDisplay);
		// initialiseDisplay(iDisplay);
		initialiseBitmapMode(iDisplay);
	}
	
	{
		// Wall display
	
		displayPowerOn(fdVideo, 8);
		setMode(8, Display_Mode_Bitmap);
		
		int textId = 1;
		
		vector<var> controlCreateText =
		{
			Control_Video_CreateText,
			textId
		};
		write(fdVideo, controlCreateText);
		
		vector<var> controlClear =
		{
			Control_Video_Clear,
			Display_TextBackground_Black,
			8
		};
		write(fdVideo, controlClear);
		
		vector<var> controlUpdateText =
		{
			Control_Video_UpdateText,
			textId,
			"SEALED OFF",
			2,
			Display_TextForeground_Red,
			Display_TextBackground_Default
		};
		write(fdVideo, controlUpdateText);
			
		vector<var> controlDrawText =
		{
			Control_Video_DrawText,
			textId,
			8,
			vec2(0.1253, 0.4),
			20,
			1.0
		};
		write(fdVideo, controlDrawText);
		
		swapBuffers(8);
	}
	
	usleep(250000);
	
	{
		// Change power button colour to green
		
		int fdButton = open("/dev/button0", O_WRONLY);
		
		vector<var> controlState =
		{
			Control_Button_IndicateState,
			1
		};
		write(fdButton, controlState);
		
		close(fdButton);
	}
	
	// -----------------------------------------------------
	
	printOk();
	usleep(500000);
	printLine("READY. Per aspera ad astra!", 0, Display_TextForeground_White);
	
	usleep(250000);
	
	printLine("=== Multi-Purpose Spacecraft (MPS) device nodes", 0,
		Display_TextForeground_Black, Display_TextBackground_LightBlue);
	
	usleep(500000);
	
	const int entryTimeoutMicroseconds = 100000;
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/light0    ( 0, 1, 2, 3)");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/iq0       Displays: 0,1,2,3,4,5,6,7");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/sidestick");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/air0      ( 0)");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/therm0    ( 0, 1, 2, 3)");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/wcl0      ( 0, 1)");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/thruster0 ( 0, 1, 2, 3, 4, 5, 6, 7)");
	printLine("                ( 9,10,11,12,13,14,15,16)");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/nav");
	
	usleep(entryTimeoutMicroseconds);
	printLine(" /dev/button0   ( 0)");
	
	usleep(250000);
	
	// -----------------------------------------------------

	// Start default applications for communication and flight control

	executeApplication("/bin/comms");
	executeApplication("/bin/flightcontrol");

	// -----------------------------------------------------
	
	// Start user programs

	string path = "/usr/bin/hello_world";

	int pid = fork();
	if (pid > 0)
	{
		vector<var> args;
	
		// WARNING fork() ... execv() workaround, doesn't functions
		//         as you would expect from a POSIX system yet!
		if (execv(path, args) == 0)
		{
			log("Started '" + path + "' " + pid);
			printLine(">>> Executing " + path, 0,
				Display_TextForeground_Black, Display_TextBackground_Green);
		}
		else
		{
			log(" ! Failed to start '" + path + "'");
			printLine("!!! " + path + " compilation failed", 0,
				Display_TextForeground_Yellow, Display_TextBackground_Red);
		}
	}
	
	close(fdVideo);
	
	// -----------------------------------------------------
	
	return 0;
}
