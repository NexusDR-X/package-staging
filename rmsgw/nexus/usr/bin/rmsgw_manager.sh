#!/usr/bin/env bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+   ${SCRIPT_NAME} [-huv]
#%
#% DESCRIPTION
#%   This script provides a GUI to configure, start/stop, and 
#%   monitor the RMS Gateway applications.  
#%   It is designed to work on the Nexus image.
#%
#% OPTIONS
#%    -h, --help                  Print this help
#%    -u, --update                If the configuration file is present, this
#%                                option will update all the RMSGW related files
#%                                with the data from the configuration file, then exit.
#%    -v, --version               Print script information
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} 1.2.0
#-    author          Steve Magnuson, AG7GN
#-    license         CC-BY-SA Creative Commons License
#-    script_id       0
#-
#================================================================
#  HISTORY
#     20200428 : Steve Magnuson : Script creation.
#     20200507 : Steve Magnuson : Bug fixes
#     20210721 : Steve Magnuson : Add -u option
# 
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================

SYNTAX=false
DEBUG=false
Optnum=$#

#============================
#  FUNCTIONS
#============================

function TrapCleanup() {
   [[ -d "${TMPDIR}" ]] && rm -rf "${TMPDIR}/"
   for P in ${PIDs[@]}
	do
		kill $P >/dev/null 2>&1
	done
	pkill -f "yad --title=Configure RMS Gateway.*" >/dev/null 2>&1
	rm -f $PIPE
	unset CheckDaemon
	unset RestartAX25Service
	unset CheckDaemon 
	unset RestartAX25Service 
	unset ConfigureRMSGateway 
	unset SaveSettings 
	unset UpdateReporting 
	unset SetFormFields 
	unset LoadSettings
	unset WriteConfiguration
	unset RMSGW_CONFIG_FILE
	unset TMP_AX25_SERVICE
	unset RMSGW_TEMP_CONFIG
	unset PIPEDATA
}

function SafeExit() {
	EXIT_CODE=${1:-0}
   trap - INT TERM EXIT SIGINT
	TrapCleanup
   exit $EXIT_CODE
}

function ScriptInfo() { 
	HEAD_FILTER="^#-"
	[[ "$1" = "usage" ]] && HEAD_FILTER="^#+"
	[[ "$1" = "full" ]] && HEAD_FILTER="^#[%+]"
	[[ "$1" = "version" ]] && HEAD_FILTER="^#-"
	head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "${HEAD_FILTER}" | \
	sed -e "s/${HEAD_FILTER}//g" \
	    -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" \
	    -e "s/\${SPEED}/${SPEED}/g" \
	    -e "s/\${DEFAULT_PORTSTRING}/${DEFAULT_PORTSTRING}/g"
}

function Usage() { 
	printf "Usage: "
	ScriptInfo usage
	exit
}

function Die() {
	echo "${*}"
	SafeExit
}

function clearTextInfo() {
	# Arguments: $1 = sleep time.
	# Send FormFeed character every $1 minutes to clear yad text-info
	local TIMER=$1 
	while sleep $TIMER
	do
		#echo -e "\nTIMESTAMP: $(date)" 
		echo -e "\f"
		echo "$(date) Cleared monitor window. Window is cleared every $TIMER."
	done >$PIPEDATA
}

function CheckDaemon() {
	local TITLE="RMS Gateway Status"
	local STATUS=""
	local T=5
	if systemctl list-unit-files | grep -q "ax25.*enabled"
	then # ax25.service installed and enabled
	   STATUS="<b><big><span color='green'>Enabled"
	   if systemctl | grep -q "ax25.*running"
	   then
			STATUS+=" and Running</span></big></b>"
		else
	      STATUS+="</span><span color='red'> but Not Running</span></big></b>"
	   fi
	else # ax25.service not installed/enabled
		STATUS="<b><big><span color='red'>Not Enabled</span></big>\nClick 'Configure' to set up the RMS Gateway</b>"
	fi
  	yad --center --title="$TITLE" --text="$STATUS\nThis window will close in $T seconds" \
  		--width=400 --height=100 \
  		--borders=10 --text-align=center \
  		--timeout=$T --timeout-indicator=bottom \
  		--no-buttons
}

function RestartAX25Service() {
	if sudo systemctl enable ax25.service >$PIPEDATA 2>&1
#	if systemctl list-unit-files | grep enabled | grep -q ax25
	then # ax25 service is enabled.
		if systemctl | grep running | grep -q ax25.service
		then # ax25 is running.  Restart it.
			echo "Restarting ax25 service..." >$PIPEDATA
			sudo systemctl restart ax25 2>$PIPEDATA || echo -e "\n\n*** ERROR restarting: Is RMS Gateway configured?" >$PIPEDATA
		else # ax25 is stopped. Start it.
			echo "Starting ax25 service..." >$PIPEDATA
   		sudo systemctl start ax25 2>$PIPEDATA || echo -e "\n\n*** ERROR starting: Is RMS Gateway configured?" >$PIPEDATA
  		fi
	else # ax25 service is not enabled.  Create it.
   	echo -e "\n\n*** ERROR: ax25 service could not be enabled. Try reinstalling the RMS Gateway Manager." >$PIPEDATA
	fi
	return 0
}

