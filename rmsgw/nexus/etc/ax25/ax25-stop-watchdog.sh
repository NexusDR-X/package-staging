#!/usr/bin/env bash
#
# This script stops the ax25-watchdog script. This script called as ExecStartPre=
#
VERSION="1.0.1"
/usr/bin/pkill -f /etc/ax25/ax25-watchdog.sh 2>/dev/null
# The following 2 lines are needed because direwolf and mkiss were started
# with 'sudo su - $DWUSER' rather than root, so although those apps were started
# in ax25-up, they aren't in the systemctl control-group, so they aren't killed when
# the watchdog expires. 
/usr/bin/killall -SIGTERM direwolf 2>/dev/null
/usr/bin/killall -SIGKILL mkiss 2>/dev/null
exit 0
