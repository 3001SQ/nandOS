// -----------------------------------------------------------------------------
// init.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "unistd.h"

// ---------------------------------------------------------

void executeApplication(string path, vector<var> &in args)
{
	int pid = fork();
	if (pid > 0)
	{
		// WARNING fork() ... execv() workaround
		if (execv(path, args) == 0)
		{
			log(" + Started '" + path + "' " + pid);
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
	log("Starting Init");

	log("PID=" + getpid() + " PPID=" + getppid());

	// --------------------------------------------------------

	// MPS
	//  - /bin/flightcontrol
	//  - /bin/comms
	// Station
	//  - /bin/stationcontrol
	
	for (uint iArg = 0; iArg < argc; iArg++)
	{
		string path = string(argv[iArg]);
		vector<var> execArgs;
		
		// TODO Generic detection for commandline arguments
		
		executeApplication(path, execArgs);
	}
	
	// --------------------------------------------------------

	while(true)
	{
		// FIXME empty run queue
		// sleep(5);
		// log("Init wakeup, just for fun");
	}
	
	// --------------------------------------------------------

	return 0;
}