# CRIU X11 JVM POC

The objective is to use CRIU to freeze (dump) running X11-using JVM processes on disk,
and thaw (restore) those processes later.

In principle, CRIU does just that, but in practise, the conditions on the server
have to be just right.

This POC explores just exactly how to control those conditions, so that CRIU will
do its job predictably every time.

## Running the JVM with CRIU.

Set `-XX:-UsePerfData` so that the JVM won't create the perf data directories and files
which sometimes get cleaned up, and will block the restoration of the process.

## Running JVM AWT programs with X11 and Xvfb

AWT will terminate the JVM process, if an active X11 session goes away from under it.

If you try to restore a process which has lost its X11 session in this way,
the restore will be successful, but the process will immediately die.

The solution is to start a separate Xvfb process for each AWT process, push them into
the same PID namespace, and freeze the parent process of both Xvfb and the JVM.

## namespaces

When CRIU restores a process from disk to memory, it tells the Linux kernel to recreate
the exact process structure which it saved on disk originally. A part of this exact
duplication is setting the process ID numbers (PIDs) to be exactly as they used to be.
However, the Linux kernel might have given that PID to some other process meanwhile.

The solution to this potential PID conflict is to create a separate PID namespace,
where processes can have the same PIDs as already existing processes have in the parent
PID namespace, and restore the processes into that empty new PID namespace.

## cgroups

## capabilities?
