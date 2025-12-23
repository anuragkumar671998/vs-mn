#!/bin/bash
# =================================================================
# Complete Random CPU Limiter Installation Script
# Includes: Main Script + Systemd Service + 60s Delay Timer
# =================================================================

# Configuration
SCRIPT_NAME="random-cpu-limiter.sh"
SERVICE_NAME="random-cpu-limiter.service"
TIMER_NAME="random-cpu-limiter.timer"
INSTALL_PATH="/usr/local/bin"
SERVICE_PATH="/etc/systemd/system"
LOG_DIR="/var/log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Functions
print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        print_error "This script must be run as root"
        echo "Please run: sudo bash $0"
        exit 1
    fi
}

# Create the main CPU limiter script
create_main_script() {
    local script_path="$INSTALL_PATH/$SCRIPT_NAME"
    
    print_header "Creating Main CPU Limiter Script"
    
    cat > "$script_path" << 'EOF'
#!/bin/bash
# Random CPU Limiter: 73-91% for 29-49 minutes
# Systemd Service Version with 60-second boot delay

LOG_FILE="/var/log/random-cpu-limiter.log"
MAX_LOG_SIZE=10485760  # 10MB
STARTUP_DELAY=60       # 60-second delay handled by systemd timer

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
    log "Service started with 60-second boot delay"
    log "Random Range: 73-91% CPU for 29-49 minutes"
    log "Hostname: $(hostname)"
    log "Date: $(date)"
    log "=========================================="
}

# Install cpulimit if not present
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
    echo $((73 + RANDOM % 19))  # 73 to 91 inclusive
}

# Get random minutes 29-49
get_random_minutes() {
    echo $((29 + RANDOM % 21))  # 29 to 49 inclusive
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
    
    # Get current CPU usage before limiting
    local cpu_before=$(get_cpu_usage)
    
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
            
            # Log first few for debugging
            if [ $count -le 3 ]; then
                log "  Limited PID $pid ($proc_name) to ${percentage}%"
            fi
        fi
    done
    
    # Also limit by executable name for common processes
    local common_execs="bash python3 java node npm docker containerd php apache2 nginx mysql postgres"
    
    for exec_name in $common_execs; do
        if pgrep -x "$exec_name" >/dev/null; then
            cpulimit -e "$exec_name" -l $percentage -q -z >/dev/null 2>&1 &
            count=$((count + 1))
            log "  Limited all '$exec_name' processes to ${percentage}%"
        fi
    done
    
    # Wait a moment for cpulimit to start
    sleep 2
    
    # Check how many cpulimit processes are running
    local cpulimit_count=$(ps aux | grep -c "[c]pulimit.*-l $percentage")
    
    # Get CPU usage after limiting
    local cpu_after=$(get_cpu_usage)
    
    log "Applied limit to ~$count processes"
    log "Active cpulimit processes: $cpulimit_count"
    log "CPU before: ${cpu_before}%, CPU after: ${cpu_after}%"
    
    if [ $cpulimit_count -eq 0 ]; then
        log "WARNING: No cpulimit processes started!"
        return 1
    fi
    
    return 0
}

# Monitor CPU usage during limit period
monitor_cpu_usage() {
    local target_limit=$1
    local duration_seconds=$(( $2 * 60 ))
    local interval=30
    local samples=$(( duration_seconds / interval ))
    local total=0
    local max=0
    
    log "Monitoring CPU usage for $2 minutes (target: ${target_limit}%)"
    
    for ((i=1; i<=samples; i++)); do
        sleep $interval
        
        local current=$(get_cpu_usage)
        total=$((total + current))
        
        if [ $current -gt $max ]; then
            max=$current
        fi
        
        # Log every 10th sample or every 5 minutes
        if [ $((i % 10)) -eq 0 ]; then
            local minutes_passed=$((i * interval / 60))
            log "  ${minutes_passed}/${2} minutes: ${current}% CPU"
        fi
    done
    
    local average=$((total / samples))
    log "CPU Usage Report - Avg: ${average}%, Max: ${max}%, Target: ${target_limit}%"
    
    # Check if limit was effective
    if [ $average -gt $((target_limit + 15)) ]; then
        log "WARNING: CPU usage significantly above target limit!"
        return 1
    fi
    
    return 0
}

