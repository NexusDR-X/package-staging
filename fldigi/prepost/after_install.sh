#!/usr/bin/env sh
# Runs AFTER installing package

# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/share/applications"
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
[ -f /usr/share/applications/fldigi.desktop ] && sudo mv -f /usr/share/applications/fldigi.desktop /usr/share/applications/fldigi.desktop.disabled
[ -f /usr/share/applications/flarq.desktop ] && sudo mv -f /usr/share/applications/flarq.desktop /usr/share/applications/flarq.desktop.disabled
if [ ! -s /usr/share/applications/fldigi-left.desktop ]
then
   sed -e "s/_LEFT_RADIO_/Left Radio/g" \
   /usr/share/applications/fldigi-left.template >/usr/share/applications/fldigi-left.desktop
fi
if [ ! -s /usr/share/applications/fldigi-right.desktop ]
then
   sed -e "s/_RIGHT_RADIO_/Right Radio/g" \
   /usr/share/applications/fldigi-right.template >/usr/share/applications/fldigi-right.desktop
fi
exit 0
