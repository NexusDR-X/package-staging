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
for SIDE in left right
do
   if [ ! -f /usr/share/applications/flrig-${SIDE}.desktop ]
   then
      sed -e "s/_${SIDE^^}_RADIO_/${SIDE^} Radio/g" \
      /usr/share/applications/flrig-${SIDE}.template | \
      sudo tee /usr/share/applications/flrig-${SIDE}.desktop >/dev/null
   fi
done
exit 0