# Remove all limits
remove_limits() {
    log "Removing CPU limits..."
    
    # Kill all cpulimit processes
    pkill -9 -f "cpulimit" 2>/dev/null
    killall -9 cpulimit 2>/dev/null
    
    sleep 2
    
    # Verify cleanup
    local remaining=$(ps aux | grep -c "[c]pulimit")
    if [ $remaining -gt 0 ]; then
        log "  WARNING: $remaining cpulimit processes remain, forcing kill..."
        pkill -9 cpulimit 2>/dev/null
    fi
    
    log "CPU limits removed"
}

# Main function
main() {
    # Initialize
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
        local break_minutes=$((1 + RANDOM % 3))  # Shorter break: 1-3 minutes
        
        log "════════════════════════════════════════════════════════════════════════════════"
        log "CYCLE #${cycle}: LIMIT ${percentage}% CPU for ${minutes} minutes"
        log "════════════════════════════════════════════════════════════════════════════════"
        log "Random Settings: CPU Limit=${percentage}%, Duration=${minutes}min, Break=${break_minutes}min"
        
        # Apply limit
        if limit_all_processes $percentage; then
            # Monitor in background
            monitor_cpu_usage $percentage $minutes &
            MONITOR_PID=$!
            
            # Wait for duration with progress updates
            log "Maintaining ${percentage}% CPU limit for ${minutes} minutes..."
            
            # Progress updates every 5 minutes
            local minutes_passed=0
            while [ $minutes_passed -lt $minutes ]; do
                local remaining=$((minutes - minutes_passed))
                if [ $remaining -le 5 ]; then
                    sleep ${remaining}m
                    minutes_passed=$minutes
                else
                    sleep 5m
                    minutes_passed=$((minutes_passed + 5))
                    remaining=$((minutes - minutes_passed))
                    log "  Progress: ${minutes_passed}/${minutes} minutes (${remaining} minutes remaining)"
                fi
            done
            
            # Stop monitor
            kill $MONITOR_PID 2>/dev/null
        else
            log "ERROR: Failed to apply limit, skipping to break period"
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

# Cleanup handler
cleanup() {
    echo ""
    log "════════════════════════════════════════════════════════════════════════════════"
    log "SHUTDOWN SIGNAL RECEIVED - Cleaning up..."
    log "════════════════════════════════════════════════════════════════════════════════"
    
    remove_limits
    
    log "Cleanup complete. Goodbye!"
    exit 0
}

# Set up signal traps
trap cleanup INT TERM EXIT

# Start main function
main
EOF
    
    chmod +x "$script_path"
    print_status "Main script created: $script_path"
}

# Create systemd service file
create_service_file() {
    local service_path="$SERVICE_PATH/$SERVICE_NAME"
    
    print_header "Creating Systemd Service File"
    
    cat > "$service_path" << EOF
[Unit]
Description=Random CPU Limiter Service
Description=Applies random CPU limits (73-91%) for random durations (29-49min)
After=network.target
After=multi-user.target
After=$TIMER_NAME
Wants=$TIMER_NAME
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
Group=root
ExecStart=$INSTALL_PATH/$SCRIPT_NAME
Restart=always
RestartSec=10
StandardOutput=append:$LOG_DIR/random-cpu-limiter-service.log
StandardError=append:$LOG_DIR/random-cpu-limiter-service.error.log
KillMode=process
KillSignal=SIGTERM
TimeoutStopSec=30
Nice=19
CPUSchedulingPolicy=batch

# Limit CPU usage of the service itself to prevent interference
CPUQuota=5%

# Protect the service
ProtectSystem=strict
ReadWritePaths=$LOG_DIR
PrivateTmp=yes
NoNewPrivileges=yes

[Install]
# Do NOT set WantedBy - timer will handle startup
EOF
    
    print_status "Service file created: $service_path"
}

# Create systemd timer file (for 60-second delay)
create_timer_file() {
    local timer_path="$SERVICE_PATH/$TIMER_NAME"
    
    print_header "Creating Systemd Timer File (60-second delay)"
    
    cat > "$timer_path" << EOF
[Unit]
Description=Timer to delay CPU Limiter Service start by 60 seconds
Description=Starts CPU limiter 60 seconds after system boot
Requires=$SERVICE_NAME

[Timer]
# Start 60 seconds after boot
OnBootSec=60s
# If service fails, don't retry immediately
OnUnitActiveSec=0
Unit=$SERVICE_NAME

# Accuracy settings
AccuracySec=1s
RandomizedDelaySec=5s

[Install]
WantedBy=timers.target
EOF
    
    print_status "Timer file created: $timer_path"
    print_status "Service will start 60 seconds after boot"
}

