// -----------------------------------------------------------------------------
// stat.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/sys_stat.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// TODO Regularize path: sys/stat.h

// Constants

/** File types and permissions, OR'ed together */
enum FD_Mode
{
	// Types
	S_IFIFO = 0x0001,		/** FIFO */
	S_IFCHR = 0x0002,		/** Character device */
	S_IFDIR = 0x0004,		/** Directory */
	S_IFBLK = 0x0008,		/** Block device */
	S_IFREG = 0x0010		/** Regular file */
}

// ---------------------------------------------------------

/** make a directory relative to directory file descriptor */
int          mkdir(const string &in path, int mode)

/** make a directory relative to directory file descriptor with defined file descriptor */
int          mkdirat(int fd, const string &in path, int mode)

/** make directory, special file, or regular file, dev = (classId * 100) + deviceId */
int          mknod(const string &in path, int mode, int dev)

/** make directory, special file, or regular file with defined file descriptor, dev = (classId * 100) + deviceId */
int          mknodat(int fd, const string &in path, int mode, int dev)
