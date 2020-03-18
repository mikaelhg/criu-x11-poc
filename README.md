# CRIU X11 JVM POC

The objective is to use CRIU to freeze running X11-using JVM processes on disk,
and thaw those processes later.

In principle, CRIU does just that, but in practise, the conditions on the server
have to be just right.

This POC explores just exactly how to control those conditions, so that CRIU will
do its job predictably every time.