function LoadSettings() {
	if [ -s "$RMSGW_CONFIG_FILE" ]
	then # There is a config file
   	echo "Configuration file $RMSGW_CONFIG_FILE found." >$PIPEDATA
	else # Set some default values in a new config file
   	echo "Configuration file $RMSGW_CONFIG_FILE not found.  Creating a new one with default values."  >$PIPEDATA
		echo "declare -gA F" > "$RMSGW_CONFIG_FILE"
		echo "F[_CALL_]='N0CALL'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SSID_]='10'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_PASSWORD_]='password'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SYSOP_]='John Smith'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_GRID_]='CN88ss'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADDR1_]='123 Main Street'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADDR2_]=''" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_CITY_]='Anytown'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_STATE_]='WA'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ZIP_]='98225'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_BEACON_]='!4850.00N/12232.27W]144.920MHzMy RMS Gateway'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_EMAIL_]='n0one@example.com'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_FREQ_]='144920000'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_POWER_]='3'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_HEIGHT_]='2'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_GAIN_]='7'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_DIR_]='0'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_HOURS_]='24/7'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_SERVICE_]='PUBLIC'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_TNC_]='direwolf'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_MODEM_]='1200'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADEVICE_CAPTURE_]='null'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADEVICE_PLAY_]='null'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ACHANNELS_]='1'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_CHANNEL_]='0'" >> "$RMSGW_CONFIG_FILE"
    	echo "F[_ARATE_]='96000'" >> "$RMSGW_CONFIG_FILE"
	  	echo "F[_PTT_]='GPIO 23'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_DWUSER_]='$(whoami)'" >> "$RMSGW_CONFIG_FILE"
  		echo "F[_BANNER_]='*** My Banner ***'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_REPORTS_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
   	echo "F[_ADDL_EMAIL_]=''" >> "$RMSGW_CONFIG_FILE"
   	if grep -q "on-watchdog" /lib/systemd/system/ax25.service 2>/dev/null
   	then
   		echo "F[_AUTORESTART_]='TRUE'" >> "$RMSGW_CONFIG_FILE"
   	else
   		echo "F[_AUTORESTART_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
		fi
	fi
	source "$RMSGW_CONFIG_FILE"
}

function SetFormFields () {
	
	# Set YAD variables
	TNCs="tncpi~direwolf"
	[[ $TNCs =~ ${F[_TNC_]} ]] && TNCs="$(echo "$TNCs" | sed "s/${F[_TNC_]}/\^${F[_TNC_]}/")" 

	MODEMs="300~1200~9600"
	[[ $MODEMs =~ ${F[_MODEM_]} ]] && MODEMs="$(echo "$MODEMs" | sed "s/${F[_MODEM_]}/\^${F[_MODEM_]}/")" 

	SERVICEs="PUBLIC~EMCOMM"
	[[ $SERVICEs =~ ${F[_SERVICE_]} ]] && SERVICEs="$(echo "$SERVICEs" | sed "s/${F[_SERVICE_]}/\^${F[_SERVICE_]}/")" 

	if pgrep pulseaudio >/dev/null 2>&1
	then # There may be pulseaudio ALSA devices.  Look for them.
		CAPTURE_IGNORE="$(pacmd list-sinks 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
		ADEVICE_CAPTUREs="$(arecord -L | grep -v "$CAPTURE_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '~' | sed 's/~$//')"
		PLAYBACK_IGNORE="$(pacmd list-sources 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
		ADEVICE_PLAYBACKs="$(aplay -L | grep -v "$PLAYBACK_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '~' | sed 's/~$//')"
	else  # pulseaudio isn't running.  Check only for null and plughw devices
   	ADEVICE_CAPTUREs="$(arecord -L | grep "^null\|^plughw" | tr '\n' '~' | sed 's/~$//')"
   	ADEVICE_PLAYBACKs="$(aplay -L | grep "^null\|^plughw" | tr '\n' '~' | sed 's/~$//')"
	fi
	[[ $ADEVICE_CAPTUREs =~ ${F[_ADEVICE_CAPTURE_]} ]] && ADEVICE_CAPTUREs="$(echo "$ADEVICE_CAPTUREs" | sed "s/${F[_ADEVICE_CAPTURE_]}/\^${F[_ADEVICE_CAPTURE_]}/")"
	[[ -z $ADEVICE_CAPTUREs ]] && ADEVICE_CAPTUREs="null"
	[[ $ADEVICE_PLAYBACKs =~ ${F[_ADEVICE_PLAY_]} ]] && ADEVICE_PLAYBACKs="$(echo "$ADEVICE_PLAYBACKs" | sed "s/${F[_ADEVICE_PLAY_]}/\^${F[_ADEVICE_PLAY_]}/")"
	[[ -z $ADEVICE_PLAYBACKs ]] && ADEVICE_PLAYBACKs="null"

	ACHANNELSs="1~2"
	[[ $ACHANNELSs =~ ${F[_ACHANNELS_]} ]] && ACHANNELSs="$(echo "$ACHANNELSs" | sed "s/${F[_ACHANNELS_]}/\^${F[_ACHANNELS_]}/")"

	CHANNELs="0~1"
	[[ $CHANNELs =~ ${F[_CHANNEL_]} ]] && CHANNELs="$(echo "$CHANNELs" | sed "s/${F[_CHANNEL_]}/\^${F[_CHANNEL_]}/")"

	ARATEs="44100~48000~96000"
	[[ $ARATEs =~ ${F[_ARATE_]} ]] && ARATEs="$(echo "$ARATEs" | sed "s/${F[_ARATE_]}/\^${F[_ARATE_]}/")" 

	PTTs="GPIO 12~GPIO 23"
	if [[ $PTTs =~ ${F[_PTT_]} ]]
	then
		PTTs="$(echo "$PTTs" | sed "s/${F[_PTT_]}/\^${F[_PTT_]}/")" 
	else
		PTTs+="~^${F[_PTT_]}"
	fi

}

