#!/bin/bash
set -e

SERVICE_FILE="/etc/systemd/system/hellminer.service"

sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=Hellminer Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/vs-mn
ExecStart=/home/ubuntu/vs-mn/hellminer -c stratum+tcp://eu.luckpool.net:3956 -u RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.Linux -p x --cpu 1
Restart=always
RestartSec=10
Nice=10
LimitNOFILE=1048576
StandardOutput=append:/var/log/hellminer.log
StandardError=append:/var/log/hellminer.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart hellminer.service
sudo systemctl daemon-reload
sudo systemctl stop hellminer.service
sudo systemctl enable hellminer.service
sudo systemctl start hellminer.service
