#!/usr/bin/env sh
# Runs AFTER installing package
# Fix the *.desktop files
FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flcluster.desktop
   do
      [ -e "$F" ] || continue
      sudo sed -i 's/Network;//g' $F 
   done
done
[ -f /usr/local/share/applications/flcluster.desktop.disabled ] && sudo mv -f /usr/local/share/applications/flcluster.desktop.disabled /usr/local/share/applications/flcluster.desktop
exit 0
