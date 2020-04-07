#!/bin/env python3

import os, sys

st = os.stat(f'/proc/{sys.argv[1]}/fd/0')
#st = os.stat('/proc/1/fd/0')
print("tty[%x:%x]" % (st.st_rdev, st.st_dev))
