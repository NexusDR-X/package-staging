#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+   ${SCRIPT_NAME} [-hv]
#%
#% DESCRIPTION
#%   This script provides a GUI to configure and start/stop
#%   ARDOP (ardopc) and pat.  It is designed to work on the 
#%   Nexus DR-X image.
#%
#% OPTIONS
#%    -h, --help                  Print this help
#%    -v, --version               Print script information
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} 1.1.1
#-    author          Steve Magnuson, AG7GN
#-    license         CC-BY-SA Creative Commons License
#-    script_id       0
#-
#================================================================
#  HISTORY
#     20200718 : Steve Magnuson : Script creation.
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
   kill $timeStamp_PID >/dev/null 2>&1
   killARDOP
   kill $pat_PID >/dev/null 2>&1
	kill $RIG_PID >/dev/null 2>&1
   for P in ${YAD_PIDs[@]}
	do
		kill $P >/dev/null 2>&1
	done
   sudo pkill kissattach >/dev/null 2>&1
   rm -f /tmp/kisstnc
   rm -f $PIPE
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

function Die () {
	echo "${*}"
	SafeExit
}

function Sender () {
	# Data piped to this function is sent to a socat pipe, prepended by the 
	# app name (optional) and a time stamp
   declare input=${1:-$(</dev/stdin)}
   declare APP="${1:-}"
   [[ -n $APP ]] && APP="${APP} "
   cat -v | ts "$APP $TIME_FORMAT" | socat - udp-sendto:127.255.255.255:$SOCAT_PORT,broadcast
}

function loadpatDefaults () {
   for I in $(seq 7 10)
   do # I is the field number.  D[$I] is the default value
      echo "${I}:${D[$I]}"
   done
}

function setAX25Defaults () {
	AX25[1]="wl2k"	# Port
   AX25[2]="200"	# TX Delay
	AX25[3]="50"	# TX Tail
   AX25[4]="64"	# Persist
   AX25[5]="20"	# Slot Time
   AX25[6]="60"	# Audio Stats
}


function setARDOPDefaults () {
   declare -gA ARDOP
   ARDOP[1]="null"		# Audio capture interface (ADEVICE)
   ARDOP[2]="null"		# Audio playback interface (ADEVICE)
   ARDOP[3]="GPIO 12"	# GPIO PTT (BCM pin)
   ARDOP[4]="8515"		# ARDOP Port
   ARDOP[5]="FALSE"		# Enable pat HTTP server
   ARDOP[6]="-l /dev/null/" # Optional piardopc arguments
}

function setDirewolfDefaults () {
   declare -gA DW
   DW[1]="N0CALL"  # Call sign
   DW[2]="1200" # Modem
   DW[3]="null" # Audio capture interface (ADEVICE)
   DW[4]="null" # Audio playback interface (ADEVICE)
   DW[5]="48000" # Audio playback rate (ARATE)
   DW[6]="GPIO 23" # GPIO PTT (BCM pin)
   DW[7]="200" # TX Delay
	DW[8]="50" # TX Tail
   DW[9]="64"  # Persist
   DW[10]="20" # Slot Time
   DW[11]="60" # Audio Stats
   DW[12]="8001" # AGW Port
   DW[13]="8011"  # KISS Port
   DW[14]="TRUE" # Enable pat HTTP server
   DW[15]="disabled" # Disable piano switch autostart
}