function UpdateReporting () {
	#PAT_DIR="$HOME/.wl2kgw"
	PAT_DIR="$HOME/.config/pat"
   PAT_MBOX_DIR="/$HOME/.local/share/pat/mailbox"
	WHO="$USER"
	SCRIPT="$(command -v rmsgw-activity.sh)"
	#PAT="$(command -v pat) --config $PAT_DIR/config.json --mbox $PAT_DIR/mailbox --send-only --event-log /dev/null connect telnet"
	#PAT="$(command -v pat) --config $PAT_DIR/config.json --mbox $PAT_MBOX_DIR --send-only --event-log /dev/null connect telnet"
	CLEAN="find $PAT_MBOX_DIR/${F[_CALL_]}/sent -type f -mtime +30 -exec rm -f {} \;"
   # remove old style pat cron job, which used the default config.json pat configuration
	#OLDPAT="$(command -v pat) --send-only --event-log /dev/null connect telnet"
	#cat <(fgrep -i -v "$OLDPAT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
	if [[ ${F[_REPORTS_]} == "TRUE" ]]
	then # Daily email reports requested
		if [[ ${F[_EMAIL_]} =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:].]{2,4}$ ]]
		then # user has supplied a well-formed Sysop email address
      	echo "Setting up reporting." >$PIPEDATA
			if command -v pat >/dev/null 2>&1
			then
				# Check for pat's config file, config.json.  Create it if missing or corrupted.
				if $(command -v jq) . $PAT_DIR/config.json >/dev/null 2>&1
				then
					echo "$PAT_DIR/config.json exists." >$PIPEDATA
				else # config.json missing or corrupted.  Make a new one.
            	echo "Making new $PAT_DIR/config.json file." >$PIPEDATA
					[[ -f $PAT_DIR/config.json ]] && rm -f $PAT_DIR/config.json
            	mkdir -p $PAT_DIR
					cd $HOME
					export EDITOR=ed
					echo -n "" | pat --config $PAT_DIR/config.json configure >/dev/null 2>&1
				fi
 				cat $PAT_DIR/config.json | jq \
					--arg C "${F[_CALL_]}" \
					--arg P "${F[_PASSWORD_]}" \
					--arg L "${F[_GRID_]}" \
						'.mycall = $C | .secure_login_password = $P | .locator = $L' | sponge $PAT_DIR/config.json
				echo "Installing user $WHO cron job for daily RMSGW report generation and email" >$PIPEDATA
				if [[ -z ${F[_ADDL_EMAIL_]} ]]
				then
					EMAILs=${F[_EMAIL_]}
				else
					_EMAILs="$(echo "${F[_ADDL_EMAIL_]}" | tr -s ' ' | tr ' ' ',')"
					EMAILs="${F[_EMAIL_]},$_EMAILs"
				fi
            # Run rmsgw-activity.sh
				WHEN="1 0 * * *"
				#WHAT="$SCRIPT $EMAILs $PAT_DIR >/dev/null 2>&1"
				WHAT="$SCRIPT $EMAILs >/dev/null 2>&1"
				JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
				cat <(grep -i -v "$SCRIPT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
            # Send mail via telnet
				#WHEN="3 * * * *"
				#WHAT="$PAT >/dev/null 2>&1"
				#JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
				#cat <(fgrep -i -v "$PAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
				# Purge sent messages older than 30 days
				echo "Installing cron to purge sent messages older than 30 days" >$PIPEDATA
				WHEN="7 0 * * *"
				WHAT="$CLEAN"
				JOB="$WHEN $WHAT"
				cat <(grep -i -v "find.*${F[_CALL_]}" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
				echo "Done." >$PIPEDATA
				echo "Reporting setup complete." >$PIPEDATA
		else
				echo "pat not found but is needed to email reports. Reporting will not be enabled." >$PIPEDATA
				F[_REPORTS_]=FALSE
			fi
		else
			echo "Invalid or missing Sysop email address.  Reporting will not be enabled." >$PIPEDATA
			F[_REPORTS_]=FALSE
		fi
	else # Reporting disabled. Remove report cron job if present
		echo "Remove Reporting" >$PIPEDATA
		cat <(fgrep -i -v "$SCRIPT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
		#cat <(fgrep -i -v "$PAT" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
		cat <(fgrep -i -v "$CLEAN" <(sudo crontab -u $WHO -l)) | sudo crontab -u $WHO -
	fi
}

function WriteConfiguration () {

	# Do some minimal error checking
	if [[ ${F[_CALL_]} =~ ^N0(CALL|ONE)$ || \
			${F[_PASSWORD_]} == "" || \
			${F[_EMAIL_],,} =~ @example.com$ || \
			! ${F[_EMAIL_],,} =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:].]{2,4}$ ]]
	then
		echo -e "\n**** CONFIGURATION ERROR ****: Invalid Sysop call sign or empty password or\ninvalid email address.\RMSGW files not updated." >$PIPEDATA
		return 1
	fi

	# Update the various RMS gateway configuration files
	TEMPF=$RMSGW_TEMP_CONFIG
	#cd /usr/local/src/nexus/nexus-rmsgw/

	FNAME="/etc/rmsgw/channels.xml"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_SSID_|${F[_SSID_]}|" \
		-e "s|_PASSWORD_|${F[_PASSWORD_]}|" \
		-e "s|_GRID_|${F[_GRID_]}|" \
		-e "s|_FREQ_|${F[_FREQ_]}|" \
		-e "s|_MODEM_|${F[_MODEM_]}|" \
		-e "s|_POWER_|${F[_POWER_]}|" \
		-e "s|_HEIGHT_|${F[_HEIGHT_]}|" \
		-e "s|_GAIN_|${F[_GAIN_]}|" \
		-e "s|_DIR_|${F[_DIR_]}|" \
		-e "s|_HOURS_|${F[_HOURS_]}|" \
		-e "s|_SERVICE_|${F[_SERVICE_]}|" \
		"${FNAME}.template" > "$TEMPF" 
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/rmsgw/banner"
	echo "${F[_BANNER_]}" > "$TEMPF"
	sudo cp -f "$TEMPF" "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/rmsgw/gateway.conf"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_SSID_|${F[_SSID_]}|" \
		-e "s|_GRID_|${F[_GRID_]}|" \
		"${FNAME}.template" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/rmsgw/sysop.xml"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_PASSWORD_|${F[_PASSWORD_]}|" \
		-e "s|_GRID_|${F[_GRID_]}|" \
		-e "s|_SYSOP_|${F[_SYSOP_]}|" \
		-e "s|_ADDR1_|${F[_ADDR1_]}|" \
		-e "s|_ADDR2_|${F[_ADDR2_]}|" \
		-e "s|_CITY_|${F[_CITY_]}|" \
		-e "s|_STATE_|${F[_STATE_]}|" \
		-e "s|_ZIP_|${F[_ZIP_]}|" \
		-e "s|_EMAIL_|${F[_EMAIL_]}|" \
		"${FNAME}.template" > "$TEMPF" 
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/ax25/axports"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_SSID_|${F[_SSID_]}|g" \
		-e "s|_FREQ_|${F[_FREQ_]}|g" \
		-e "s|_MODEM_|${F[_MODEM_]}|g" \
		"${FNAME}.template" > "$TEMPF"
	[[ $? == 0 ]] || echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA
	# Check for a client wl2k line, save it if found and append it to new axports file
	if [ -f "$FNAME" ]
	then
		SAVE="$(grep "^wl2k[[:space:]]" "$FNAME" || [[ $? == 1 ]] 2>&1)"
		[[ $SAVE =~ wl2k ]] && echo -e "\n$SAVE" >> "$TEMPF"
	fi
	sudo cp -f "$TEMPF" "$FNAME"
	# Remove empty lines
	sudo sed -i '/^[[:space:]]*$/d' "$FNAME"
	sudo chmod ugo+r "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/ax25/ax25d.conf"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_SSID_|${F[_SSID_]}|g" \
		"${FNAME}.template" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	sudo chmod ugo+r "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

#	FNAME="/etc/ax25/ax25-up.new"
#	sed -e "s|_DWUSER_|${F[_DWUSER_]}|" \
#		-e "s|_TNC_|${F[_TNC_]}|" \
#		-e "s|_MODEM_|${F[_MODEM_]}|" \
#		"${FNAME}.template" > "$TEMPF"
#	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
#	sudo cp -f "$TEMPF" "$FNAME"
#	sudo chmod +x "$FNAME"
#	echo "$FNAME configured." >$PIPEDATA
#
#	FNAME="/etc/ax25/ax25-up.new2"
#	sed -e "s|_BEACON_|${F[_BEACON_]}|" "${FNAME}.template" > "$TEMPF"
#	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
#	sudo cp -f "$TEMPF" "$FNAME"
#	sudo chmod +x "$FNAME"
#	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/ax25/ax25-up.nexus"
	sed -e "s|_DWUSER_|${F[_DWUSER_]}|" \
		-e "s|_TNC_|${F[_TNC_]}|" \
		-e "s|_MODEM_|${F[_MODEM_]}|" \
		-e "s|_BEACON_|${F[_BEACON_]}|" \
		"${FNAME}.template" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	sudo chmod +x "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	FNAME="/etc/ax25/direwolf.conf"
	sed -e "s|_CALL_|${F[_CALL_]}|g" \
		-e "s|_PTT_|${F[_PTT_]}|" \
		-e "s|_MODEM_|${F[_MODEM_]}|" \
		-e "s|_ARATE_|${F[_ARATE_]}|" \
		-e "s|_ADEVICE_CAPTURE_|${F[_ADEVICE_CAPTURE_]}|" \
		-e "s|_ADEVICE_PLAY_|${F[_ADEVICE_PLAY_]}|" \
		-e "s|_ACHANNELS_|${F[_ACHANNELS_]}|" \
		-e "s|_CHANNEL_|${F[_CHANNEL_]}|" \
		"${FNAME}.template" > "$TEMPF"
	[[ $? == 0 ]] || { echo -e "\n**** CONFIGURATION ERROR ****: ERROR updating $FNAME" >$PIPEDATA; return 1; }
	sudo cp -f "$TEMPF" "$FNAME"
	sudo chmod ugo+r "$FNAME"
	echo "$FNAME configured." >$PIPEDATA

	echo "Setting up symlink for /etc/ax25/ax25-up" >$PIPEDATA
#	if ! [ -L /etc/ax25/ax25-up ]
#	then # There's no symlink for /etc/ax25/ax25-up
#   	[ -f /etc/ax25/ax25-up ] && sudo mv /etc/ax25/ax25-up /etc/ax25/ax25-up.previous
#   	sudo ln -s /etc/ax25/ax25-up.new /etc/ax25/ax25-up
#	fi
	if ! [[ -L /etc/ax25/ax25-up ]]
	then # There's no symlink for /etc/ax25/ax25-up
   	[ -f /etc/ax25/ax25-up ] && sudo mv /etc/ax25/ax25-up /etc/ax25/ax25-up.previous
	fi
	sudo ln -s /etc/ax25/ax25-up.nexus /etc/ax25/ax25-up
	echo "Done." >$PIPEDATA
	

	if grep -q "on-watchdog" /lib/systemd/system/ax25.service
	then
		sudo cp -f /lib/systemd/system/ax25.service.watchdog /lib/systemd/system/ax25.service
	else
		sudo cp -f /lib/systemd/system/ax25.service.nowatchdog /lib/systemd/system/ax25.service
	fi

	if [[ ${F[_AUTORESTART_]} == TRUE ]] && ! grep -q "on-watchdog" /lib/systemd/system/ax25.service
	then
		echo "Enabling AX25 autorestart workaround..." >$PIPEDATA
		sudo cp -f /lib/systemd/system/ax25.service.withwatchdog /lib/systemd/system/ax25.service
		sudo systemctl daemon-reload
		echo "Done." >$PIPEDATA
	elif [[ ${F[_AUTORESTART_]} == FALSE ]] && grep -q "on-watchdog" /lib/systemd/system/ax25.service
	then
		echo "Disabling AX25 autorestart workaround..." >$PIPEDATA
		sudo cp -f /lib/systemd/system/ax25.service.nowatchdog /lib/systemd/system/ax25.service
		sudo systemctl daemon-reload
		echo "Done." >$PIPEDATA
	else
		echo "No AX25 autorestart change requested" >$PIPEDATA
	fi
	return 0

}

