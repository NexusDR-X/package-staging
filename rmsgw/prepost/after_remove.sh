#!/usr/bin/env sh
# Runs AFTER removing package
rm -f /usr/share/applications/rmsgw_config_monitor.desktop
rm -f /usr/bin/rmschanstat.local 
rm -f /usr/bin/rmsgw* 
rm -f /usr/local/bin/pitnc_*
rm -f /usr/bin/pitnc_*
for F in ax25-up ax25-up.new ax25-up.new2 ax25d.conf direwolf.conf ax25-down ax25*watchdog.sh *.template *.depricated
# Remove various configuration and script files
do
	rm -f /etc/ax25/${F}
done
rm -rf /etc/rmsgw
#for F in channels.xml gateway.conf sysop.xml
#do
#	rm -f /etc/rmsgw/${F}
#done
# Remove cron jobs
rm -f /lib/systemd/system/ax25.service*
bash -c 'cat <(grep -i -v -e "mailbox.*sent.*mtime" <(crontab -u pi -l)) | crontab -u pi -'
bash -c 'cat <(fgrep -i -v "rmsgw-activity" <(crontab -u pi -l)) | crontab -u pi -'
bash -c 'cat <(fgrep -i -v "rmsgw_aci" <(crontab -u rmsgw -l)) | crontab -u rmsgw -'
exit 0
