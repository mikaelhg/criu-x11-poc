

```
(00.124829) Dumping pstree (pid: 2022)
(00.124833) ----------------------------------------
(00.124838) Process: 2022(2022)
(00.124897) ----------------------------------------
(00.124913) cg: All tasks in criu's cgroups. Nothing to dump.
(00.124917) unix: Dumping external sockets
(00.124942) unix:       Dumping extern: ino 1114950 peer_ino 1115514 family    1 type    1 state  1 name 
(00.124950) unix:       Dumped extern: id 0x49 ino 1114950 peer 0 type 2 state 10 name 18 bytes
(00.124955) unix:       Ext stream not supported: ino 1114950 peer_ino 1115514 family    1 type    1 state  1 name 
(00.124960) Error (criu/sk-unix.c:815): unix: Can't dump half of stream unix connection.
(00.124992) Unlock network
(00.124998) Unfreezing tasks into 1
(00.125002)     Unseizing 2022 into 1
(00.125053) Error (criu/cr-dump.c:1775): Dumping FAILED.
```
