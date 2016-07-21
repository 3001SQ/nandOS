// -----------------------------------------------------------------------------
// stdio.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/stdio.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// ---------------------------------------------------------

int printf(const string &in message)
int printf(const string &in format, vector<var> &in args)

int scanf(const string &in format, int &out value)
int scanf(const string &in format, int64 &out value)
int scanf(const string &in format, uint &out value)
int scanf(const string &in format, uint64 &out value)

int scanf(const string &in format, float &out value)
int scanf(const string &in format, double &out value)

int scanf(const string &in format, string &out value)
