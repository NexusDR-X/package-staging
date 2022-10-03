#!/usr/bin/env bash
#
# This script watches for LISTEN sockets between this RMS Gateway and a
# client station. This should never occur, as such sockets should be removed once the
# conversation has completed. However, due to a bug in the Linux kernel, they do not.
# The result is that that same client station cannot connect to the RMS Gateway again 
# until a different station connects first, then THAT station can't connect, etc.
# If this script detects a leftover socket, it restarts ax25.service. It is launched via
# this line in /lib/systemd/system/ax25.service:
# ExecStartPost=/usr/bin/ax25-autorestart.sh
#
# Leftover listeners start with a call sign (an alpha character)
#LEFTOVER_LISTENER="netstat --ax25 | grep -e '^[a-zA-Z].*[[:space:]]*${SOURCE}[[:space:]]*${DEVICE}[[:space:]]*LISTENING'"
#echo "LEFTOVER_LISTENER=$LEFTOVER_LISTENER"
# A normal 'netstat --ax25' output looks like this:
# Active AX.25 sockets
# Dest       Source     Device  State        Vr/Vs    Send-Q  Recv-Q
# *          W7ECG-10   ax0     LISTENING    000/000  0       0     
#
# A leftover socket, caused by the ax25 bug, looks like this:
# Active AX.25 sockets
# Dest       Source     Device  State        Vr/Vs    Send-Q  Recv-Q
# AG7GN-0    W7ECG-10   ax0     LISTENING    000/000  0       0     
#
# When that leftover socket is present, the Dest station (AG7GN-0 in this example)
# can no longer connect with this rmsgw until another station successfully connects to
# this rmsgw, then that station can't connect again until... etc.
#
# Ensure only this instance of this script is running. Kill the other instances.
#OTHER_PIDs="$(pidof -o %PPID -x $(basename $0))"
#[[ -n $OTHER_PIDs ]] && kill -SIGTERM $OTHER_PIDs

VERSION="1.0.3"

function monitor () {
	echo -e "\nWATCHDOG: Watching for leftover AX25 sockets in LISTENING state on $DEVICE\n" >> /var/log/packet.log
	while :
	do
		# Leftover listeners start with a call sign (an alpha character)
		netstat --ax25 | grep -qe "^[a-zA-Z].*[[:space:]]*${SOURCE}[[:space:]]*${DEVICE}[[:space:]]*LISTENING"
		if [[ $? == 0 ]]
		then
			# Leftover listener detected. Wait another second and if it's still there,
			# stop sending WATCHDOG=1, which will trigger a restart of ax25.service
			$(command -v systemd-notify) WATCHDOG=1
			sleep 1
			netstat --ax25 | grep -qe "^[a-zA-Z].*[[:space:]]*${SOURCE}[[:space:]]*${DEVICE}[[:space:]]*LISTENING"
			[[ $? == 0 ]] && break
		fi
		$(command -v systemd-notify) WATCHDOG=1
		sleep 2
	done
	echo -e "\nWATCHDOG: Leftover AX25 socket in LISTENING state on $DEVICE detected. AX25 will restart." >> /var/log/packet.log
}

# /usr/bin/rmsgw_manager.sh creates file /etc/ax25/ax25-autorestart when the user has 
# checked the "Enable autorestart as workaround to AX25 bug" box in the configuration
# screen.
# If this file does not exist, this script exits immediately.
#[[ -f /etc/ax25/ax25-autorestart ]] || exit 0

# Look for for the regular listener socket (starts with '*'). This listener should be
# present. If it's not then ax25 isn't running. Exit this script if that's the case. Wait for MAXWAIT/10 seconds for the socket to appear before giving up.
COUNTER=0
MAXWAIT=50
while [ $COUNTER -lt $MAXWAIT ]
do # Allocate a PTY to ax25
	LISTENER=$(netstat --ax25 | grep -e "^*" | tr -s ' \t')
	[[ -n $LISTENER ]] && break
	sleep 0.1
	let COUNTER=COUNTER+1
done
[[ -z $LISTENER ]] && exit 1

# Determine the device (usually ax0) and the source, which is this rmsgw's call-ssid.
DEVICE=$(echo "$LISTENER" | cut -d' ' -f3)
[[ $DEVICE =~ ax ]] || exit 1
SOURCE=$(echo "$LISTENER" | cut -d' ' -f2)
#echo "Launching watchdog for call $SOURCE on device $DEVICE" >> /var/log/packet.log
$(command -v systemd-notify) --ready
monitor &