function SaveSettings () {
	IFS='~' read -r -a TF < "$RMSGW_TEMP_CONFIG"
	F[_CALL_]="${TF[0]^^}"
	F[_SSID_]="${TF[1]}"
	F[_PASSWORD_]="${TF[2]}"
	F[_SYSOP_]="${TF[3]}"
	F[_GRID_]="${TF[4]}"
	F[_ADDR1_]="${TF[5]}"
	F[_ADDR2_]="${TF[6]}"
	F[_CITY_]="${TF[7]}"
	F[_STATE_]="${TF[8]}"
	F[_ZIP_]="${TF[9]}"
	F[_BEACON_]="${TF[10]}"
	F[_EMAIL_]="${TF[11]}"
	F[_FREQ_]="${TF[12]}"
	F[_POWER_]="${TF[13]}"
	F[_HEIGHT_]="${TF[14]}"
	F[_GAIN_]="${TF[15]}"
	F[_DIR_]="${TF[16]}"
	F[_HOURS_]="${TF[17]}"
	F[_SERVICE_]="${TF[18]}"
	F[_TNC_]="${TF[19]}"
	F[_MODEM_]="${TF[20]}"
	F[_ADEVICE_CAPTURE_]="${TF[21]}"
	F[_ADEVICE_PLAY_]="${TF[22]}"
	F[_ACHANNELS_]="${TF[23]}"
	F[_CHANNEL_]="${TF[24]}"
	F[_ARATE_]="${TF[25]}"
	F[_PTT_]="${TF[26]}"
	F[_DWUSER_]="${TF[27]}"
	F[_BANNER_]="$(echo "${TF[28]}" | sed "s/'//g")" # Strip out single quotes
	F[_REPORTS_]="${TF[29]}"
	F[_ADDL_EMAIL_]="${TF[30]}"
	F[_AUTORESTART_]="${TF[31]}"

	# Do some minimal error checking
	if [[ ${F[_CALL_]} =~ ^N0(CALL|ONE)$ || \
			${F[_PASSWORD_]} == "" || \
			${F[_EMAIL_],,} =~ @example.com$ || \
			! ${F[_EMAIL_],,} =~ ^[[:alnum:]._%+-]+@[[:alnum:].-]+\.[[:alpha:].]{2,4}$ ]]
	then
		echo -e "\n**** CONFIGURATION ERROR ****: Invalid Sysop call sign or empty password or\ninvalid email address." >$PIPEDATA
		return 1
	fi

	UpdateReporting
	# fepi-capture|playback-left|right are already mono, so force mono and left channel
	if [[ ${F[_ADEVICE_CAPTURE_]} =~ fepi ]]
	then
		F[_ACHANNELS_]='1'
		F[_CHANNEL_]='0'
	fi
	
	# Update the configuration file
	echo "declare -gA F" > "$RMSGW_CONFIG_FILE"
	for I in "${!F[@]}"
	do
		echo "F[$I]='${F[$I]}'" >> "$RMSGW_CONFIG_FILE"
	done
	source "$RMSGW_CONFIG_FILE"

	WriteConfiguration

	# Set permissions
	#sudo chown -R rmsgw:rmsgw /etc/rmsgw/*
	return 0
}

