// -----------------------------------------------------------------------------
// sh.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

#include "unistd.h"

// @@@ Proper setup of entry point
int main(uint argc, vector<var> &in argv)
{
	log("Starting Shell");
	
	log("PID=" + getpid() + " PPID=" + getppid());
	log("argc: " + argc + " " + argv.size());
	
	for (uint iArg = 0; iArg < argv.size(); iArg++)
	{
		log(iArg + ": " + argv[iArg].dump());
	}
	
	// --------------------------------------------------------

	while(true)
	{
		// TODO Wait for user input, run applications, etc
	
		sleep(1);
	}

	return 0;
}