function loadSettings () {
	 
   PTTs="GPIO 12!GPIO 23!rig control via client"
	ARDOP_CONFIG="$TMPDIR/ardop.conf"
	PAT_ARQ_BW_MAXs="200!500!1000!2000"

	if [ -s "$CONFIG_FILE" ]
	then # There is a config file
   	echo "$CONFIG_FILE found." >&8
  		source "$CONFIG_FILE"
	else # Set some default values in a new config file
   	echo -e "Config file $CONFIG_FILE not found.\nCreating a new one with default values." >&8
		setARDOPpatDefaults
   	echo "declare -gA F" > "$CONFIG_FILE"
   	echo "F[_ADEVICE_CAPTURE_]='${D[1]}'" >> "$CONFIG_FILE"
   	echo "F[_ADEVICE_PLAY_]='${D[2]}'" >> "$CONFIG_FILE"
   	echo "F[_PTT_]='${D[3]}'" >> "$CONFIG_FILE"
   	echo "F[_ARDOPPORT_]='${D[4]}'" >> "$CONFIG_FILE"
   	echo "F[_PAT_HTTP_]='${D[5]}'" >> "$CONFIG_FILE"
   	echo "F[_ARDOP_ARGS_]='${D[6]}'" >> "$CONFIG_FILE"
   	source "$CONFIG_FILE"
	fi
	if pgrep pulseaudio >/dev/null 2>&1
   then # There may be pulseaudio ALSA devices.  Look for them.
      CAPTURE_IGNORE="$(pacmd list-sinks 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
      ADEVICE_CAPTUREs="$(arecord -L | grep -v "$CAPTURE_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '!' | sed 's/!$//')"
      PLAYBACK_IGNORE="$(pacmd list-sources 2>/dev/null | grep name: | tr -d '\t' | cut -d' ' -f2 | sed 's/^<//;s/>$//' | tr '\n' '\|' | sed 's/|/\\|/g')"
      ADEVICE_PLAYBACKs="$(aplay -L | grep -v "$PLAYBACK_IGNORE^ .*\|^dsnoop\|^sys\|^default\|^dmix\|^hw\|^usbstream\|^jack\|^pulse" | tr '\n' '!' | sed 's/!$//')"
   else  # pulseaudio isn't running.  Check only for null and plughw devices
      ADEVICE_CAPTUREs="$(arecord -L | grep "^null\|^plughw" | tr '\n' '!' | sed 's/!$//')"
      ADEVICE_PLAYBACKs="$(aplay -L | grep "^null\|^plughw" | tr '\n' '!' | sed 's/!$//')"
   fi
   [[ $ADEVICE_CAPTUREs =~ ${F[_ADEVICE_CAPTURE_]} ]] && ADEVICE_CAPTUREs="$(echo "$ADEVICE_CAPTUREs" | sed "s/${F[_ADEVICE_CAPTURE_]}/\^${F[_ADEVICE_CAPTURE_]}/")"
   [[ $ADEVICE_CAPTUREs == "" ]] && ADEVICE_CAPTUREs="null"
   [[ $ADEVICE_PLAYBACKs =~ ${F[_ADEVICE_PLAY_]} ]] && ADEVICE_PLAYBACKs="$(echo "$ADEVICE_PLAYBACKs" | sed "s/${F[_ADEVICE_PLAY_]}/\^${F[_ADEVICE_PLAY_]}/")"
   [[ $ADEVICE_PLAYBACKs == "" ]] && ADEVICE_PLAYBACKs="null"

	if [[ $PTTs =~ ${F[_PTT_]} ]]
   then
      PTTs="$(echo "$PTTs" | sed "s/${F[_PTT_]}/\^${F[_PTT_]}/")"
   else
      PTTs+="!^${F[_PTT_]}"
   fi
	
	ARDOPPORT="${F[_ARDOPPORT_]}"

	PAT_START_HTTP="${F[_PAT_HTTP_]}"
	PAT_CALL="$(jq -r ".mycall" $PAT_CONFIG)"
	PAT_PASSWORD="$(jq -r ".secure_login_password" $PAT_CONFIG)"
	PAT_HTTP_PORT="$(jq -r ".http_addr" $PAT_CONFIG | cut -d: -f2)"
	PAT_TELNET_PORT="$(jq -r ".telnet.listen_addr" $PAT_CONFIG | cut -d: -f2)"
	PAT_LOCATOR="$(jq -r ".locator" $PAT_CONFIG)"
	PAT_ARDOPPORT="$(jq -r ".ardop.addr" $PAT_CONFIG | cut -d: -f2)"
	PAT_ARQ_BW_FORCED="$(jq -r ".ardop.arq_bandwidth.Forced" $PAT_CONFIG)"
	PAT_ARQ_BW_MAX="$(jq -r ".ardop.arq_bandwidth.Max" $PAT_CONFIG)"
	if [[ $PAT_ARQ_BW_MAXs =~ $PAT_ARQ_BW_MAX ]]
	then
		PAT_ARQ_BW_MAXs="$(echo $PAT_ARQ_BW_MAXs | sed -e "s/$PAT_ARQ_BW_MAX/\^$PAT_ARQ_BW_MAX/")"
	else
		PAT_ARQ_BW_MAXs="$(echo $PAT_ARQ_BW_MAXs | sed -e "s/500/\^500/")"
	fi
	PAT_BEACON_INTERVAL="$(jq -r ".ardop.beacon_interval" $PAT_CONFIG)"
	PAT_CW_ID="$(jq -r ".ardop.cwid_enabled" $PAT_CONFIG)"
}

