// -----------------------------------------------------------------------------
// signal.h
// nandOS (Binary Interface)
//
// http://pubs.opengroup.org/onlinepubs/9699919799/basedefs/signal.h.html
//
// Created by Stjepan Stamenkovic.
// -----------------------------------------------------------------------------

// Types

typedef int pid_t;

// ---------------------------------------------------------

/** send a signal to a process or a group of processes */
int          kill(pid_t pid, int sig)

/** wait for a signal */
int          sigwait(const vector<int> &in set, int &out sig)
