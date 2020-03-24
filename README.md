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

## Demo

#### 1\. Fork a new, isolated, bash process 

Start a new isolated shell, and check its namespaces.

```bash
sudo -E unshare --pid --ipc --mount --cgroup --mount-proc --fork bash

lsns
        NS TYPE   NPROCS PID USER COMMAND
4026531837 user        3   1 root bash
4026531838 uts         3   1 root bash
4026532463 mnt         3   1 root bash
4026532465 ipc         3   1 root bash
4026532473 pid         3   1 root bash
4026532474 cgroup      3   1 root bash
4026532476 net         3   1 root bash

ls -Flah /proc/$$/ns
total 0
dr-x--x--x 2 root root 0 maalis 22 19:00 ./
dr-xr-xr-x 9 root root 0 maalis 22 18:16 ../
lrwxrwxrwx 1 root root 0 maalis 22 19:03 cgroup -> 'cgroup:[4026532474]'
lrwxrwxrwx 1 root root 0 maalis 22 19:03 ipc -> 'ipc:[4026532465]'
lrwxrwxrwx 1 root root 0 maalis 22 19:03 mnt -> 'mnt:[4026532463]'
lrwxrwxrwx 1 root root 0 maalis 22 19:00 net -> 'net:[4026532476]'
lrwxrwxrwx 1 root root 0 maalis 22 19:03 pid -> 'pid:[4026532473]'
lrwxrwxrwx 1 root root 0 maalis 22 19:08 pid_for_children -> 'pid:[4026532473]'
lrwxrwxrwx 1 root root 0 maalis 22 19:03 user -> 'user:[4026531837]'
lrwxrwxrwx 1 root root 0 maalis 22 19:03 uts -> 'uts:[4026531838]'
```

And from a different terminal that's not inside those new namespaces:

```bash
sudo lsns | grep bash
4026532463 mnt         2 1658585 root             unshare --pid --ipc --net --mount --cgroup --propagation private --mount-proc --fork bash
4026532465 ipc         2 1658585 root             unshare --pid --ipc --net --mount --cgroup --propagation private --mount-proc --fork bash
4026532473 pid         1 1658586 root             bash
4026532474 cgroup      2 1658585 root             unshare --pid --ipc --net --mount --cgroup --propagation private --mount-proc --fork bash
4026532476 net         2 1658585 root             unshare --pid --ipc --net --mount --cgroup --propagation private --mount-proc --fork bash
```

#### 2\. Fork a new process group leader bash process

Which in turn runs a script, which starts our applications.

```bash
setsid -f ./start_app.sh &
```

#### 3\. Dump the application and Xvfb processes through their common parent bash

```bash
rm -rf /tmp/5 ; mkdir /tmp/5
criu dump -t $(pgrep start_app) -D /tmp/5 -v4 -o dump.log --external $(python3 tty_code.py) --shell-job --ext-unix-sk --tcp-established && echo OK
```

#### 4\. Create new anonymous namespaces, and restore the process in there

```bash
sudo -E unshare --pid --ipc --mount --cgroup --mount-proc --fork bash

criu restore -d -D /tmp/5 -v4 -o restore.log --inherit-fd 'fd[1]:'$(python3 tty_code.py) --shell-job --ext-unix-sk --tcp-established && echo OK
```

#### 5\. Network namespaces

```bash

sudo ip link add name veth0 type veth peer name veth1 netns 2237407
```

## Errors

When restoring, the `dconf` configuration file `$HOME/.config/dconf/user`,
which is apparently loaded through the `libX11` initialization somehow,
can change. 

```
(00.026277)    445: Error (criu/files-reg.c:1824): File home/mikael/.config/dconf/user has bad size 9547 (expect 9555)

lsof -p 1435 | grep -v /lib
lsof: WARNING: can't stat() fuse.gvfsd-fuse file system /run/user/1000/gvfs
      Output information may be incomplete.
lsof: WARNING: can't stat() fuse.jetbrains-toolbox file system /tmp/.mount_jetbraAPEOnR
      Output information may be incomplete.
COMMAND  PID USER   FD      TYPE             DEVICE  SIZE/OFF    NODE NAME
java    1435 root  cwd       DIR               0,50        21 3706348 /home/mikael/devel/temp/criu-x11-poc
java    1435 root  rtd       DIR               0,25        29      34 /
java    1435 root  txt       REG               0,50      8768 3685336 /home/mikael/.jdks/adopt-openjdk-14/bin/java
java    1435 root  mem       REG               0,25    100008 1101294 /usr/share/glib-2.0/schemas/gschemas.compiled
java    1435 root  mem       REG               0,50      9547 3927808 /home/mikael/.config/dconf/user
java    1435 root  mem       REG               0,71         2      35 /run/user/1000/dconf/user
java    1435 root    0u      CHR              136,6       0t0       9 /dev/pts/6
java    1435 root    1u      CHR              136,6       0t0       9 /dev/pts/6
java    1435 root    2u      CHR              136,6       0t0       9 /dev/pts/6
java    1435 root    5u     unix 0xffff95ce2fa08800       0t0 3388592 type=STREAM
java    1435 root    6u  a_inode               0,14         0   12677 [eventfd]
java    1435 root    7u  a_inode               0,14         0   12677 [eventfd]
java    1435 root    8u  a_inode               0,14         0   12677 [eventfd]
java    1435 root    9r     FIFO               0,13       0t0 3388594 pipe
java    1435 root   10u  a_inode               0,14         0   12677 [eventfd]
java    1435 root   11w     FIFO               0,13       0t0 3388594 pipe
```

#### Trash

Manual app start commands.

```bash
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

$ ps -C sleep
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

Routing to network namespaces:   
https://hackernoon.com/routing-to-namespaces-8e1eaffaac7f   
https://josephmuia.ca/2018-05-16-net-namespaces-veth-nat/   
https://www.toptal.com/linux/separation-anxiety-isolating-your-system-with-linux-namespaces

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
