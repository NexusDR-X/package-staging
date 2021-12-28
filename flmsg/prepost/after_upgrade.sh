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
if [ ! -s /usr/share/applications/flmsg-left.desktop ]
then
   sed -e "s/_LEFT_RADIO_/Left Radio/g" \
   /usr/share/applications/flmsg-left.template >/usr/share/applications/flmsg-left.desktop
fi
if [ ! -s /usr/share/applications/flmsg-right.desktop ]
then
   sed -e "s/_RIGHT_RADIO_/Right Radio/g" \
   /usr/share/applications/flmsg-right.template >/usr/share/applications/flmsg-right.desktop
fi
exit 0
