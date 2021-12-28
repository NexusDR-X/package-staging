#!/usr/bin/env sh
# Runs AFTER installing package
# Fix the *.desktop files
#FLDIGI_DESKTOPS="/usr/local/share/applications $HOME/.local/share/applications"
FLDIGI_DESKTOPS="/usr/share/applications"
for D in ${FLDIGI_DESKTOPS}
do
   for F in ${D}/flwrap*.desktop
   do
      [ -e "$F" ] || continue
      sed -i 's/Network;//g' $F
   done
done

[ -f /usr/share/applications/flwrap.desktop.disabled ] && sudo mv -f /usr/share/applications/flwrap.desktop.disabled /usr/share/applications/flwrap.desktop
exit 0
