#!/usr/bin/env bash
# Restart the DMS shell (bar, launcher, notifications, lock, idle).
# The service is started by home-manager via UWSM's graphical-session.target.
systemctl --user restart dms.service
