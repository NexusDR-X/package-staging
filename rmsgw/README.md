# Nexus RMS Gateway

## IMPORTANT

IMPORTANT: You must obtain a [Sysop Winlink account](https://www.winlink.org/content/join_gateway_sysop_team_sysop_guidelines) in order to operate an RMS Gateway!

## Contents

The `rmsgw` package contains:

- NW Digital Radio's [Linux RMS Gateway](https://github.com/nwdigitalradio/rmsgw) packaged specifically for the Nexus DR-X.
- AX.25/Direwolf control scripts from [KI6ZHD](http://www.trinityos.com/HAM/CentosDigitalModes/RPi/rpi2-setup.html#18.install-ax25) and heavily modified for use with the Nexus DR-X.
- Various GUI and shell scripts for configuring and monitoring Direwolf, AX.25, and the Linux AX.25 gateway.

## Installation and Upgrading

Use one of these methods:

- Run `sudo apt update && sudo apt install rmsgw` in Terminal.
- Select `rmsgw` in the Nexus Updater (__Hamradio__ menu, then __Nexus Updater__).

## Bugs and workarounds

### TX Audio Delay with PulseAudio

There's a bug somewhere (PulseAudio?) that introduces a delay of about 1 second after PTT is activated before any audio is transmitted. The workaround is to configure Direwolf to use the Fe-Pi sound card directly (via ALSA), and not the PulseAudio virtual ALSA sound interfaces of `fepi-capture-left|right` and `fepi-playback-left|right`. To change from using the FePi virtual ALSA interfaces of `fepi-capture-left|right` and `fepi-playback-left|right`, follow these instructions *in this order*:

1. Stop the ax25 service using either the __RMS Gateway Manager__ or the command line:

		sudo systemctl stop ax25
		
1. Open a Terminal, type the following lines to disable the PulseAudio service:

		systemctl --user stop pulseaudio.socket
		systemctl --user stop pulseaudio.service
			
	and remove the pulseaudio configuration that uses the Fe-Pi:
	
		sudo mv /etc/asound.conf /etc/asound.conf.disabled
		mv ~/.config/pulse/default.pa ~/.config/pulse/default.pa.disabled

	and restart pulseaudio:
	
		systemctl --user start pulseaudio
		
1. Start the __RMS Gateway Manager__ app from the __Hamradio__ menu. Click __Configure__, then:

	- In the __Direwolf Capture ADEVICE__ field, select `plughw:CARD=Audio,DEV=0`
	- In the __Direwolf Playback ADEVICE__ field, select `plughw:CARD=Audio,DEV=0`
	- In the __Direwolf ACHANNELS__ field, select `2`
	- In the __Direwolf CHANNEL__ field, select:
		- `0` if your radio is connected to the LEFT side of the Nexus, or 
		- `1` if your radio is connected to the RIGHT side of the Nexus.
	
	The remaining settings should be fine. 
	
	- Click __Save__ to close the __Configure__ window and save the settings.
	- Click __[Re]start__ to start __AX25__.

1. Reboot and make sure all is working as expected.	

### Lingering AX25 Sockets

There's a bug in Linux kernel for Bullseye that causes a station that successfully connects to the RMS Gateway to not be able to connect again to that same gateway. That station's socket connection on the gateway goes into LISTENING mode rather than being removed as it should. As a workaround, the RMS Gateway Manager has a setting that enables a watchdog. This watchdog monitors the RMS Gateway for these leftover LISTENING sockets. If one is detected, the RMS Gateway service will automatically restart. To enable this feature:

1. Start the __RMS Gateway Manager__ app from the __Hamradio__ menu. Click __Configure__, then:

	- Check the __Enable autorestart watchdog for AX25 bug__ box.
	- Click __Save__ to close the __Configure__ window and save the settings.
	- Click __[Re]start__ to restart __AX25__.

1. Reboot and make sure all is working as expected.		

	
	
	










