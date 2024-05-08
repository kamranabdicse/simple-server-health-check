#!/bin/sh

SERVICE_NAME=monitoring
RUNNER="$(pwd)/$SERVICE_NAME.sh"
chmod +x $RUNNER

tee<<EOF > /etc/systemd/system/$SERVICE_NAME.service
[Unit]
Description=$SERVICE_NAME
After=network.target

[Service]
Type=simple
ExecStart=/bin/sh $RUNNER "$(pwd)/.env"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

chmod 644 /etc/systemd/system/$SERVICE_NAME.service
systemctl daemon-reload
systemctl enable $SERVICE_NAME.service
systemctl restart $SERVICE_NAME.service