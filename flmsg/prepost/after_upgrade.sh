#!/usr/bin/env sh
# Runs AFTER installing package
# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flmsg*.desktop
   do
      [ -e "$F" ] || continue
      sudo sed -i 's/Network;//g' $F
   done
done
[ -f /usr/share/applications/flmsg.desktop ] && sudo mv -f /usr/share/applications/flmsg.desktop /usr/share/applications/flmsg.desktop.disabled
exit 0
