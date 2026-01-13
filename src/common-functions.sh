#!/bin/bash

###############################################################################
# KVM_Spin_Ups – Common Functions Library
# Shared functions for all distribution installers
# Licensed under MIT License
# © 2025 Ahmad M. Waddah and the KVM_Spin_Ups contributors
###############################################################################

# Prevent multiple sourcing
if [[ -n "${KVM_SPIN_UPS_COMMON_LOADED:-}" ]]; then
    return 0
fi
export KVM_SPIN_UPS_COMMON_LOADED=1

# Get the directory where this script is located
COMMON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Global Configuration - use absolute paths based on project root
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly VM_DIR="$HOME/KVM_Spin_Ups"
readonly ISO_DIR="$VM_DIR/iso"
readonly IMAGE_DIR="$VM_DIR/vms"
readonly TEMPLATE_DIR="$PROJECT_ROOT/src/templates"
readonly BOOT_DIR="$VM_DIR/mounts"
readonly DEPENDENCIES_DIR="$PROJECT_ROOT/src"
readonly DISTROS_DIR="$PROJECT_ROOT/src/distros-installers"
readonly HTTP_PORT=8080

# ANSI Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BLUE='\033[0;34m'
readonly MAGENTA='\033[0;35m'
readonly NC='\033[0m'

# Global variables
declare -a VM_CONFIGS=()
KS_PID=""
CLEANUP_ALLOWED=false
HOST_IP=""

