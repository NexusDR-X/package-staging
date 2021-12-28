#!/usr/bin/env sh
# # Runs AFTER installing package
# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flamp.desktop
   do
      [ -e "$F" ] || continue
      sudo sed -i 's/Network;//g' $F 
   done
done
[ -f /usr/share/applications/flamp.desktop ] && sudo mv -f /usr/share/applications/flamp.desktop /usr/share/applications/flamp.desktop.disabled
for SIDE in left right
do
   if [ ! -f /usr/share/applications/flamp-${SIDE}.desktop ]
   then
      sed -e "s/_${SIDE^^}_RADIO_/${SIDE^} Radio/g" \
      /usr/share/applications/flamp-${SIDE}.template | \
      sudo tee /usr/share/applications/flamp-${SIDE}.desktop >/dev/null
   fi
done
exit 0
