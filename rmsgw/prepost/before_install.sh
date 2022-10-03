#!/usr/bin/env sh
# Runs BEFORE installing package
mkdir -p /etc/rmsgw/hooks
id rmsgw >/dev/null 2>&1 || useradd -c 'Linux RMS Gateway' -d /etc/rmsgw -s /bin/false rmsgw
#[ -d /usr/local/etc/rmsgw ] && sudo rm -rf /usr/local/etc/rmsgw
#sudo mkdir -p /usr/local/etc
#sudo ln -s /etc/rmsgw /usr/local/etc/rmsgw
#sudo mkdir -p /usr/local/share/applications
systemctl is-active --quiet ax25 && sudo systemctl stop ax25.service
killall -SIGTERM rmsgw_manager.sh 2>/dev/null
exit 0
