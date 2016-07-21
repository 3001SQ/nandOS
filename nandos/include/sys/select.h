// -----------------------------------------------------------------------------
// select.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/sys_select.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// TODO select() functionality is not fully validated yet

// Types

class fd_set
{
	// Opaque type
}

class timeval
{
	uint tv_sec;
	uint tv_usec;
}

// ---------------------------------------------------------

/** Synchronous multiplexing, examine given file descriptor sets for their write/read/error status, timeval parameter is NOT modified */
int select(int nfds, fd_set@ readfds, fd_set@ writefds, fd_set@ errorfds, timeval@ timeout)

/** Remove the file descriptor from the set */
void FD_CLR(int fd, fd_set& fdset)

/** Return whether a file descriptor is part of the set */
int FD_ISSET(int fd, fd_set& fdset)

/** Add a file descriptor to the set */
void FD_SET(int fd, fd_set& fdset)

/** Empty the file descriptor set */
void FD_ZERO(fd_set& fdset)
