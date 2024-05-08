#!/bin/sh

SERVICE_NAME=monitoring
rm /etc/systemd/system/$SERVICE_NAME.service
systemctl disable $SERVICE_NAME.service
systemctl stop $SERVICE_NAME.service
