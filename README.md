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

1\. AWT will terminate the JVM process, if an active X11 session goes away from under it.

If you try to restore a process which has lost its X11 session in this way,
the restore will be successful, but the process will immediately die.

The solution is to start a separate Xvfb process for each AWT process, push them into
the same PID namespace, and freeze the parent process of both Xvfb and the JVM.

2\. Xvfb/Xserver will start a `dbus` process for the X11 session, if it's been configured 
to do so in the normal platform X11 configuration.

In addition, some library in the X11 client initialization process will memory map a 
`dconf` per-user configuration file, which CRIU will unfortunately expect to be exactly
the same when restoring an image.

To accomplish stability here, we can either figure out why X11 performs these initializations
and disable them, or alternatively mark the configuration file read only, and make sure that
it's always the same. It doesn't appear that the application needs to actually write anything
there.

## Process group leader inside the isolated PID namespace

When dumping a process inside a PID namespace, CRIU requires the process group leader
to be inside that same PID namespace. Therefore, you have to use `setsid` to assign a
new process group leader as a parent to both the `Xvfb` and the `java` processes.

## Demo inside Docker

```bash
docker build -t criu-x11-poc .

docker run -it --rm -v `pwd`:/app -v /tmp/data/dump:/data/dump -w /app \
  --privileged -v /lib/modules:/lib/modules:ro --tmpfs /run \
  criu-x11-poc:latest bash

# 
# yum install -y util-linux procps lsof iptables criu xorg-x11-server-Xvfb libXrender libXtst python3 less

setsid ./03_start_processes.sh

criu dump -t $(pgrep -f 03_start) -D /data/dump -v4 -o dump.log --external $(python3 tty_code.py) --tcp-established && echo OK

CTRL-D

docker run -it --rm -v `pwd`:/app -v /tmp/data/dump:/data/dump -w /app \
  --privileged -v /lib/modules:/lib/modules:ro --tmpfs /run \
  criu-x11-poc:latest bash

# yum install -y util-linux procps lsof iptables criu xorg-x11-server-Xvfb libXrender libXtst python3 less

criu restore -d -D /data/dump -v4 -o restore.log --inherit-fd 'fd[1]:'$(python3 tty_code.py) --tcp-established && echo OK
```

## Demo

#### 1\. Fork a new, isolated, bash process 

Start a new isolated shell, and check its namespaces.

```bash
sudo  unshare --pid --ipc --mount --cgroup --net --mount-proc --fork bash

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

setsid -f xvfb-run -a -l -s '+extension GLX +render -noreset -nolisten unix' \
  /home/mikael/.jdks/adopt-openjdk-14/bin/java -XX:-UsePerfData -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar
```

#### 3\. Dump the application and Xvfb processes through their common parent bash

```bash
rm -rf /tmp/5 ; mkdir /tmp/5
criu dump -t $(pgrep start_app) -D /tmp/5 -v4 -o dump.log --external $(python3 tty_code.py) --shell-job --ext-unix-sk --tcp-established && echo OK
```

#### 4\. Create new anonymous namespaces, and restore the process in there

```bash
sudo unshare --pid --ipc --mount --cgroup --net --mount-proc --fork bash

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

With `sudo` without `-E`, the user `root` appears to receive an extra `dbus-launch` daemon.

```
(00.026277)    445: Error (criu/files-reg.c:1824): File home/mikael/.config/dconf/user has bad size 9547 (expect 9555)

lsof -nPp 258 | grep -v /lib
lsof: WARNING: can't stat() fuse.gvfsd-fuse file system /run/user/1000/gvfs
      Output information may be incomplete.
lsof: WARNING: can't stat() fuse.jetbrains-toolbox file system /tmp/.mount_jetbraqrqAYM
      Output information may be incomplete.
COMMAND PID USER   FD      TYPE             DEVICE  SIZE/OFF    NODE NAME
java    258 root  cwd       DIR               0,50        21 3706348 /home/mikael/devel/temp/criu-x11-poc
java    258 root  rtd       DIR               0,26        29      34 /
java    258 root  txt       REG               0,50      8768 3685336 /home/mikael/.jdks/adopt-openjdk-14/bin/java
java    258 root  mem       REG               0,26    100008  984010 /usr/share/glib-2.0/schemas/gschemas.compiled
java    258 root  mem       REG               0,51         2      18 /root/.cache/dconf/user
java    258 root    0u      CHR              136,0       0t0       3 /dev/pts/0
java    258 root    1u      CHR              136,0       0t0       3 /dev/pts/0
java    258 root    2u      CHR              136,0       0t0       3 /dev/pts/0
java    258 root    5u     IPv4             424303       0t0     TCP 127.0.0.1:37878->127.0.0.1:6001 (ESTABLISHED)
java    258 root    6u  a_inode               0,14         0   12677 [eventfd]
java    258 root    7u  a_inode               0,14         0   12677 [eventfd]
java    258 root    8u  a_inode               0,14         0   12677 [eventfd]
java    258 root    9u     unix 0xffff987e9a398000       0t0  431205 type=STREAM
java    258 root   10u  a_inode               0,14         0   12677 [eventfd]
java    258 root   11r     FIFO               0,13       0t0  417269 pipe
java    258 root   12w     FIFO               0,13       0t0  417269 pipe

