#!/usr/bin/env sh
# Runs AFTER installing package
# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
#for D in ${FLDIGI_DESKTOPS}
#   do
#      for F in ${D}/fl*.desktop
#      do

#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flrig*.desktop
   do
      [ -e "$F" ] || continue
      sudo sed -i 's/Network;//g' $F
      if [ $F = "${D}/flrig.desktop" ]
      then
         grep -q "\-\-debug-level 0" $F 2>/dev/null || sudo sed -i 's/Exec=flrig/Exec=flrig --debug-level 0/' $F
      fi
   done
done
[ -f /usr/share/applications/flrig.desktop ] && sudo mv -f /usr/share/applications/flrig.desktop /usr/share/applications/flrig.desktop.disabled
if [ ! -s /usr/share/applications/flrig-left.desktop ]
then
   sed -e "s/_LEFT_RADIO_/Left Radio/g" \
   /usr/share/applications/flrig-left.template >/usr/share/applications/flrig-left.desktop
fi
if [ ! -s /usr/share/applications/flrig-right.desktop ]
then
   sed -e "s/_RIGHT_RADIO_/Right Radio/g" \
   /usr/share/applications/flrig-right.template >/usr/share/applications/flrig-right.desktop
fi
exit 0
