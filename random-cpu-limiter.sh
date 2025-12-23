#!/bin/bash
# Installer for Random CPU Limiter Service
# Save as: install-random-cpu-limiter.sh

set -e

echo "=========================================="
echo "Random CPU Limiter Service Installer"
echo "=========================================="

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    echo "ERROR: Please run as root"
    echo "Use: sudo bash $0"
    exit 1
fi

# Configuration
SCRIPT_PATH="/usr/local/bin/random-cpu-limiter.sh"
SERVICE_PATH="/etc/systemd/system/random-cpu-limiter.service"
LOG_DIR="/var/log"

echo "Installing Random CPU Limiter..."

# 1. Create the main script
echo "Creating main script at $SCRIPT_PATH..."
cat > $SCRIPT_PATH << 'EOF'
#!/bin/bash

# Random CPU Limiter: 73-91% for 29-49 minutes
# Service version

LOG_FILE="/var/log/random-cpu-limiter.log"
MAX_LOG_SIZE=10485760  # 10MB

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
    
    # Rotate log if too large
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]; then
        mv "$LOG_FILE" "${LOG_FILE}.1" 2>/dev/null
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated" > "$LOG_FILE"
    fi
}

# Initialize log
init_log() {
    mkdir -p /var/log/
    touch "$LOG_FILE"
    chmod 644 "$LOG_FILE"
    log "=========================================="
    log "Random CPU Limiter Service Started - PID: $$"
    log "Random Range: 73-91% CPU for 29-49 minutes"
    log "System: $(uname -a)"
    log "=========================================="
}

# Install cpulimit
install_cpulimit() {
    if ! command -v cpulimit &> /dev/null; then
        log "Installing cpulimit..."
        apt-get update >/dev/null 2>&1
        apt-get install -y cpulimit >/dev/null 2>&1
        
        if ! command -v cpulimit &> /dev/null; then
            log "Compiling cpulimit from source..."
            apt-get install -y git build-essential >/dev/null 2>&1
            rm -rf /tmp/cpulimit_src
            git clone https://github.com/opsengine/cpulimit.git /tmp/cpulimit_src 2>/dev/null
            if [ -d "/tmp/cpulimit_src" ]; then
                cd /tmp/cpulimit_src
                make >/dev/null 2>&1
                cp src/cpulimit /usr/local/bin/ 2>/dev/null
                cd /
                rm -rf /tmp/cpulimit_src
            fi
        fi
        
        if command -v cpulimit &> /dev/null; then
            log "cpulimit installed: $(cpulimit --version 2>/dev/null || echo 'version unknown')"
        else
            log "ERROR: cpulimit installation failed"
            return 1
        fi
    fi
    return 0
}

# Get random percentage 73-91
get_random_percentage() {
    echo $((73 + RANDOM % 19))
}

# Get random minutes 29-49
get_random_minutes() {
    echo $((29 + RANDOM % 21))
}

# Get current CPU usage
get_cpu_usage() {
    local cpu_usage
    if command -v mpstat &> /dev/null; then
        cpu_usage=$(mpstat 1 1 | awk '/Average:/ {print 100 - $NF}' | cut -d. -f1)
    else
        cpu_usage=$(top -bn2 | grep "Cpu(s)" | tail -1 | awk '{print $2 + $4}' | cut -d. -f1)
    fi
    echo "${cpu_usage:-0}"
}

# Get all user process PIDs safely
get_user_pids() {
    local pids=""
    for pid in /proc/[0-9]*/; do
        pid=$(basename "$pid" 2>/dev/null)
        if [[ "$pid" =~ ^[0-9]+$ ]] && [ "$pid" -gt 10 ]; then
            if [ "$pid" -ne $$ ] && [ "$pid" -ne 1 ] && [ "$pid" -ne 2 ]; then
                if [ -f "/proc/$pid/stat" ]; then
                    ppid=$(awk '{print $4}' /proc/$pid/stat 2>/dev/null)
                    if [ "$ppid" -gt 2 ]; then
                        pids="$pids $pid"
                    fi
                fi
            fi
        fi
    done
    echo "$pids"
}

