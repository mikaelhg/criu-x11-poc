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

```bash
sudo -E unshare --pid --ipc --mount --cgroup --mount-proc --fork bash
setsid -f ./start_app.sh &

criu dump -t 3964 -D /tmp/5 -v4 -o dump.log --external 'tty[8800:17]' --shell-job --ext-unix-sk --tcp-established && echo OK

criu restore -d -D /tmp/5 -v4 -o restore.log --inherit-fd 'fd[1]:tty[8800:17]' --shell-job --ext-unix-sk --tcp-established && echo OK

Xvfb :1 -screen 0 1024x768x24 +extension GLX +render -noreset \
    > /dev/null 2> /dev/null < /dev/null &
java -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar \
    > /dev/null 2> /dev/null < /dev/null &
```

## external TTYs

https://criu.org/Inheriting_FDs_on_restore#External_TTYs

```
$ ipython
In [1]: import os
In [2]: st = os.stat("/proc/self/fd/0")
In [3]: print "tty[%x:%x]" % (st.st_rdev, st.st_dev)
tty:[8800:d]

$ps -C sleep
  PID TTY          TIME CMD
 4109 ?        00:00:00 sleep

$ ./criu dump --external 'tty[8800:d]' -D imgs -v4 -t 4109
$ ./criu restore --inherit-fd 'fd[1]:tty[8800:d]' -D imgs -v4
```

## process groups

The process which we dump should NOT be a process group leader. We can use the
`setsid` command to set a new process group leader.

```text
 | unshare (set namespace)
 \- setsid 1 (create independent process group leader)
  \- bash 2 (dump this)
   |- Xvfb 3
   |- java 4
```

## namespaces

When CRIU restores a process from disk to memory, it tells the Linux kernel to recreate
the exact process structure which it saved on disk originally. A part of this exact
duplication is setting the process ID numbers (PIDs) to be exactly as they used to be.
However, the Linux kernel might have given that PID to some other process meanwhile.

The solution to this potential PID conflict is to create a separate PID namespace,
where processes can have the same PIDs as already existing processes have in the parent
PID namespace, and restore the processes into that empty new PID namespace.

```
sudo -E unshare --pid --ipc --mount --cgroup --mount-proc --fork -S 1000 -G 1000 bash

ps -eo cgroup,ppid,pid,user,cmd

sudo nsenter -a -t $NEW_PID bash
sudo -E nsenter -a -S 1000 -G 1000 -t $NEW_PID bash

criu dump -t 448226 -D /tmp/5 -vvv -o dump.log --shell-job --tcp-established && echo OK
criu restore -d -D /tmp/5 -vvv -o restore.log --tcp-established --shell-job && echo OK

```

## cgroups

It **appears** that CRIU is fetching a list of, among other things, named pipes,
or UNIX IPC streams, through interrogating the freezed process's cgroups. I don't
really understand how this works yet, so this will be the immediate object my work,
as the CRIU dump logs terminate on the various named pipes, and there is little
documentation to help figure out how to move forward.

## capabilities?

Restoring a CRIU dump requires `CAP_SYSADMIN` capabilities, which are available to
`root`. However, it should be possible to set / stick that capability to any random
binary run by a non-`root` user. Worth looking at.