function ConfigureRMSGateway () {
	CONFIGURE_TEXT="<b><big><big>RMS Gateway Configuration Parameters</big></big></b>\n \
<span color='blue'>See http://www.aprs.net/vm/DOS/PROTOCOL.HTM for power, height, gain, dir and beacon message format.</span>\n \
<b><span color='red'>CAUTION:</span></b> Do not use the tilde '<b>~</b>' character in any field below.\n"

	while true
	do
		# Retrieve saved settings or defaults if there are no saved settings
		LoadSettings
		if ! [[ -n "${F[_REPORTS_]}" ]]
		then # Older versions of config file didn't have REPORTS. Add if necessary.
			F[_REPORTS_]='FALSE'
			echo "F[_REPORTS_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
		fi
		if ! [[ -n "${F[_AUTORESTART_]}" ]]
		then # Older versions of config file didn't have AUTORESTART. Add if necessary.
			F[_AUTORESTART_]='FALSE'
			echo "F[_AUTORESTART_]='FALSE'" >> "$RMSGW_CONFIG_FILE"
		fi
		if ! [[ -n "${F[_ACHANNELS_]}" ]]
		then # Older versions of config file didn't have ACHANNELS. Add if necessary.
			F[_ACHANNELS_]=1
			echo "F[_ACHANNELS_]='1'" >> "$RMSGW_CONFIG_FILE"
		fi
		if ! [[ -n "${F[_CHANNEL_]}" ]]
		then # Older versions of config file didn't have CHANNEL. Add if necessary.
			F[_CHANNEL_]=0
			echo "F[_CHANNEL_]='0'" >> "$RMSGW_CONFIG_FILE"
		fi
		SetFormFields
	
		> $RMSGW_TEMP_CONFIG
		# Start the Configure RMSGW tab
		CMD=(
			yad --title="Configure RMS Gateway $VERSION" --width=1000 --height=750	
  			--text="$CONFIGURE_TEXT"
  			--item-separator="~"
			--separator="~" 
  			--center
  			--buttons-layout=center
  			--columns=2
  			--text-align=center
  			--align=right
  			--borders=20
  			--form
  			--field="Call Sign" 
  			--field="SSID":NUM 
  			--field="Winlink Password":H 
  			--field="Sysop Name" 
  			--field="Grid Square" 
  			--field="Street Address1" 
  			--field="Street Address2" 
  			--field="City" 
  			--field="State" 
  			--field="ZIP" 
  			--field="Beacon message\n(Empty disables beacon)" 
  			--field="Sysop Email" 
  			--field="Frequency (Hz)" 
  			--field="Power SQR(P)":NUM 
  			--field="Antenna Height LOG2(H/10)":NUM 
  			--field="Antenna Gain (dB)":NUM 
  			--field="Direction (D/45)":NUM 
  			--field="Hours" 
  			--field="Service Code":CB 
  			--field="TNC Type":CB 
  			--field="MODEM":CB 
  			--field="Direwolf Capture ADEVICE":CB 
  			--field="Direwolf Playback ADEVICE":CB
  			--field="Direwolf <b>ACHANNELS</b>: <b>1</b> for fepi\nor Mono ADEVICE; <b>2</b> for Stereo":CB
  			--field="Direwolf <b>CHANNEL</b>: <b>0</b> for fepi or\n stereo left; <b>1</b> for stereo right":CB  
  			--field="Direwolf ARATE":CB 
  			--field="Direwolf PTT":CBE 
  			--field="Direwolf User" 
  			--field="Banner Text (keep it short!)" 
  			--field="Send daily activity reports to Sysop email address":CHK 
  			--field="Add'l Activity Report Email(s)\n(Use comma to separate emails)"
  			--field="Enable autorestart watchdog for AX25 bug":CHK
			--button="<b>Close</b>":1 \
			--button="<b>Save</b>":0 \
			--
			"${F[_CALL_]}"
			"${F[_SSID_]}~1..15~1~"
			"${F[_PASSWORD_]}"
			"${F[_SYSOP_]}"
			"${F[_GRID_]}"
			"${F[_ADDR1_]}"
			"${F[_ADDR2_]}"
			"${F[_CITY_]}"
			"${F[_STATE_]}"
			"${F[_ZIP_]}"
			"${F[_BEACON_]}"
			"${F[_EMAIL_]}"
			"${F[_FREQ_]}"
			"${F[_POWER_]}~0..9~1~"
			"${F[_HEIGHT_]}~0..9~1~"
			"${F[_GAIN_]}~0..9~1~"
			"${F[_DIR_]}~0..9~1~"
			"${F[_HOURS_]}"
			"$SERVICEs"
			"$TNCs"
			"$MODEMs"
			"$ADEVICE_CAPTUREs"
			"$ADEVICE_PLAYBACKs"
			"$ACHANNELSs"
			"$CHANNELs"
			"$ARATEs"
			"$PTTs"
			"${F[_DWUSER_]}"
			"${F[_BANNER_]}"
			"${F[_REPORTS_]}"
			"${F[_ADDL_EMAIL_]}"
			"${F[_AUTORESTART_]}"
		)
		"${CMD[@]}" > $RMSGW_TEMP_CONFIG
		
		case $? in
			0) # Save changes and [re]start.
				[[ -s $RMSGW_TEMP_CONFIG ]] || Die "Unexpected input from configuration tab"
				if SaveSettings
				then # Configuration looks OK
					# Add Auto-Check-in script to cron
					#    Generate 2 numbers between 1 and 59, M minutes apart to 
					#    use for the cron job
					echo "Updating crontab for user rmsgw to run Winlink Auto Check-in..." >$PIPEDATA
					M=30
					N1=$(( $RANDOM % 59 + 1 ))
					N2=$(( $N1 + $M ))
					(( $N2 > 59 )) && N2=$(( $N2 - 60 ))
					INTERVAL="$(echo "$N1 $N2" | xargs -n1 | sort -g | xargs | tr ' ' ',')"
					WHO="rmsgw"
					WHEN="$INTERVAL * * * *"
					WHAT="/usr/bin/rmsgw_aci >/dev/null 2>&1"
					JOB="$WHEN PATH=\$PATH:/usr/local/bin; $WHAT"
					cat <(fgrep -i -v "$WHAT" <(sudo crontab -u $WHO -l)) <(echo "$JOB") | sudo crontab -u $WHO -
					echo "Done." >$PIPEDATA
					echo -e "\nConfiguration is OK. Click '[Re]start' button below to activate." >$PIPEDATA
					break
				else # Error in configuration
					echo >$PIPEDATA
					#echo -e "\n***ERROR: Configuration is invalid. Re-check your settings." >$PIPEDATA
				fi
				;;
			*) # User cancelled. Exit.
				#echo "Configuration dialog closed." >$PIPEDATA
				break
				;;
		esac
