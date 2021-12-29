#!/usr/bin/env sh
# Runs BEFORE installing package
sudo apt -y remove --purge libhamlib4 libhamlib-utils
apt-mark hold libhamlib4 libhamlib-utils
rm -f /usr/lib/libhamlib*
exit 0
