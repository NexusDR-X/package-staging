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
if [ ! -s /usr/share/applications/flamp-left.desktop ]
then
   sed -e "s/_LEFT_RADIO_/Left Radio/g" \
   /usr/share/applications/flamp-left.template >/usr/share/applications/flamp-left.desktop
fi
if [ ! -s /usr/share/applications/flamp-right.desktop ]
then
   sed -e "s/_RIGHT_RADIO_/Right Radio/g" \
   /usr/share/applications/flamp-right.template >/usr/share/applications/flamp-right.desktop
fi
exit 0
