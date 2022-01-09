#!/usr/bin/env sh
# Runs AFTER removing package
rm -f /usr/share/applications/rmsgw_config_monitor.desktop
rm -f /usr/bin/rmschanstat.local 
rm -f /usr/bin/rmsgw-activity.sh 
rm -f /usr/bin/rmsgw_manager.sh
rm -f /usr/local/bin/pitnc_*
rm -f /usr/bin/pitnc_*
for F in ax25-up.new ax25-up.new2 ax25d.conf direwolf.conf
do
	rm -f /etc/ax25/${F}
done
for F in channels.xml gateway.conf sysop.xml
do
	rm -f /etc/rmsgw/${F}
done
exit 0
