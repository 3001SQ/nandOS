// -----------------------------------------------------------------------------
// smoke_and_mirrors.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "unistd.h"

// ---------------------------------------------------------

int fdVideo = 0;

// --------------------------------------------------------

// General helper functions

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

void printMissing(int displayId = 0)
{
	printAppend("[ ", displayId, Display_TextForeground_LightGray);
	printAppend("FAILED", displayId, Display_TextForeground_Red, Display_TextBackground_Black);
	printLine(" ]", displayId, Display_TextForeground_LightGray);
}

void printLow(int displayId = 0)
{
	printAppend("[", displayId, Display_TextForeground_LightGray);
	printAppend("   LOW  ", displayId, Display_TextForeground_Yellow, Display_TextBackground_Black);
	printLine("]", displayId, Display_TextForeground_LightGray);
}

void initialiseDisplay(int displayId)
{
	setMode(displayId, Display_Mode_Text);
	clear(displayId, Display_TextBackground_Cyan);
}

void initialiseBitmapMode(int displayId)
{
	setMode(displayId, Display_Mode_Bitmap);
	drawTexture(displayId, displayId);
	swapBuffers(displayId);
}

void clearCockpitDisplays()
{
	for (int displayId = 1; displayId < 8; displayId++)
	{
		setMode(displayId, Display_Mode_Text);
		clear(displayId, Display_TextBackground_Black);
	}
}

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

// ---------------------------------------------------------

vector<var> deviceNodes =
{
	"/dev/therm0",
	"/dev/therm1",
	"/dev/therm2",
	"/dev/therm3",
	"/dev/wcl0",
	"/dev/wcl1"
};

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