ps axufwww
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0  12368  3148 pts/6    S    11:44   0:00 bash
root           9  0.0  0.0   2608  1404 ?        Ss   11:44   0:00 /bin/sh /usr/bin/xvfb-run -a -l -s +extension GLX +render -noreset /home/mikael/.jdks/adopt-openjdk-14/bin/java -XX:-UsePerfData -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar
root          19  0.0  0.1 2480984 33344 ?       Sl   11:44   0:00  \_ Xvfb :99 +extension GLX +render -noreset -auth /tmp/xvfb-run.bXlQgk/Xauthority
root          54  0.1  0.1 11953560 55808 ?      Sl   11:44   0:00  \_ /home/mikael/.jdks/adopt-openjdk-14/bin/java -XX:-UsePerfData -jar build/libs/criu-x11-poc-1.0-SNAPSHOT-all.jar
root          80  0.0  0.0   7128  1880 ?        S    11:44   0:00 dbus-launch --autolaunch=5893f493f747485fa557d207fdf91dc0 --binary-syntax --close-stderr
root          81  0.0  0.0   7148  2184 ?        Ss   11:44   0:00 /usr/bin/dbus-daemon --syslog-only --fork --print-pid 5 --print-address 7 --session

$ grep -r libgio /home/mikael/.jdks/adopt-openjdk-14/
Binary file /home/mikael/.jdks/adopt-openjdk-14/lib/libawt_xawt.so matches
Binary file /home/mikael/.jdks/adopt-openjdk-14/lib/libawt_headless.so matches
Binary file /home/mikael/.jdks/adopt-openjdk-14/lib/libnet.so matches
Binary file /home/mikael/.jdks/adopt-openjdk-14/lib/libsplashscreen.so matches
Binary file /home/mikael/.jdks/adopt-openjdk-14/lib/libawt.so matches
mikael@gumidesk:~$ strings /home/mikael/.jdks/adopt-openjdk-14/lib/libawt.so | grep libgio
@libgio-2.0.so
libgio-2.0.so.0
mikael@gumidesk:~$ strings /home/mikael/.jdks/adopt-openjdk-14/lib/libawt_xawt.so | grep libgio
libgio-2.0.so
libgio-2.0.so.0
mikael@gumidesk:~$ strings /home/mikael/.jdks/adopt-openjdk-14/lib/libawt_headless.so | grep libgio
libgio-2.0.so
libgio-2.0.so.0

sudo grep -r dbus /etc/X11
/etc/X11/Xsession.options:use-session-dbus
/etc/X11/Xsession.d/75dbus_dbus-launch:# simply place use-session-dbus into your /etc/X11/Xsession.options file
/etc/X11/Xsession.d/75dbus_dbus-launch:DBUSLAUNCH=/usr/bin/dbus-launch
/etc/X11/Xsession.d/75dbus_dbus-launch:if has_option use-session-dbus; then
/etc/X11/Xsession.d/75dbus_dbus-launch:  # 95dbus_update-activation-env will not have the complete environment
/etc/X11/Xsession.d/75dbus_dbus-launch:  # environment variable also calls dbus-update-activation-environment.
/etc/X11/Xsession.d/70im-config_launch:# The hook script for dbus-launch is in 75 which changes $STARTUP string.
/etc/X11/Xsession.d/70im-config_launch:# This shuld be befor this dbus-launch hook to ensure the working dbus
/etc/X11/Xsession.d/95dbus_update-activation-env:    [ -x "/usr/bin/dbus-update-activation-environment" ]; then
/etc/X11/Xsession.d/95dbus_update-activation-env:    # tell dbus-daemon --session (and systemd --user, if running)
/etc/X11/Xsession.d/95dbus_update-activation-env:    dbus-update-activation-environment --verbose --systemd --all
/etc/X11/Xsession.d/90qt-a11y:if [ -x "/usr/bin/dbus-update-activation-environment" ]; then
/etc/X11/Xsession.d/90qt-a11y:        dbus-update-activation-environment --verbose --systemd QT_ACCESSIBILITY
/etc/X11/Xsession.d/20dbus_xdg-runtime:  # Be nice to non-libdbus, non-sd-bus implementations by using
/etc/X11/Xsession.d/20dbus_xdg-runtime:if [ -x "/usr/bin/dbus-update-activation-environment" ]; then
/etc/X11/Xsession.d/20dbus_xdg-runtime:  # tell dbus-daemon --session (and systemd --user, if running)
/etc/X11/Xsession.d/20dbus_xdg-runtime:  dbus-update-activation-environment --verbose --systemd \

```

#### Trash

Manual app start commands.

```bash
Xvfb :1 -screen 0 1024x768x24 +extension GLX +render -noreset \
    > /dev/null 2> /dev/null < /dev/null &

Xvfb :1 -screen 0 1024x768x24 +extension GLX +render -noreset -listen inet -nolisten unix -nolisten local

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
