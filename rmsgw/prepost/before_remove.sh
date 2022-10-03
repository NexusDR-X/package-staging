#!/usr/bin/env sh
# Runs BEFORE removing package
systemctl stop ax25.service
systemctl disable ax25.service
systemctl daemon-reload
exit 0
