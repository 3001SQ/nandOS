// -----------------------------------------------------------------------------
// unistd.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/unistd.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Types

typedef int pid_t;

typedef int uid_t;

// Constants

int STDIN_FILENO;

int STDOUT_FILENO;

int STDERR_FILENO;

// ---------------------------------------------------------

// File handling

int close(int);

ssize_t read(int, vector<var> &, size_t);

ssize_t write(int, vector<var> &in);

int rmdir(const string &in);

int unlink(const string &in);

int unlinkat(int, const string &in, int);

// WARNING fork() ... execv() NOT implemented as non-POSIX WORKAROUND

pid_t fork();

int execv(const string &in, const vector<var> &in);

// Process information

pid_t getpid();

pid_t getppid();

pid_t getpgrp();

uid_t getuid();

uid_t getgid();

// Sleeping and signals

uint sleep(uint);

int usleep(uint);

// Working directory

int chdir(string &in);

string getcwd(string &out, size_t &out);

string getcwd();