# Install dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Check if apt is available
    if command -v apt-get &> /dev/null; then
        print_status "Updating package list..."
        apt-get update >/dev/null 2>&1
        
        # Install cpulimit if not present
        if ! command -v cpulimit &> /dev/null; then
            print_status "Installing cpulimit..."
            apt-get install -y cpulimit >/dev/null 2>&1
            if [ $? -eq 0 ]; then
                print_status "cpulimit installed successfully"
            else
                print_warning "Could not install cpulimit via apt, will compile from source later"
            fi
        else
            print_status "cpulimit already installed"
        fi
        
        # Install monitoring tools
        print_status "Installing monitoring tools..."
        apt-get install -y sysstat procps >/dev/null 2>&1
    else
        print_warning "apt-get not found. Please install cpulimit manually if needed."
    fi
}

# Configure systemd and start services
configure_systemd() {
    print_header "Configuring Systemd"
    
    # Reload systemd daemon
    print_status "Reloading systemd daemon..."
    systemctl daemon-reload
    
    # Disable direct service auto-start (timer will handle it)
    print_status "Disabling direct service auto-start..."
    systemctl disable "$SERVICE_NAME" 2>/dev/null || true
    
    # Enable timer
    print_status "Enabling timer for auto-start..."
    systemctl enable "$TIMER_NAME"
    
    # Start timer
    print_status "Starting timer..."
    systemctl start "$TIMER_NAME"
    
    # Wait a moment
    sleep 2
    
    # Show status
    print_status "Checking timer status..."
    systemctl status "$TIMER_NAME" --no-pager -l
}

# Create log directory and files
setup_logging() {
    print_header "Setting Up Logging"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Create log files with proper permissions
    touch "$LOG_DIR/random-cpu-limiter.log"
    touch "$LOG_DIR/random-cpu-limiter-service.log"
    touch "$LOG_DIR/random-cpu-limiter-service.error.log"
    
    # Set permissions
    chmod 644 "$LOG_DIR/random-cpu-limiter.log"
    chmod 644 "$LOG_DIR/random-cpu-limiter-service.log"
    chmod 644 "$LOG_DIR/random-cpu-limiter-service.error.log"
    
    print_status "Log files created in $LOG_DIR/"
}

# Create uninstall script
create_uninstall_script() {
    local uninstall_path="$INSTALL_PATH/uninstall-random-cpu-limiter.sh"
    
    print_header "Creating Uninstall Script"
    
    cat > "$uninstall_path" << 'EOF'
#!/bin/bash
# Uninstall script for Random CPU Limiter

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "=========================================="
echo "Random CPU Limiter Uninstaller"
echo "=========================================="

# Check root
if [ "$EUID" -ne 0 ]; then 
    echo -e "${RED}ERROR: Must run as root${NC}"
    echo "Use: sudo bash $0"
    exit 1
fi

# Stop and disable services
echo "Stopping services..."
systemctl stop random-cpu-limiter.service 2>/dev/null
systemctl stop random-cpu-limiter.timer 2>/dev/null

echo "Disabling services..."
systemctl disable random-cpu-limiter.service 2>/dev/null
systemctl disable random-cpu-limiter.timer 2>/dev/null

# Remove systemd files
echo "Removing systemd files..."
rm -f /etc/systemd/system/random-cpu-limiter.service
rm -f /etc/systemd/system/random-cpu-limiter.timer

# Remove main script
echo "Removing main script..."
rm -f /usr/local/bin/random-cpu-limiter.sh
rm -f /usr/local/bin/uninstall-random-cpu-limiter.sh

# Reload systemd
echo "Reloading systemd..."
systemctl daemon-reload

# Kill any remaining cpulimit processes
echo "Cleaning up cpulimit processes..."
pkill -9 -f "cpulimit" 2>/dev/null
killall -9 cpulimit 2>/dev/null

# Optional: Remove log files
read -p "Remove log files? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Removing log files..."
    rm -f /var/log/random-cpu-limiter.log*
    rm -f /var/log/random-cpu-limiter-service.log
    rm -f /var/log/random-cpu-limiter-service.error.log
fi

echo -e "${GREEN}Uninstallation complete!${NC}"
echo ""
echo "Note: cpulimit package is still installed."
echo "To remove it: sudo apt-get remove cpulimit"
EOF
    
    chmod +x "$uninstall_path"
    print_status "Uninstall script created: $uninstall_path"
}

