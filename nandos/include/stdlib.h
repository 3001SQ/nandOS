// -----------------------------------------------------------------------------
// stdlib.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/stdlib.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Constants

const int RAND_MAX = 0x7fff;

// ---------------------------------------------------------

int           rand()
void          srand(unsigned seed)