done
}

#============================
#  FILES AND VARIABLES
#============================

# Set Temp Directory
# -----------------------------------
# Create temp directory with three random numbers and the process ID
# in the name.  This directory is removed automatically at exit.
# -----------------------------------
TMPDIR="/tmp/${SCRIPT_NAME}.$RANDOM.$RANDOM.$RANDOM.$$"
(umask 077 && mkdir "${TMPDIR}") || {
  Die "Could not create temporary directory! Exiting."
}

  #== general variables ==#
SCRIPT_NAME="$(basename ${0})" # scriptname without path
SCRIPT_DIR="$( cd $(dirname "$0") && pwd )" # script directory
SCRIPT_FULLPATH="${SCRIPT_DIR}/${SCRIPT_NAME}"
SCRIPT_ID="$(ScriptInfo | grep script_id | tr -s ' ' | cut -d' ' -f3)"
SCRIPT_HEADSIZE=$(grep -sn "^# END_OF_HEADER" ${0} | head -1 | cut -f1 -d:)
VERSION="$(ScriptInfo version | grep version | tr -s ' ' | cut -d' ' -f 4)" 

APP_NAME="RMS Gateway Manager"
TITLE="$APP_NAME $VERSION"
#RMSGW_CONFIG_FILE="$HOME/rmsgw.conf"
mkdir -p "$HOME/.config/nexus"
RMSGW_CONFIG_FILE="$HOME/.config/nexus/rmsgw.conf"
LOGFILES="/var/log/rms.debug /var/log/ax25-listen.log /var/log/packet.log"
TEXT="<b><big><span color='blue'>RMS Gateway Manager</span></big></b>\nFollowing $LOGFILES"

