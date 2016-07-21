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

typedef uint64 size_t;
typedef int64 ssize_t;

// Constants

int STDIN_FILENO = 0;
int STDOUT_FILENO = 1;
int STDERR_FILENO = 2;

// ---------------------------------------------------------

// File handling

/** close a file descriptor */
int close(int)

/** read from a file */
ssize_t read(int, vector<var> &, size_t)

/** write on a file */
ssize_t write(int, vector<var> &in)

/** remove a directory */
int rmdir(const string &in)

/** remove a directory entry relative to working directory */
int unlink(const string &in)

/** remove a directory entry relative to file descriptor */
int unlinkat(int, const string &in, int)

// WARNING fork() ... execv() implemented as non-POSIX WORKAROUND

/** shall create a new process. The new process (child process) shall be an exact copy of the calling process (parent process) except for the list of the specs */
pid_t fork()

/** shall replace the current process image with a new process image. The new image shall be constructed from a regular, executable file called the new process image file. There shall be no return from a successful exec, because the calling process image is overlaid by the new process image. */
int execv(const string &in, const vector<var> &in)

// Process information

/** shall return the process ID of the calling process. */
pid_t getpid()

/** shall return the parent process ID of the calling process. */
pid_t getppid()

/** shall return the process group ID of the calling process. */
pid_t getpgrp()

/** shall return the real user ID of the calling process. */
uid_t getuid()

/** shall return the real group ID of the calling process. */
uid_t getgid()

// Sleeping and signals

/** suspend execution for an interval of time (seconds) */
uint sleep(uint)

/** suspend execution for an interval (microseconds) NOTE: From issue 6, removed in issue 7 */
int usleep(uint)

// Working directory

/** shall cause the directory named by the pathname pointed to by the path argument to become the current working directory; that is, the starting point for path searches for pathnames not beginning with '/' */
int chdir(string &in)

/** get the pathname of the current working directory */
string getcwd(string &out, size_t &out)

/** get the pathname of the current working directory */
string getcwd()
