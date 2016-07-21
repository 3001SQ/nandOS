// -----------------------------------------------------------------------------
// fcntl.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/fcntl.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Constants

/** File descriptor flags that can be OR-ed together */
enum FD_FLAG
{
	// Main flags
	O_RDONLY = 0x01,	/** Open for reading only */
	O_RDWR   = 0x02,	/** Open for reading and writing. */
	O_WRONLY = 0x04,	/** Open for writing only. */
	// Optional flags
	O_APPEND = 0x10,	/** If set, the file offset shall be set to the end of the file prior to each write */
	O_CREAT  = 0x20,	/** [...] the file shall be created */
	O_TRUNC  = 0x40,	/** [...] length shall be truncated to 0, and the mode and owner shall be unchanged */
	O_NONBLOCK = 0x80	/** Non-blocking mode */
}

/** fcntl() commands */
enum FD_FcntlCmd
{
	F_GETFL = 0,	/** Get file status flags and file access modes */
	F_SETFL			/** Set file status flags */
}

// ---------------------------------------------------------

/** open file relative to current working directory */
int          open(const string &in path, int oflag)

/** open file relative to another opened file descriptor (has to be directory) */
int          openat(int fd, const string &in path, int oflag)

/** get the file status flags, F_GETFL */
int          fcntl(int fildes, int cmd)

/** set the file status flags, F_SETFL */
int          fcntl(int fildes, int cmd, int flags)
