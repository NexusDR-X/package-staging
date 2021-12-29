#!/usr/bin/env sh
# Runs BEFORE installing package
echo "Remove libhamlib4 libhamlib-utils if installed"
apt -y remove --purge libhamlib4 libhamlib-utils 2>/dev/null
echo "Mark libhamlib4 libhamlib-utils as held"
apt-mark hold libhamlib4 libhamlib-utils
#echo "Remove /usr/lib/hamlib*"
#rm -f /usr/lib/libhamlib*
echo "Done"
exit 0