function timeStamp () {
	while sleep 60
	do
		echo -e "\nTIMESTAMP: $(date)" 
	done >$PIPEDATA
}

function killARDOP () {
	# $1 is the ardop PID
	ardopPIDs="$(pgrep -f $ARDOP | xargs)"
	if [[ -n $ardopPIDs ]]
	then
		kill -9 $ardopPIDS
		echo -e "\n\nardopc stopped.  Click \"Save Settings...\" button below to restart." >$PIPEDATA
	else		
		echo -e "\n\nardopc was already stopped.  Click \"Save Settings...\" button below to restart." >$PIPEDATA
	fi
}

function trim() {
  # Trims leading and trailing white space from a string
  local s2 s="$*"
  until s2="${s#[[:space:]]}"; [ "$s2" = "$s" ]; do s="$s2"; done
  until s2="${s%[[:space:]]}"; [ "$s2" = "$s" ]; do s="$s2"; done
  echo "$s"
}

function getRig() {
#   # Prints make and model of rig of currently running rigctld.
#   if pgrep rigctld >/dev/null 2>&1
#   then
#   	local ID="$(cat /proc/$(pidof rigctld)/cmdline | tr -d '\0' | tr '-' '\n' | egrep "^m[0-9]{1,4}" | sed -e 's/^m//')"
#		local LINE="$($(command -v rigctl) -l | grep -v "^ Rig" | egrep "^[[:space:]]*$ID ")"
#		local N="$(trim "${LINE:2:4}")"
#		local M="$(trim "${LINE:8:23}")"
#  		local O="$(trim "${LINE:31:24}")"
#		echo "\n<span color='green'><b>Rig Control is RUNNING for $M $O rig</b></span>"
#	else
#		echo "\n<span color='red'><b>Rig Control is NOT RUNNING</b></span>"
#	fi
   echo ""
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

TITLE="ARDOP Monitor and Configuration $VERSION"
CONFIG_FILE="$HOME/ardop.conf"
MESSAGE="ARDOP Configuration"

ID="${RANDOM}"

PAT_CONFIG="$HOME/.config/pat/config.json"

RETURN_CODE=0
#ARDOP="$(command -v piardopc)"
ARDOP="$(command -v ardopc)"
#PAT="$(command -v pat) --log /dev/stdout -l ax25,telnet http"
PAT="$(command -v pat) -l ardop,telnet http"

PIPE=$TMPDIR/pipe
mkfifo $PIPE
exec 8<> $PIPE

#============================
#  PARSE OPTIONS WITH GETOPTS
#============================
  
#== set short options ==#
SCRIPT_OPTS=':hv-:'

#== set long options associated with short one ==#
typeset -A ARRAY_OPTS
ARRAY_OPTS=(
	[help]=h
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
		
		if [[ $( echo "${SCRIPT_OPTS}" | grep -c "${OPTION}:" ) -eq 1 ]]; then
			if [[ "x${LONG_OPTARG}" = "x" ]] || [[ "${LONG_OPTARG}" = -* ]]; then 
				OPTION=":" OPTARG="-$LONG_OPTION"
			else
				OPTARG="$LONG_OPTARG";
				if [[ $LONG_OPTIND -ne -1 ]]; then
					[[ $OPTIND -le $Optnum ]] && OPTIND=$(( $OPTIND+1 ))
					shift $OPTIND
					OPTIND=1
				fi
			fi
		fi
	fi

	# Options followed by another option instead of argument
	if [[ "x${OPTION}" != "x:" ]] && [[ "x${OPTION}" != "x?" ]] && [[ "${OPTARG}" = -* ]]; then 
		OPTARG="$OPTION" OPTION=":"
	fi

	# Finally, manage options
	case "$OPTION" in
		h) 
			ScriptInfo full
			exit 0
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
pidof -o %PPID -x $(basename "$0") >/dev/null && exit 1

# Check for required apps.
for A in yad pat jq sponge rigctld ardopc
do 
	command -v $A >/dev/null 2>&1 || Die "$A is required but not installed."
done

# If this is the first time running this script, don't attempt to start Direwolf
# or pat until user configures both.
if [[ -s $PAT_CONFIG && -s $CONFIG_FILE ]]
then # ARDOP and pat configuration files exist
	if [[ $(jq -r ".mycall" $PAT_CONFIG) == "" ||  ${F[_ADEVICE_CAPTURE_]} == "null" ]]
	then # Config files present, but not configured
		FIRST_RUN=true
	else # Config files present and configured
		FIRST_RUN=false
	fi
else # No configuration files exist
	FIRST_RUN=true
fi

# Check for pat's config file, config.json.  Create it if missing or corrupted.
RESULT="$(jq . $PAT_CONFIG 2>/dev/null)"
if [[ $RESULT == "" ]]
then # config.json missing or corrupted.  Make a new one.
	[[ -f $PAT_CONFIG ]] && rm $PAT_CONFIG
	cd $HOME
	export EDITOR=ed
	echo -n "" | pat configure >/dev/null 2>&1
fi

# Set up pat for rigctl in config.json
cat $PAT_CONFIG | jq \
   '.hamlib_rigs += {"network": {"address": "localhost:4532", "network": "tcp"}}' | sponge $PAT_CONFIG
# Add the network Hamlib rig to the ardop section
cat $PAT_CONFIG | jq --arg R "network" '.ardop.rig = $R' | sponge $PAT_CONFIG

export -f setARDOPpatDefaults loadpatDefaults
export load_pat_defaults_cmd='@bash -c "setARDOPpatDefaults; loadpatDefaults"'
export PIPEDATA=$PIPE

#============================
#  MAIN SCRIPT
#============================

# Trap bad exits with cleanup function
trap SafeExit EXIT INT TERM

# Exit on error. Append '||true' when you run the script if you expect an error.
set -o errexit

# Check Syntax if set
$SYNTAX && set -n
# Run in debug mode, if set
$DEBUG && set -x 

timeStamp &
timeStamp_PID=$!

ardop_PID=""
pat_PID=""
YAD_PIDs=()

while true
do
	# Kill any running processes and load latest settings
	#killARDOP $ardop_PID
	killARDOP
	[[ $pat_PID == "" ]] || kill $pat_PID >/dev/null 2>&1
   for P in ${YAD_PIDs[@]}
	do
		ps x | egrep -q "^$P" && kill $P
	done
	loadSettings
	YAD_PIDs=()
	
	# Start the tail window tab
	TEXT="ARDOP Port: <span color='blue'><b>${F[_ARDOPPORT_]}</b></span>"
	[[ $PAT_START_HTTP == TRUE ]] && TEXT+="   pat Telnet Port: <span color='blue'><b>$PAT_TELNET_PORT</b></span>   pat Web Server: <span color='blue'><b>http://$HOSTNAME.local:$PAT_HTTP_PORT</b></span>$(getRig)"
	yad --plug="$ID" --tabnum=1 \
		--back=black --fore=yellow --selectable-labels \
		--text-info --text-align=center --text="$TEXT" \
		--tail --center <&8 &
	YAD_PIDs+=( $! )

	# Start rigctld.  
	if pgrep rigctld >/dev/null
	then
		echo "rigctld already running." >&8
	else # Start rigctl as a dummy rig because we have no idea what rig is used.
		echo "Starting rigctld using dummy rig..." >&8
		$(command -v rigctld) -m 1 >&8 2>&8 &
		RIG_PID=$!
		echo "Done." >&8
	fi

	if [[ $FIRST_RUN == true ]]
	then
		echo -e "Configure ARDOP and pat in the \"Configure ARDOP\" and \"Configure pat\" tabs,\nthen click \"Save Settings...\" button below." >&8
	else # Not a first run.  pat and ARDOP configured so start 'em
		# Check what PTT was selected
		if [[ ${F[_PTT_]} =~ GPIO ]]
		then # Let ardopc control PTT gia GPIO
			ARDOP_PTT="-p $(echo "${F[_PTT_]}" | tr ' ' '=')"
		else # Let pat control PTT via rigctl
			ARDOP_PTT=""
		fi
		# Start ardopc
		# If no ardopc logging specified as an argument, send logs to /dev/null
		[[ ${F[_ARDOP_ARGS_]} =~ -l ]] || F[_ARDOP_ARGS_]+=" -l /dev/null/"
		# If PTT is specified as an argument, override PTT setting in GUI
		[[ ${F[_ARDOP_ARGS_]} =~ -p ]] && ARDOP_PTT=""
		echo "Starting $ARDOP ${F[_ARDOPPORT_]} ${F[_ADEVICE_CAPTURE_]} ${F[_ADEVICE_PLAY_]} ${F[_ARDOP_ARGS_]} $ARDOP_PTT" >&8
		$ARDOP ${F[_ARDOPPORT_]} ${F[_ADEVICE_CAPTURE_]} ${F[_ADEVICE_PLAY_]} ${F[_ARDOP_ARGS_]} $ARDOP_PTT >&8 2>&8 &
		ardop_PID=$!
		echo -e "\nARDOP has started.  PID=$ardop_PID" >&8

		# Start pat
		if [[ $PAT_START_HTTP == TRUE ]]
		then
			$PAT >&8 2>&8 &
			pat_PID=$!
		else
			pat_PID=""
		fi
	fi 

	ARG_INFO="ardopc arguments are usually not needed, but if you want to use them:\n \
-l path or --logdir path          Path for log files\n \
-c device or --cat device         Device to use for CAT Control\n \
-p device or --ptt device         Device to use for PTT control using RTS\n \
-k string or --keystring string   String (In HEX) to send to the radio to key PTT\n \
-u string or --unkeystring string String (In HEX) to send to the radio to unkeykey PTT\n \
-L use Left Channel of Soundcard in stereo mode\n \
-R use Right Channel of Soundcard in stereo mode\n\n \
"
	# Set up tab for configuring ardopc.
	yad --plug="$ID" --tabnum=2 \
  		--text="<b><big><big>ARDOP Configuration</big></big></b>\n\n \
<b><u><big>Typical Sound Card and PTT Settings for Nexus DR-X</big></u></b>\n \
<span color='blue'><b>LEFT Radio:</b></span> Use \
<b>fepi-capture-left</b> and <b>fepi-playback-left</b> and PTT <b>GPIO 12</b>.\n \
<span color='blue'><b>RIGHT Radio:</b></span> Use \
<b>fepi-capture-right</b> and <b>fepi-playback-right</b> and PTT <b>GPIO 23</b>.\n\n \
Click the <b>Save Settings...</b> button below after you make your changes.\n" \
  		--item-separator="!" \
		--separator="|" \
  		--text-align=center \
  		--align=right \
  		--borders=20 \
  		--form \
		--columns=1 \
  	  	--field="<b>Audio Capture Device</b>":CB "$ADEVICE_CAPTUREs" \
     	--field="<b>Audio Playback Device</b>":CB "$ADEVICE_PLAYBACKs" \
   	--field="<b>PTT</b>":CB "$PTTs" \
   	--field="<b>ARDOP Port</b>":NUM "${F[_ARDOPPORT_]}!8510..8519!1!" \
   	--field="<b>ardopc</b> command arguments\n(OPTIONAL - usually not needed)" "${F[_ARDOP_ARGS_]}" \
  		--focus-field 1 > $TMPDIR/CONFIGURE_ARDOP.txt &
	YAD_PIDs+=( $! )

#   	--field="<b>ardopc</b> argument information:":TXT "$ARG_INFO" \


	# Set up tab for pat configuration
	yad --plug="$ID" --tabnum=3 \
		--text="<b><big><big>pat Configuration</big></big></b>\n\n \
Click the <b>Save Settings...</b> button below after you make your changes.\n\n" \
		--item-separator="!" \
		--separator="|" \
  		--text-align=center \
  		--align=right \
  		--borders=20 \
  		--form \
		--columns=2 \
     	--field="Call Sign" "$PAT_CALL" \
		--field="Winlink Password":H "$PAT_PASSWORD" \
		--field="Locator Code" "$PAT_LOCATOR" \
   	--field="Web Service Port":NUM "$PAT_HTTP_PORT!8040..8049!1!" \
   	--field="Start pat web service when ARDOP starts":CHK "$PAT_START_HTTP" \
   	--field="Telnet Service Port":NUM "$PAT_TELNET_PORT!8770..8779!1!" \
   	--field="Forced ARQ Bandwidth":CHK "$PAT_ARQ_BW_FORCED" \
   	--field="Max ARQ Bandwidth (Hz)":CB "$PAT_ARQ_BW_MAXs" \
   	--field="Beacon Interval (seconds)\n0 = disabled":NUM "$PAT_BEACON_INTERVAL!0..3600!1!" \
   	--field="Enable CW ID":CHK "$PAT_CW_ID" \
		--field="<b>Edit pat Connection Aliases</b>":FBTN "bash -c edit_pat_aliases.sh &" \
  		--focus-field 1 > $TMPDIR/CONFIGURE_PAT.txt &
	YAD_PIDs+=( $! )
	[[ $PAT_START_HTTP == TRUE ]] && AND_PAT=" + pat" || AND_PAT=""

	# Set up tab with form button to launch pat web interface
	#yad --plug="$ID" --tabnum=4 --text-align="center" \
	#	--text="<big><b>Open pat Web Interface</b></big>" --form \
	#	--field="<b>Open pat Web Interface</b>":FBTN "bash -c xdg-open >/dev/null &" >/dev/null &
	#YAD_PIDs+=( $! )

	# Set up tab to present button to launch rigctld manager
	RIGCTL_INFO=" \
The rig control daemon (rigctld) is part of Hamlib. It provides a way to control \
various rigs using CAT commands, usually over a serial port.\n\nIn order to set up \
aliases (shortcuts) in the pat web interface for RMS Gateway stations ALONG WITH \
their frequency, pat requires the use of rigctld. When started, the GUI you're \
currently using will check to see if rigctld is already running. If it's not, it'll \
start rigctld using a 'dummy' rig, which fools pat into thinking it's controlling a \
radio when it's not (meaning you have to set your radio's frequency manually).\n\nIf \
your rig is supported by Hamlib (or to check to see if it is supported), click the \
'Manage Hamlib rigctld' button below to have the TNC and pat REALLY talk to your \
radio (if supported) and have pat automatically QSY as needed."
	yad --plug="$ID" --tabnum=4 --text-align=center --borders=20 --form --wrap \
		--text="<big><b>Hamlib Rig Control (rigctld)</b></big>" \
		--field="":TXT "$RIGCTL_INFO" \
		--field="<b>Manage Hamlib rigctld</b>":FBTN "bash -c rigctl_gui.sh >/dev/null &" >/dev/null &
	YAD_PIDs+=( $! )

	if [[ $pat_PID == "" ]]
	then
		cat > $TMPDIR/pat_web.sh <<EOF
yad --center --title="Error" --borders=20 --text "<b>pat is not running.\nNo web interface to open.</b>" --button="Close":0 --buttons-layout=center
EOF
	else
		cat > $TMPDIR/pat_web.sh <<EOF
xdg-open http://$HOSTNAME.local:$PAT_HTTP_PORT >/dev/null 2>&1
EOF
	fi
	chmod +x $TMPDIR/pat_web.sh
	
	# Set up a notebook with the tabs.		
	yad --title="ARDOP and pat $VERSION" --text="<b><big>ARDOP$AND_PAT Configuration and Operation</big></b>" \
  		--text-align="center" --notebook --key="$ID" \
		--posx=10 --posy=50 \
  		--buttons-layout=center \
  		--tab="Monitor" \
  		--tab="Configure ARDOP" \
  		--tab="Configure pat" \
  		--tab="Rig Control" \
		--width="800" --height="600" \
  		--button="<b>Stop ARDOP$AND_PAT &#x26; Exit</b>":1 \
  		--button="<b>Save Settings &#x26; Restart ARDOP$AND_PAT</b>":0 \
  		--button="<b>Open pat Web interface</b>":"bash -c $TMPDIR/pat_web.sh"
	RETURN_CODE=$?

	case $RETURN_CODE in
		0) # Read and handle the Configure TNC tab yad output
			[[ -s $TMPDIR/CONFIGURE_ARDOP.txt ]] || Die "Unexpected input from dialog"
			IFS='|' read -r -a TF < "$TMPDIR/CONFIGURE_ARDOP.txt"
			F[_ADEVICE_CAPTURE_]="${TF[0]}"
			F[_ADEVICE_PLAY_]="${TF[1]}"
			F[_PTT_]="${TF[2]}"
			F[_ARDOPPORT_]="${TF[3]}"
			F[_ARDOP_ARGS_]="${TF[4]}"
			

			# Read and handle the Configure pat tab yad output
			[[ -s $TMPDIR/CONFIGURE_PAT.txt ]] || Die "Unexpected input from dialog"
			IFS='|' read -r -a TF < "$TMPDIR/CONFIGURE_PAT.txt"
			PAT_CALL="${TF[0]^^}"
			PAT_PASSWORD="${TF[1]}"
			PAT_LOCATOR="${TF[2]^^}"
			PAT_HTTP_PORT="${TF[3]}"
			F[_PAT_HTTP_]="${TF[4]}"
			PAT_TELNET_PORT="${TF[5]}"
			PAT_ARQ_BW_FORCED="${TF[6]}"
			PAT_ARQ_BW_MAX="${TF[7]}"
			PAT_BEACON_INTERVAL="${TF[8]}"
			PAT_CW_ID="${TF[9]}"
			
			# Update the pat config.json file with the new data.
			cat $PAT_CONFIG | jq \
				--arg C "$PAT_CALL" \
				--arg P "$PAT_PASSWORD" \
				--arg H "0.0.0.0:$PAT_HTTP_PORT" \
				--arg T "0.0.0.0:$PAT_TELNET_PORT" \
				--arg L "$PAT_LOCATOR" \
				--arg R "127.0.0.1:${F[_ARDOPPORT_]}" \
				--argjson F ${PAT_ARQ_BW_FORCED,,} \
				--argjson B $PAT_ARQ_BW_MAX \
				--argjson I $PAT_BEACON_INTERVAL \
				--argjson D ${PAT_CW_ID,,} \
					'.mycall = $C | .secure_login_password = $P | .http_addr = $H | .telnet.listen_addr = $T | .locator = $L | .ardop.addr =  $R | .ardop.arq_bandwidth.Max = $B | .ardop.beacon_interval = $I | .ardop.arq_bandwidth.Forced = $F | .ardop.cwid_enabled = $D' | sponge $PAT_CONFIG

			# Did ARDOP config request rigctl for PTT? If so let pat handle it via rigctl
			[[ ${F[_PTT_]} =~ GPIO ]] && PAT_PTT=false || PAT_PTT=true
			cat $PAT_CONFIG | jq --argjson P $PAT_PTT '.ardop.ptt_ctrl = $P' | sponge $PAT_CONFIG  

			# Update the yad configuration file.
			echo "declare -gA F" > "$CONFIG_FILE"
			for J in "${!F[@]}"
			do
   			echo "F[$J]='${F[$J]}'" >> "$CONFIG_FILE"
			done
			if [[ $(jq -r ".mycall" $PAT_CONFIG) == "" ||  ${F[_ADEVICE_CAPTURE_]} == "null" ]]
			then
				FIRST_RUN=true
			else
				FIRST_RUN=false
			fi
			;;
		*) # User click Exit button or closed window. 
			break
			;;
	esac
done
SafeExit