PIPE=$TMPDIR/pipe
mkfifo $PIPE
exec 9<> $PIPE

export -f CheckDaemon RestartAX25Service ConfigureRMSGateway SaveSettings UpdateReporting SetFormFields LoadSettings WriteConfiguration
export PIPEDATA=$PIPE
export RMSGW_CONFIG_FILE
export RMSGW_TEMP_CONFIG=$TMPDIR/CONFIGURE_RMSGW.txt
export TMP_AX25_SERVICE=$TMPDIR/ax25.service

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================
  
#== set short options ==#
SCRIPT_OPTS=':huv-:'

#== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
	[update]=u
	[version]=v
)

LONG_OPTS="^($(echo "${!ARRAY_OPTS[@]}" | tr ' ' '|'))="

# Parse options
while getopts ${SCRIPT_OPTS} OPTION
do
	# Translate long options to short
	if [[ "x$OPTION" == "x-" ]]
	then
		LONG_OPTION=$OPTARG
		LONG_OPTARG=$(echo $LONG_OPTION | egrep "$LONG_OPTS" | cut -d'=' -f2-)
		LONG_OPTIND=-1
		[[ "x$LONG_OPTARG" = "x" ]] && LONG_OPTIND=$OPTIND || LONG_OPTION=$(echo $OPTARG | cut -d'=' -f1)
		[[ $LONG_OPTIND -ne -1 ]] && eval LONG_OPTARG="\$$LONG_OPTIND"
		OPTION=${ARRAY_OPTS[$LONG_OPTION]}
		[[ "x$OPTION" = "x" ]] &&  OPTION="?" OPTARG="-$LONG_OPTION"
		
		if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]
		then
			if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]
			then 
				OPTION=":" OPTARG="-$LONG_OPTION"
			else
				OPTARG="$LONG_OPTARG";
				if [[ $LONG_OPTIND -ne -1 ]]
				then
					[[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
					shift $OPTIND
					OPTIND=1
				fi
			fi
		fi
	fi

	# Options followed by another option instead of argument
	if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]] 		
	then 
		OPTARG="$OPTION" OPTION=":"
	fi

	# Finally, manage options
	case "$OPTION" in
		h) 
			ScriptInfo full
			exit 0
			;;
		u) 
			# Kill earlier running scripts
			kill -9 $(pgrep -f "yad.*$APP_NAME" | grep -v $$) 2>/dev/null
			if [[ -s $RMSGW_CONFIG_FILE ]] && WriteConfiguration
			then
				echo "${SCRIPT_NAME}: Configuration files written"
				SafeExit
			else
				Die "${SCRIPT_NAME}: $RMSGW_CONFIG_FILE empty or not found"
				SafeExit 1
			fi
			;;
		v) 
			ScriptInfo version
			exit 0
			;;
		:) 
			Die "${SCRIPT_NAME}: -$OPTARG: option requires an argument"
			;;
		?) 
			Die "${SCRIPT_NAME}: -$OPTARG: unknown option"
			;;
	esac
