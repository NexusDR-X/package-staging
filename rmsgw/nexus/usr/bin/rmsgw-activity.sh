#!/bin/bash

# Extracts Login/Logout events in RMS Gateway occuring in the past 24 hours
# and emails results
# Suggested cron config to run this script:
# 1 0 * * *   /home/pi/rmsgw-activity.sh 2>&1 >/dev/null

# Separate MAILTO addresses with spaces.

VERSION="1.1.8"

declare -i AGE=24 # Age in hours
FILES="/var/log/rms* /var/log/syslog*"
MAILTO="${1:-w7ecg.wecg@gmail.com}"
#PAT_DIR="${2:-$HOME/.wl2k}"
PAT_DIR="${2:-$HOME/.config/pat}"
# Mail RMS gateway login activity for last 24 hours.
FILTERED="$(mktemp)"
OUTFILE="$(mktemp)"
$(command -v bzgrep) -h " rmsgw.*Login \| rmsgw.*Logout " $FILES 2>/dev/null 1>$FILTERED
NOW="$(date +'%s')"
if [ -s $FILTERED ]
then
   while IFS= read -r LINE
   do
      D="${LINE%% $HOSTNAME*}" # Extract date from log message
      E="$(date --date="$D" +'%s')" # Convert date to epoch
      if [ $E -gt $NOW ]
      then # Now in new year.  (Log messages don't include year, so it's a problem going from December to January.)
         # Account for leap years
         date -d $(date +%Y)-02-29 >/dev/null 2>&1 && SEC_IN_YEAR=$((60 * 60 * 24 * 366)) || SEC_IN_YEAR=$((60 * 60 * 24 * 365))
         # Make it December again ;)
         E=$(( $E - $SEC_IN_YEAR ))
      fi
      let DIFF=$NOW-$E
      if [ $DIFF -le $(($AGE * 3600)) ] # Print events <= 24 hours old
      then
         echo "$LINE" | tr -s ' ' | cut -d' ' -f1,2,3,6- >> $OUTFILE
      fi
   done < $FILTERED
fi
[ -s $OUTFILE ] || echo "No RMS Gateway activity." > $OUTFILE
#{
#   echo To: $MAILTO
#   echo From: $MAILFROM
#   echo Subject: $HOSTNAME RMS Gateway activity for 24 hours preceding `date`
#   echo 
#   cat $OUTFILE | sort | uniq
#} | /usr/sbin/ssmtp $MAILTO
#cat $OUTFILE | sort | uniq | $(command -v patmail.sh) -d $PAT_DIR $MAILTO "$HOSTNAME RMS Gateway activity for 24 hours preceding `date`" telnet
cat $OUTFILE | sort | uniq | $(command -v pat) --config $PAT_DIR/config.json --event-log /dev/null compose --subject "$HOSTNAME RMSGW activity 24 hours preceding `date`" $(echo $MAILTO | xargs -d,) &>/dev/null
$(command -v pat) --config $PAT_DIR/config.json --event-log /dev/null --send-only connect telnet &>/dev/null
rm $OUTFILE
rm $FILTERED