# Show usage information
show_usage() {
    print_header "Installation Complete!"
    
    echo -e "${GREEN}Random CPU Limiter has been successfully installed!${NC}"
    echo ""
    echo "Service Details:"
    echo "----------------"
    echo -e "${BLUE}Main Script:${NC}      $INSTALL_PATH/$SCRIPT_NAME"
    echo -e "${BLUE}Service:${NC}          $SERVICE_PATH/$SERVICE_NAME"
    echo -e "${BLUE}Timer:${NC}            $SERVICE_PATH/$TIMER_NAME"
    echo -e "${BLUE}Log Files:${NC}        $LOG_DIR/random-cpu-limiter.log"
    echo "                  $LOG_DIR/random-cpu-limiter-service.log"
    echo ""
    echo "Service Behavior:"
    echo "-----------------"
    echo "• Starts 60 seconds after system boot"
    echo "• Applies random CPU limits: ${YELLOW}73-91%${NC}"
    echo "• For random durations: ${YELLOW}29-49 minutes${NC}"
    echo "• Short breaks: ${YELLOW}1-3 minutes${NC} between cycles"
    echo "• Auto-restarts if crashes"
    echo ""
    echo "Management Commands:"
    echo "--------------------"
    echo -e "${BLUE}Check status:${NC}     sudo systemctl status random-cpu-limiter.timer"
    echo -e "${BLUE}Start now:${NC}        sudo systemctl start random-cpu-limiter.service"
    echo -e "${BLUE}Stop:${NC}             sudo systemctl stop random-cpu-limiter.service"
    echo -e "${BLUE}Restart:${NC}          sudo systemctl restart random-cpu-limiter.service"
    echo -e "${BLUE}Enable/Disable:${NC}   sudo systemctl enable/disable random-cpu-limiter.timer"
    echo ""
    echo "Log Monitoring:"
    echo "---------------"
    echo -e "${BLUE}Main log:${NC}         sudo tail -f /var/log/random-cpu-limiter.log"
    echo -e "${BLUE}Service log:${NC}      sudo journalctl -u random-cpu-limiter -f"
    echo -e "${BLUE}Timer log:${NC}        sudo systemctl status random-cpu-limiter.timer"
    echo ""
    echo "Uninstall:"
    echo "----------"
    echo -e "${BLUE}Run:${NC}              sudo $INSTALL_PATH/uninstall-random-cpu-limiter.sh"
    echo ""
    echo -e "${GREEN}The service will start automatically in 60 seconds after boot.${NC}"
    echo -e "${YELLOW}To start it immediately, run: sudo systemctl start random-cpu-limiter.service${NC}"
}

# Test the installation
test_installation() {
    print_header "Testing Installation"
    
    echo "Checking files..."
    
    # Check if files exist
    if [ -f "$INSTALL_PATH/$SCRIPT_NAME" ]; then
        print_status "Main script: OK"
    else
        print_error "Main script not found!"
    fi
    
    if [ -f "$SERVICE_PATH/$SERVICE_NAME" ]; then
        print_status "Service file: OK"
    else
        print_error "Service file not found!"
    fi
    
    if [ -f "$SERVICE_PATH/$TIMER_NAME" ]; then
        print_status "Timer file: OK"
    else
        print_error "Timer file not found!"
    fi
    
    # Check systemd status
    echo ""
    echo "Checking systemd..."
    if systemctl is-active "$TIMER_NAME" >/dev/null 2>&1; then
        print_status "Timer is active"
    else
        print_warning "Timer is not active (may need to start manually)"
    fi
    
    if systemctl is-enabled "$TIMER_NAME" >/dev/null 2>&1; then
        print_status "Timer is enabled for boot"
    else
        print_error "Timer is not enabled for boot!"
    fi
}

# Main installation function
main_installation() {
    print_header "Random CPU Limiter Installation"
    echo "This script will install:"
    echo "1. Main CPU limiter script"
    echo "2. Systemd service file"
    echo "3. Systemd timer (60-second delay)"
    echo "4. Logging configuration"
    echo "5. Uninstall script"
    echo ""
    
    # Ask for confirmation
    read -p "Continue with installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled."
        exit 0
    fi
    
    # Run installation steps
    check_root
    install_dependencies
    create_main_script
    create_service_file
    create_timer_file
    setup_logging
    configure_systemd
    create_uninstall_script
    test_installation
    show_usage
}

# If script is run directly, start installation
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main_installation
fi