done
shift $((${OPTIND} - 1)) ## shift options

# Ensure only one instance of this script is running.
pidof -o %PPID -x $(basename "$0") >/dev/null && Die "$(basename $0) already running."

# Check for required apps.
for A in yad jq sponge pat 
do 
	command -v $A >/dev/null 2>&1 || Die "$A is required but not installed."
done

#============================
#  MAIN SCRIPT
#============================

# Trap bad exits with cleanup function
trap SafeExit EXIT INT TERM SIGINT

# Exit on error. Append '||true' when you run the script if you expect an error.
#set -o errexit

# Check Syntax if set
$SYNTAX && set -n
# Run in debug mode, if set
$DEBUG && set -x 

# Update older configuration files as necessary
#   Move configuration file to ~/.config/nexus
[[ -f "$HOME/rmsgw.conf" ]] && mv "$HOME/rmsgw.conf" "$RMSGW_CONFIG_FILE" 
#   Make configuration file array global
[[ -s $RMSGW_CONFIG_FILE ]] && sed -i -e 's/^declare -A/declare -gA/1' $RMSGW_CONFIG_FILE

systemctl is-active --quiet ax25 && echo -e "\nax25.service is ACTIVE\n" >>/var/log/packet.log || \
echo -e "\nax25.service is NOT active\n" >>/var/log/packet.log

PIDs=()
# Uncomment the following 2 lines to purge yad text-info periodically.
#clearTextInfo 120m &
#PIDs=( $! )
# Start the log file monitor
yad --title="$TITLE" --text-align="center" --window-icon=logviewer \
	--text="$TEXT" --back=black --fore=yellow --text-info \
	--posx=10 --posy=45 --width=1000 --height=500 \
	--tail --listen --buttons-layout=center \
	--button="<b>Close</b>":0 \
	--button="<b>Status</b>":"bash -c CheckDaemon" \
	--button="<b>Stop</b>":"bash -c 'sudo systemctl stop ax25.service 2>/dev/null'" \
	--button="<b>[Re]start</b>":"bash -c RestartAX25Service" \
	--button="<b>Configure</b>":"bash -c ConfigureRMSGateway" <&9 &
monitor_PID=$!
PIDs+=( $monitor_PID )
[[ -s $RMSGW_CONFIG_FILE ]] || echo "RMS Gateway appears to be unconfigured. Click 'Configure' below." >&9
tail -F --pid=$monitor_PID -q -n 30 $LOGFILES 2>/dev/null | cat -v >&9
SafeExit

