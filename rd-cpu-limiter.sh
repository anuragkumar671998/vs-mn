  GNU nano 7.2                                                                                       rd-cpu-limiter.sh                                                                                                 
#!/bin/bash
set -e

SERVICE_FILE="/etc/systemd/system/random-cpu-limiter.service"

sudo tee "$SERVICE_FILE" >/dev/null <<'EOF'
[Unit]
Description=Random CPU Limiter Service
Description=Applies random CPU limits (73-91%) for random durations (29-49min)
After=network.target
After=multi-user.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/random-cpu-limiter.sh
Restart=always
RestartSec=10
StandardOutput=append:/var/log/random-cpu-limiter-service.log
StandardError=append:/var/log/random-cpu-limiter-service.error.log
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=30
Nice=19
CPUSchedulingPolicy=batch

[Install]
WantedBy=multi-user.target
Alias=random-cpu-limiter.service
EOF

sudo systemctl daemon-reload
sudo systemctl enable random-cpu-limiter.service
sudo systemctl start random-cpu-limiter.service
