#!/bin/sh

SERVICE_NAME=monitoring
SCRIPT_DIR=$(pwd)
RUNNER="$SCRIPT_DIR/$SERVICE_NAME.sh"
PRE_START_SCRIPT="$SCRIPT_DIR/pre-start.sh"
STOP_SCRIPT="$SCRIPT_DIR/stop.sh"
NOTIFY_SCRIPT="$SCRIPT_DIR/notify.sh"

chmod +x $RUNNER $PRE_START_SCRIPT $STOP_SCRIPT $NOTIFY_SCRIPT

tee<<EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=$SERVICE_NAME
After=network.target

[Service]
Type=simple
ExecStartPre=/bin/sh $PRE_START_SCRIPT
ExecStart=/bin/sh $RUNNER "$SCRIPT_DIR/.env"
ExecStopPost=/bin/sh $STOP_SCRIPT
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/$SERVICE_NAME.service

systemctl daemon-reload
systemctl enable $SERVICE_NAME.service
systemctl restart $SERVICE_NAME.service
