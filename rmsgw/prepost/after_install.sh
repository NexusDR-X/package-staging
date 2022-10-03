#!/usr/bin/env sh
# Runs AFTER installing package
sudo chown -R rmsgw:rmsgw /etc/rmsgw/*
echo "Get the pitnc_setparams and pitnc_getparams software"
wget -q -O /tmp/pitnc9K6params.zip http://www.tnc-x.com/pitnc9K6params.zip
if [ $? -eq 0 ]
then
   unzip -o /tmp/pitnc9K6params.zip
   chmod +x pitnc_*
   sudo mv -f pitnc_* /usr/bin/
   echo "Done."
else
   echo >&2 "WARNING: Could not download pitnc software."
fi

#grep -qE "^wl2kgw" /etc/ax25/axports 2>/dev/null || echo "wl2kgw	_CALL_-_SSID_	19200	236	4	TNC Setup on _FREQ_ Hz (_MODEM_)" >> /etc/ax25/axports
#if ! grep -qE "wl2kgw" /etc/ax25/ax25d.conf 2>/dev/null
#then
#   cat > /tmp/ax25d.conf <<EOF
#[_CALL_-_SSID_ VIA wl2kgw]
#NOCALL   * * * * * *  L
#N0CALL   * * * * * *  L
#N0ONE    * * * * * *  L
#default  * * * * * *  -	rmsgw  /usr/local/bin/rmsgw	rmsgw -l debug -P %d %U
#EOF
#   cat /tmp/ax25d.conf | sudo tee --append /etc/ax25/ax25d.conf >/dev/null
#fi
if grep -q "on-watchdog" /lib/systemd/system/ax25.service 2>/dev/null
then
	sudo cp -f /lib/systemd/system/ax25.service.withwatchdog /lib/systemd/system/ax25.service
else
	sudo cp -f /lib/systemd/system/ax25.service.nowatchdog /lib/systemd/system/ax25.service
fi
sudo systemctl daemon-reload
sudo systemctl enable ax25.service
sudo systemctl restart rsyslog

exit 0

