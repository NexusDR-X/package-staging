#!/usr/bin/env sh
# Runs AFTER installing package

# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/local/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/fldigi*.desktop
   do
      [ -e "$F" ] || continue
      sed -i 's/Network;//g' $F

   done
done

# Disable the regular flgidi.desktop file because Nexus has separate desktop files
# for left and right radios
[ -f /usr/local/share/applications/fldigi.desktop ] && sudo mv -f /usr/local/share/applications/fldigi.desktop /usr/local/share/applications/fldigi.desktop.disabled
[ -f /usr/local/share/applications/flarq.desktop ] && sudo mv -f /usr/local/share/applications/flarq.desktop /usr/local/share/applications/flarq.desktop.disabled
exit 0
