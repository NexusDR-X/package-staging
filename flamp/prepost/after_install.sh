#!/usr/bin/env sh
# # Runs AFTER installing package
# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/local/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flamp.desktop
   do
      [ -e "$F" ] || continue
      sudo sed -i 's/Network;//g' $F 
   done
done
[ -f /usr/local/share/applications/flamp.desktop ] && sudo mv -f /usr/local/share/applications/flamp.desktop /usr/local/share/applications/flamp.desktop.disabled
exit 0
