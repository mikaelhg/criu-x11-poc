#!/bin/env python

import os
st = os.stat("/proc/self/fd/0")
print("tty[%x:%x]" % (st.st_rdev, st.st_dev))
