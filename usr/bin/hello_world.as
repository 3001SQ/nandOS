// -----------------------------------------------------------------------------
// hello_world.as
// nandOS
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

//
// This program will print a message to the Launcher debugging console
//
// To get started with more useful programs, check:
// - https://3001sq.net/forums/#/categories/hello-world (Beginners Forum)
// - https://github.com/3001SQ                          (Code Examples)
//

// Binary nandOS API
#include "stdio.h"

// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------
// -----------------------------------------------------------------------------

int main(uint argc, vector<var> &in argv)
{
	log("Hello World! (Launcher Code Console)");
	printf("Hello World! (Terminal Display)\n");

	return 0;
}