# === LOGGING FUNCTIONS ===
log_info() { echo -e "${BLUE}🔧 $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_cyan() { echo -e "${CYAN}$1${NC}"; }
log_magenta() { echo -e "${MAGENTA}$1${NC}"; }

# === ERROR HANDLING ===
handle_error() {
    local line=$1
    log_error "Error on line $line. Exiting."
    exit 1
}

handle_interrupt() {
    echo -e "\n${YELLOW}⚠️  Script interrupted by user.${NC}"
    exit 130
}

# === DIRECTORY MANAGEMENT ===
ensure_directories() {
    log_info "Setting up directory structure..."
    local dirs=("$VM_DIR" "$ISO_DIR" "$IMAGE_DIR" "$TEMPLATE_DIR" "$BOOT_DIR")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        chmod 755 "$dir"
    done
    log_success "Directory structure ready"
}

# === DEPENDENCY CHECKS ===
check_dependencies() {
    log_info "Checking system dependencies..."
    local missing_deps=0
    local essential_deps=("virsh" "qemu-img" "curl" "sed" "awk" "grep" "python3")
    local hashing_tool_found=0

    # Check essential tools
    for dep in "${essential_deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "Missing essential dependency: ${dep}"
            missing_deps=1
        fi
    done

    # Check hashing tools
    if command -v "grub-crypt" &> /dev/null || command -v "openssl" &> /dev/null || command -v "python3" &> /dev/null; then
        hashing_tool_found=1
    fi

    if [ "$hashing_tool_found" -eq 0 ]; then
        log_error "Missing password hashing tools (grub-crypt, openssl, or python3)"
        missing_deps=1
    fi

    if [ "$missing_deps" -eq 1 ]; then
        log_error "Please install missing dependencies and try again."
        exit 1
    fi
    log_success "All dependencies satisfied"
}

check_permissions() {
    command -v virsh >/dev/null || { 
        log_error "virsh not found. Install libvirt-daemon-system"
        exit 1
    }
    
    virsh list --all >/dev/null 2>&1 || {
        log_error "Permission denied for libvirt"
        log_warn "Run: sudo usermod -a -G libvirt,kvm \$USER"
        log_warn "Then log out and back in, or run: newgrp libvirt"
        exit 1
    }
}


# === NETWORK MANAGEMENT ===
setup_network() {
    log_info "Configuring libvirt network..."
    
    if ! virsh net-info default &>/dev/null; then
        log_warn "Creating default libvirt network..."
        sudo virsh net-define /dev/stdin <<EOF
<network>
  <name>default</name>
  <uuid>$(uuidgen)</uuid>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF
        sudo virsh net-autostart default
        sudo virsh net-start default
        log_success "Default network created"
    elif ! virsh net-list --state-active | grep -q default; then
        log_warn "Starting default network..."
        sudo virsh net-start default
        log_success "Default network started"
    else
        log_success "Default network active"
    fi
    
    if ! ip link show virbr0 &>/dev/null; then
        log_error "Network bridge 'virbr0' not found."
        return 1
    fi
}

detect_host_ip() {
    local detected_ip=""
    
    if ip route get 192.168.122.1 >/dev/null 2>&1; then
        detected_ip="192.168.122.1"
    elif ip addr show virbr0 >/dev/null 2>&1; then
        detected_ip=$(ip addr show virbr0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)
    else
        detected_ip=$(ip route get 1.1.1.1 | grep -oP 'src \K\S+' | head -1)
    fi
    
    echo "$detected_ip"
}

configure_firewall() {
    log_info "Configuring firewall for port $HTTP_PORT..."
    if command -v firewall-cmd &> /dev/null; then
        sudo firewall-cmd --permanent --add-port=$HTTP_PORT/tcp >/dev/null 2>&1 || true
        sudo firewall-cmd --reload >/dev/null 2>&1 || true
    elif command -v ufw &> /dev/null; then
        sudo ufw allow $HTTP_PORT/tcp >/dev/null 2>&1 || true
        sudo ufw reload >/dev/null 2>&1 || true
    else
        log_warn "No supported firewall detected"
    fi
}

# === PASSWORD MANAGEMENT ===
read_password() {
    local prompt="$1"
    local pass=""
    
    printf "%b" "$prompt" >&2
    stty -echo
    while IFS= read -r -n1 -s char; do
        if [[ -z "$char" ]]; then
            break
        fi
        if [[ "$char" == $'\177' ]]; then 
            if [ -n "$pass" ]; then
                pass="${pass%?}"
                printf '\b \b' >&2
            fi
        else
            pass+="$char"
            printf '*' >&2
        fi
    done
    stty echo
    printf '\n' >&2
    echo "$pass"
}

generate_password_hash() {
    local password="$1"
    local hash=""
    
    # Method 1: Use Python with proper SHA-512 crypt
    hash=$(python3 -c "
import sys
import crypt
import base64
import os

password = sys.argv[1]

# Generate proper SHA-512 crypt hash
try:
    # Generate random 16-character salt for SHA-512
    salt_chars = './0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
    salt = ''.join([salt_chars[ord(os.urandom(1)) % len(salt_chars)] for _ in range(16)])
    hash = crypt.crypt(password, '\$6\$' + salt + '\$')
    print(hash)
except Exception as e:
    print('ERROR')
    sys.exit(1)
" "$password" 2>/dev/null)
    
    if [[ $? -eq 0 ]] && [[ -n "$hash" ]] && [[ "$hash" != "ERROR" ]]; then
        printf "%s" "$hash"
        return 0
    fi
    
    # Method 2: Use grub-crypt as fallback
    if command -v grub-crypt >/dev/null 2>&1; then
        hash=$(echo -n "$password" | grub-crypt --sha-512 2>/dev/null)
        if [[ $? -eq 0 ]] && [[ -n "$hash" ]]; then
            printf "%s" "$hash"
            return 0
        fi
    fi
    
    # Method 3: Use openssl as last resort
    if command -v openssl >/dev/null 2>&1; then
        hash=$(openssl passwd -6 "$password" 2>/dev/null)
        if [[ $? -eq 0 ]] && [[ -n "$hash" ]]; then
            printf "%s" "$hash"
            return 0
        fi
    fi
    
    log_error "ALL password hash methods failed"
    return 1
}

# Safe string replacement for sed
escape_sed_pattern() {
    local string="$1"
    echo "$string" | sed 's/[\/&]/\\&/g'
}

# === ISO MANAGEMENT ===
download_iso() {
    local url="$1"
    local iso_path="$2"
    local os_variant="$3"
    local boot_dir="$BOOT_DIR/$os_variant"

    if [[ -f "$iso_path" ]]; then
        log_info "ISO exists: $(basename "$iso_path")"
    else
        log_warn "Downloading ISO: $(basename "$iso_path")"
        mkdir -p "$(dirname "$iso_path")"
        if ! curl -L -o "$iso_path" "$url" --progress-bar; then
            log_error "Failed to download ISO"
            return 1
        fi
        log_success "ISO downloaded"
    fi

    if [[ ! -f "$boot_dir/vmlinuz" ]] || [[ ! -f "$boot_dir/initrd.img" ]]; then
        extract_boot_files "$iso_path" "$boot_dir" "$os_variant"
    else
        log_info "Boot files already extracted"
    fi
}

extract_boot_files() {
    local iso_path="$1"
    local boot_dir="$2"
    local os_variant="$3"
    
    log_info "Extracting boot files for $os_variant..."
    mkdir -p "$boot_dir"
    
    local TEMP_MOUNT="$BOOT_DIR/temp_mount_$(date +%s)"
    mkdir -p "$TEMP_MOUNT"
    
    if ! sudo mount -o loop "$iso_path" "$TEMP_MOUNT" 2>/dev/null; then
        log_error "Failed to mount ISO"
        return 1
    fi

    local vmlinuz_path="" initrd_path=""
    
    # Find vmlinuz
    for location in "/boot/vmlinuz" "/images/pxeboot/vmlinuz" "/isolinux/vmlinuz" "/vmlinuz"; do
        if [[ -f "$TEMP_MOUNT$location" ]]; then
            vmlinuz_path="$TEMP_MOUNT$location"
            break
        fi
    done
    
    # Find initrd
    for location in "/boot/initrd.img" "/images/pxeboot/initrd.img" "/isolinux/initrd.img" "/initrd.img"; do
        if [[ -f "$TEMP_MOUNT$location" ]]; then
            initrd_path="$TEMP_MOUNT$location"
            break
        fi
    done

    if [[ -n "$vmlinuz_path" ]] && [[ -n "$initrd_path" ]]; then
        cp "$vmlinuz_path" "$boot_dir/vmlinuz" && \
        cp "$initrd_path" "$boot_dir/initrd.img" && \
        sudo chown "$(id -u):$(id -g)" "$boot_dir"/vmlinuz "$boot_dir"/initrd.img
        log_success "Boot files extracted"
    else
        log_error "Boot files not found in ISO"
        sudo umount "$TEMP_MOUNT"
        rmdir "$TEMP_MOUNT"
        return 1
    fi

    sudo umount "$TEMP_MOUNT"
    rmdir "$TEMP_MOUNT"
}

# === HTTP SERVER MANAGEMENT ===
start_ks_server() {
    local serve_dir="$1"
    local port=$HTTP_PORT

    log_info "Starting HTTP server on port $port..."
    
    # Kill existing server
    if pid=$(lsof -t -i :$port -sTCP:LISTEN 2>/dev/null); then
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -9 "$pid" 2>/dev/null || true
    fi

    cd "$serve_dir" && python3 -m http.server "$port" --bind 0.0.0.0 > /dev/null 2>&1 &
    KS_PID=$!
    echo "$KS_PID" > "$VM_DIR/http_server.pid"

    sleep 2

    if ! ps -p "$KS_PID" > /dev/null 2>&1; then
        log_error "HTTP server failed to start"
        return 1
    fi

    # Test server
    local test_file="$serve_dir/test_http.txt"
    echo "test" > "$test_file"
    
    local attempt=1
    while [[ $attempt -le 10 ]]; do
        if curl -s --connect-timeout 2 "http://127.0.0.1:$port/test_http.txt" > /dev/null; then
            rm -f "$test_file"
            log_success "HTTP server running on http://0.0.0.0:$port"
            return 0
        fi
        sleep 1
        ((attempt++))
    done

    log_error "HTTP server not responding"
    kill "$KS_PID" 2>/dev/null || true
    rm -f "$test_file"
    return 1
}

ensure_ks_server() {
    local serve_dir="$1"
    local port=$HTTP_PORT

    if [[ -z "$KS_PID" ]] || ! ps -p "$KS_PID" > /dev/null 2>&1; then
        start_ks_server "$serve_dir"
    elif ! curl -s --connect-timeout 2 "http://127.0.0.1:$port/" > /dev/null 2>&1; then
        kill "$KS_PID" 2>/dev/null || true
        start_ks_server "$serve_dir"
    fi
}

# === VM OPERATIONS ===
check_vm_exists() {
    local vm_name="$1"
    if virsh dominfo "$vm_name" &>/dev/null; then
        log_error "VM '$vm_name' already exists"
        return 1
    fi
    return 0
}

check_disk_exists() {
    local disk_path="$1"
    if [[ -f "$disk_path" ]]; then
        log_error "Disk image '$disk_path' already exists"
        return 1
    fi
    return 0
}

monitor_installation() {
    local vm_name="$1"
    local max_wait=1800
    local wait_time=0
    local installation_started=false
    
    log_warn "Monitoring installation for $vm_name (max 30 minutes)..."
    
    while [[ $wait_time -lt $max_wait ]]; do
        local state=$(virsh domstate "$vm_name" 2>/dev/null || echo "not found")
        
        case "$state" in
            "shut off")
                log_success "Installation completed for $vm_name (VM shut down)"
                return 0
                ;;
            "running")
                # Check if installation is actually progressing by looking at disk activity
                local disk_activity=$(virsh domblkstat "$vm_name" 2>/dev/null | grep -c "rd_bytes\|wr_bytes" || echo "0")
                
                # If no disk activity for a while and VM has been running, installation might be stuck
                if [[ "$installation_started" == "true" ]] && [[ "$disk_activity" -eq 0 ]]; then
                    local no_activity_time=$((wait_time - activity_last_seen))
                    if [[ $no_activity_time -gt 300 ]]; then  # 5 minutes without activity
                        log_warn "No disk activity detected for 5 minutes. Installation may be stuck."
                        log_warn "VM state: running but possibly waiting for input"
                        return 1
                    fi
                else
                    installation_started=true
                    activity_last_seen=$wait_time
                fi
                
                echo -ne "${YELLOW}⏳ Installing ($((wait_time/60))m $((wait_time%60))s)\r${NC}"
                sleep 10
                ((wait_time+=10))
                ;;
            "paused")
                log_warn "VM $vm_name is paused. Resuming..."
                virsh resume "$vm_name" 2>/dev/null || true
                sleep 10
                ((wait_time+=10))
                ;;
            "crashed"|"not found")
                log_error "VM $vm_name is in unexpected state: $state"
                return 1
                ;;
            *)
                echo -ne "${YELLOW}⏳ Current state: $state... ($((wait_time/60))m $((wait_time%60))s)\r${NC}"
                sleep 10
                ((wait_time+=10))
                ;;
        esac
    done

    log_error "Installation timeout for $vm_name after 30 minutes"
    log_warn "The VM may be waiting for user input or installation may have failed"
    log_warn "Check console: virsh console $vm_name"
    return 1
}

# === CLEANUP ===
cleanup() {
    if [[ "$CLEANUP_ALLOWED" == "true" ]]; then
        log_warn "Performing cleanup..."
        
        if [[ -n "$KS_PID" ]] && kill -0 "$KS_PID" 2>/dev/null; then
            kill "$KS_PID" 2>/dev/null || true
        fi
        
        for mount_point in "$BOOT_DIR"/temp_mount_*; do
            if [[ -d "$mount_point" ]]; then
                sudo umount "$mount_point" 2>/dev/null || true
                rmdir "$mount_point" 2>/dev/null || true
            fi
        done
        
        rm -f "$IMAGE_DIR"/ks_*.cfg
        rm -f "$VM_DIR/http_server.pid"
        rm -f "$IMAGE_DIR/test_http.txt"
        
        log_success "Cleanup completed"
    fi
}

# Initialize traps (only if this is the main script, not when sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    trap 'handle_error $LINENO' ERR
    trap 'handle_interrupt' INT TERM
    trap cleanup EXIT
fi