void devicePowerOn(int idx)
{
	int fd = open(deviceNodes[idx], O_WRONLY);
			
	if (fd == -1)
	{
		log("Failed to open " + string(deviceNodes[idx]));
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

void deviceSleep(int idx)
{
	int fd = open(deviceNodes[idx], O_WRONLY);
			
	if (fd == -1)
	{
		log("Failed to open " + string(deviceNodes[idx]));
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

// ---------------------------------------------------------

void handleLowPower()
{
	// Wait for sidestick input to pretend the screens have no power

	int fdSidestick = open("/dev/sidestick", O_RDONLY);

	if (fdSidestick == -1)
	{
		log("bad");
		return;
	}

	vector<var> sidestickIn;

	ssize_t r = read(fdSidestick, sidestickIn, 32);
	r = read(fdSidestick, sidestickIn, 32);

	close(fdSidestick);

	// -----------------------------------------------------

	for (int iDisplay = 1; iDisplay < 2; iDisplay++)
	{
		setMode(iDisplay, Display_Mode_Text);
		clear(iDisplay, Display_TextBackground_Black);
		printLine("ERROR: Low system voltage", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
	}
	
	for (int iDisplay = 2; iDisplay < 5; iDisplay++)
	{
		setMode(iDisplay, Display_Mode_Text);
		clear(iDisplay, Display_TextBackground_Black);
		printLine("ERROR: Low system", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
		printLine("voltage", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
	}
	
	printAppend("     Main Engine: ", 3);
	printLine("OFF", 3,
			Display_TextForeground_Red);
	printAppend("Attitude Control: ", 3);
	printLine("ON", 3,
			Display_TextForeground_Green);
	
	for (int iDisplay = 5; iDisplay < 6; iDisplay++)
	{
		setMode(iDisplay, Display_Mode_Text);
		clear(iDisplay, Display_TextBackground_Black);
		printLine("ERROR: Low system voltage", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
	}
	
	for (int iDisplay = 6; iDisplay < 7; iDisplay++)
	{
		setMode(iDisplay, Display_Mode_Text);
		clear(iDisplay, Display_TextBackground_Black);
		printLine("ERROR: Low", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
		printLine("system", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
		printLine("voltage", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
	}
	
	for (int iDisplay = 7; iDisplay < 8; iDisplay++)
	{
		setMode(iDisplay, Display_Mode_Text);
		clear(iDisplay, Display_TextBackground_Black);
		printLine("ERROR: Low system voltage", iDisplay,
			Display_TextForeground_White, Display_TextBackground_Red);
	}
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
	log("Boot...");

	devicePowerOn("/dev/button0");

	// -----------------------------------------------------
	
	fdVideo = open("/dev/iq0", O_WRONLY);

	displayPowerOn(fdVideo, 0);
	
	setMode(0, Display_Mode_Text);
	clear(0);
	// clear(0, Display_TextBackground_Cyan);
	
	clearCockpitDisplays();
		
	// -----------------------------------------------------
	
	usleep(250000);
	printLine("nandOS (1.0rc1)", 0, Display_TextForeground_White);
	
	sleep(1);
	printAppend("3001SQ Self-Test                           ");
	usleep(500000);
	printOk();
	
	// ------------
	
	devicePowerOn("/dev/light1");		// Seat
	devicePowerOn("/dev/light2");		// Front left
	devicePowerOn("/dev/light3");		// Front right
	
	sleep(1);
	
	devicePowerOn("/dev/light0");		// Top light panels
	
	// ------------
	
	printLine("Initialising ECLSS", 0, Display_TextForeground_White);

	// ------------

	sleep(1);	
	// usleep(250000);
	printAppend("Cockpit Air Revitalization                 ");
	devicePowerOn("/dev/air0");
	usleep(500000);
	printOk();	
	
	// ------------
	
	// usleep(250000);
	sleep(1);
	printAppend("Active Thermal Control                     ");
	sleep(2);
	devicePowerOn(0);
	usleep(500000);
	devicePowerOn(1);
	usleep(2000000);
	devicePowerOn(2);
	usleep(500000);
	devicePowerOn(3);
	usleep(500000);
	
	printOk();
	
	// ------------
	
	usleep(250000);
	printAppend("Water Coolant Loop 01                      ");
	devicePowerOn("/dev/wcl0");
	sleep(2);
	printOk();
	
	usleep(250000);
	printAppend("Water Coolant Loop 02                      ");
	devicePowerOn("/dev/wcl1");
	sleep(2);
	deviceSleep("/dev/wcl1");
	sleep(2);
	printFailed();
	sleep(1);
	printLine("WARNING: Limiting heat production", 0,
		Display_TextForeground_Black, Display_TextBackground_Yellow);
	
	// ------------
	
	// usleep(500000);
	sleep(1);
	printAppend("Living Quarters Air Revitalization         ");
	usleep(500000);
	printDisabled();
	
	// ------------
	
	// usleep(500000);
	sleep(1);
	printAppend("Main Engine                                ");
	usleep(500000);
	printDisabled();
	
	// ------------
	
	sleep(1);
	printAppend("System Voltage                             ");
	usleep(500000);
	printLow();
	
	// ------------
	
	sleep(1);
	printLine("Initialising Controls", 0, Display_TextForeground_White);

	// ------------
	
	sleep(1);
	printAppend("Reaction Control System                    ");
	usleep(750000);
	printOk();
	
	// ------------

	sleep(1);	
	// printLine("Initialising Cockpit Displays", 0, Display_TextForeground_White);
	printAppend("Cockpit Displays                           ");
	
	sleep(2);
	
	// 1 Arm 2 DashLeft 3 DashCenter 4 DashRight 5 Container 6 Log 7 Overhead	
	
	displayPowerOn(fdVideo, 1);
	displayPowerOn(fdVideo, 2);
	displayPowerOn(fdVideo, 3);
	displayPowerOn(fdVideo, 4);
	displayPowerOn(fdVideo, 5);
	displayPowerOn(fdVideo, 6);
	displayPowerOn(fdVideo, 7);
	
	initialiseDisplay(1);
	initialiseDisplay(4);
	
	initialiseDisplay(2);
	initialiseDisplay(3);
	initialiseDisplay(5);
	initialiseDisplay(6);
	
	usleep(250000);

	initialiseBitmapMode(1);
	initialiseBitmapMode(4);

	initialiseDisplay(7);
	
	initialiseBitmapMode(2);
	initialiseBitmapMode(3);
	initialiseBitmapMode(5);
	initialiseBitmapMode(6);
	
	initialiseBitmapMode(7);

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
	// usleep(500000);
	
	printOk();
	
	sleep(1);
	
	// devicePowerOn("/dev/light0");		// Dashboard button
	{
		int fdButton = open("/dev/button0", O_WRONLY);
		
		vector<var> controlState =
		{
			Control_Button_IndicateState,
			1
		};
		write(fdButton, controlState);
		
		close(fdButton);
	}
	
	printLine("READY. Per aspera ad astra!", 0, Display_TextForeground_White);
	
	// -----------------------------------------------------
	
	sleep(1);
	printAppend("Starting /bin/sh                           ");
	usleep(750000);
	printMissing();
	sleep(1);
	printLine("WARNING: Input disabled.", 0,
		Display_TextForeground_Black, Display_TextBackground_Yellow);
	
	// -----------------------------------------------------
	
	// handleLowPower();

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
