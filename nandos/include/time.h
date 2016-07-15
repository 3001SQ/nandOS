// -----------------------------------------------------------------------------
// time.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/time.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Types

typedef uint time_t;

typedef uint suseconds_t;

typedef uint64 clock_t;

class tm
{
	int tm_sec;
	int tm_min;
	int tm_hour;
	int tm_mday;
	int tm_mon;
	int tm_year;
	int tm_wday;
	int tm_yday;
	int tm_isdst;
}

// Constants

uint64 CLOCKS_PER_SEC;

// ---------------------------------------------------------

clock_t clock();

time_t time();