# Limit all user processes
limit_all_processes() {
    local percentage=$1
    local count=0
    
    log "Applying ${percentage}% CPU limit..."
    
    # Clean up existing cpulimit processes
    pkill -f "cpulimit.*-l" 2>/dev/null
    sleep 1
    
    # Get user PIDs
    local pids=$(get_user_pids)
    
    # Limit each PID
    for pid in $pids; do
        if [ -d "/proc/$pid" ]; then
            local proc_name=$(cat /proc/$pid/comm 2>/dev/null || echo "unknown")
            
            # Skip system processes
            case "$proc_name" in
                systemd|init|kthreadd|*rcu*|migration|watchdog|cpulimit|kworker*|ksoftirqd*|irq/*)
                    continue
                    ;;
            esac
            
            # Apply cpulimit
            cpulimit -p $pid -l $percentage -q -z >/dev/null 2>&1 &
            count=$((count + 1))
        fi
    done
    
    # Also limit by executable name for common processes
    local common_execs="bash python3 java node npm docker containerd php apache2 nginx mysql postgres"
    
    for exec_name in $common_execs; do
        if pgrep -x "$exec_name" >/dev/null; then
            cpulimit -e "$exec_name" -l $percentage -q -z >/dev/null 2>&1 &
            count=$((count + 1))
        fi
    done
    
    sleep 2
    
    # Check how many cpulimit processes are running
    local cpulimit_count=$(ps aux | grep -c "[c]pulimit.*-l $percentage")
    
    log "Applied limit to ~$count processes"
    log "Active cpulimit processes: $cpulimit_count"
    
    if [ $cpulimit_count -eq 0 ]; then
        log "WARNING: No cpulimit processes started!"
        return 1
    fi
    
    return 0
}

# Remove all limits
remove_limits() {
    log "Removing CPU limits..."
    pkill -9 -f "cpulimit" 2>/dev/null
    killall -9 cpulimit 2>/dev/null
    sleep 2
    log "CPU limits removed"
}

# Main function
main() {
    init_log
    
    # Install dependencies
    if ! install_cpulimit; then
        log "FATAL: Cannot install cpulimit"
        exit 1
    fi
    
    local cycle=0
    
    while true; do
        cycle=$((cycle + 1))
        
        # Get random values
        local percentage=$(get_random_percentage)
        local minutes=$(get_random_minutes)
        local break_minutes=$((1 + RANDOM % 3))
        
        log "════════════════════════════════════════════════════════════════════════════════"
        log "CYCLE #${cycle}: LIMIT ${percentage}% CPU for ${minutes} minutes"
        log "════════════════════════════════════════════════════════════════════════════════"
        
        # Apply limit
        if limit_all_processes $percentage; then
            # Wait for duration
            log "Maintaining ${percentage}% CPU limit for ${minutes} minutes..."
            
            local minutes_passed=0
            while [ $minutes_passed -lt $minutes ]; do
                local remaining=$((minutes - minutes_passed))
                if [ $remaining -le 5 ]; then
                    sleep ${remaining}m
                    minutes_passed=$minutes
                else
                    sleep 5m
                    minutes_passed=$((minutes_passed + 5))
                fi
            done
        else
            log "ERROR: Failed to apply limit"
        fi
        
        # Remove limits
        remove_limits
        
        # Break period
        if [ $break_minutes -gt 0 ]; then
            log "BREAK PERIOD: ${break_minutes} minutes of normal CPU..."
            sleep ${break_minutes}m
        fi
    done
}

# Cleanup
cleanup() {
    echo ""
    log "════════════════════════════════════════════════════════════════════════════════"
    log "SHUTDOWN SIGNAL RECEIVED - Cleaning up..."
    log "════════════════════════════════════════════════════════════════════════════════"
    remove_limits
    log "Cleanup complete. Goodbye!"
    exit 0
}

# Trap signals
trap cleanup INT TERM EXIT

# Run main
main
EOF

# Make script executable
chmod +x $SCRIPT_PATH
echo "✓ Script created and made executable"

# 2. Create systemd service file
echo "Creating systemd service at $SERVICE_PATH..."
cat > $SERVICE_PATH << 'EOF'
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

# Limit CPU usage of the service itself to prevent interference
CPUQuota=5%

[Install]
WantedBy=multi-user.target
Alias=random-cpu-limiter.service
EOF

echo "✓ Service file created"

# 3. Reload systemd daemon
echo "Reloading systemd daemon..."
systemctl daemon-reload
echo "✓ Systemd daemon reloaded"

# 4. Enable service to start on boot
echo "Enabling service to start on boot..."
systemctl enable random-cpu-limiter.service
echo "✓ Service enabled"

# 5. Start the service
echo "Starting the service..."
systemctl start random-cpu-limiter.service
echo "✓ Service started"

# 6. Show service status
echo ""
echo "=========================================="
echo "Installation Complete!"
echo "=========================================="
echo ""
echo "Service Information:"
echo "-------------------"
echo "Service Name: random-cpu-limiter"
echo "Main Script: $SCRIPT_PATH"
echo "Service File: $SERVICE_PATH"
echo "Main Log: /var/log/random-cpu-limiter.log"
echo "Service Log: /var/log/random-cpu-limiter-service.log"
echo "Error Log: /var/log/random-cpu-limiter-service.error.log"
echo ""
echo "Useful Commands:"
echo "----------------"
echo "Check status:    sudo systemctl status random-cpu-limiter"
echo "Start service:   sudo systemctl start random-cpu-limiter"
echo "Stop service:    sudo systemctl stop random-cpu-limiter"
echo "Restart service: sudo systemctl restart random-cpu-limiter"
echo "View logs:       sudo journalctl -u random-cpu-limiter -f"
echo "View main log:   tail -f /var/log/random-cpu-limiter.log"
echo ""
echo "The service will automatically:"
echo "- Apply random CPU limits between 73-91%"
echo "- For random durations between 29-49 minutes"
echo "- Take 1-3 minute breaks between cycles"
echo "- Restart automatically if it crashes"
echo ""

# Wait a moment and show status
sleep 3
echo "Current Service Status:"
echo "-----------------------"
systemctl status random-cpu-limiter --no-pager -l
