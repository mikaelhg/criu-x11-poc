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
