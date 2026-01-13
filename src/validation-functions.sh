#!/bin/bash

###############################################################################
# KVM_Spin_Ups – Validation Functions Library
# Input validation and system checks
# Licensed under MIT License
# © 2025 Ahmad M. Waddah and the KVM_Spin_Ups contributors
###############################################################################

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions using absolute path
source "${SCRIPT_DIR}/common-functions.sh"

# === INPUT VALIDATION ===
validate_hostname() {
    local hostname="$1"
    
    if [[ -z "$hostname" ]]; then
        log_error "Hostname cannot be empty."
        return 1
    fi
    
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        log_error "Hostname must contain only letters, digits, hyphens (-), or dots (.)."
        log_warn "Example: webserver01, db-server-02, app.example.com"
        return 1
    fi
    
    if [[ "$hostname" =~ ^- ]] || [[ "$hostname" =~ -$ ]] || \
       [[ "$hostname" =~ \.$ ]] || [[ "$hostname" =~ ^\. ]]; then
        log_error "Hostname cannot start or end with hyphen (-) or dot (.)"
        return 1
    fi
    
    if [[ "$hostname" =~ \-\- ]] || [[ "$hostname" =~ \.\. ]]; then
        log_error "Hostname cannot contain consecutive hyphens (--) or dots (..)"
        return 1
    fi
    
    return 0
}

validate_number_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local description="$4"
    
    if ! [[ "$value" =~ ^[0-9]+$ ]]; then
        log_error "$description must be a number."
        return 1
    fi
    
    if [ "$value" -lt "$min" ] || [ "$value" -gt "$max" ]; then
        log_error "$description must be between $min and $max."
        return 1
    fi
    
    return 0
}

validate_timezone() {
    local timezone="$1"
    
    if ! timedatectl list-timezones 2>/dev/null | grep -q "^$timezone$"; then
        log_error "Invalid timezone: $timezone"
        log_warn "Run 'timedatectl list-timezones' to see valid options."
        return 1
    fi
    
    return 0
}

validate_password() {
    local password="$1"
    local description="$2"
    
    # Use the more comprehensive function
    validate_password_strength "$password" "$description"
}

validate_password_hash() {
    local hash="$1"
    local description="${2:-Password hash}"
    
    if [[ -z "$hash" ]]; then
        log_error "$description cannot be empty."
        return 1
    fi
    
    # Check if it's a valid SHA-512 crypt hash (starts with $6$)
    if [[ "$hash" =~ ^\$6\$[a-zA-Z0-9./]{1,16}\$[a-zA-Z0-9./]{86}$ ]]; then
        return 0
    fi
    
    # Also accept other common crypt formats for compatibility
    if [[ "$hash" =~ ^\$[0-9a-zA-Z]+\$[a-zA-Z0-9./]+\$[a-zA-Z0-9./]+ ]]; then
        log_warn "$description uses non-SHA512 crypt format. This may cause compatibility issues."
        return 0
    fi
    
    log_error "Invalid $description format: $hash"
    log_error "Expected SHA-512 format: \$6\$salt\$hash"
    log_error "Hash should be approximately 90-100 characters starting with \$6\$"
    return 1
}

# === PASSWORD VALIDATION ===
validate_password_strength() {
    local password="$1"
    local description="$2"
    
    if [[ ${#password} -lt 8 ]]; then
        log_error "$description must be at least 8 characters long."
        return 1
    fi
    
    # Optional: Add more strength checks if desired
    if [[ ! "$password" =~ [0-9] ]]; then
        log_warn "$description should contain at least one number for better security."
    fi
    
    if [[ ! "$password" =~ [A-Z] ]]; then
        log_warn "$description should contain at least one uppercase letter for better security."
    fi
    
    if [[ ! "$password" =~ [a-z] ]]; then
        log_warn "$description should contain at least one lowercase letter for better security."
    fi
    
    return 0
}

validate_disk_space() {
    local required_gb="$1"
    local vm_dir="$2"
    
    local available_kb=$(df "$vm_dir" | awk 'NR==2 {print $4}')
    local available_gb=$((available_kb / 1024 / 1024))
    
    if [ "$available_gb" -lt "$required_gb" ]; then
        log_error "Insufficient disk space. Required: ${required_gb}GB, Available: ${available_gb}GB"
        return 1
    fi
    
    return 0
}

validate_memory() {
    local required_mb="$1"
    local total_mb available_mb
    
    # Get total and available memory
    total_mb=$(free -m | awk '/^Mem:/ {print $2}')
    available_mb=$(free -m | awk '/^Mem:/ {print $7}')
    
    log_cyan "Memory: Total: ${total_mb}MB, Available: ${available_mb}MB, Requested: ${required_mb}MB"
    
    # Only warn if available is less than requested
    if [ "$available_mb" -lt "$required_mb" ]; then
        log_warn "Low available memory. Requested: ${required_mb}MB, Available: ${available_mb}MB"
        log_warn "VM may run slowly. Consider reducing RAM allocation or closing other applications."
        # Don't return error - just warn but allow continuation
    fi
    
    return 0
}

validate_cpu_cores() {
    local required_cores="$1"
    local available_cores
    
    available_cores=$(nproc)
    
    if [ "$available_cores" -lt "$required_cores" ]; then
        log_error "Insufficient CPU cores. Required: $required_cores, Available: $available_cores"
        return 1
    fi
    
    return 0
}

# === SYSTEM CHECKS ===
check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check virtualization support (warning only)
    if ! grep -q -E "vmx|svm" /proc/cpuinfo; then
        log_warn "CPU virtualization extensions not found. Performance may be degraded."
    else
        log_success "CPU virtualization extensions: Enabled"
    fi
    
    # Check KVM support (warning only)
    if ! lsmod | grep -q kvm; then
        log_warn "KVM kernel module not loaded. Install with: sudo modprobe kvm"
        if [[ "$(uname -m)" == "x86_64" ]]; then
            log_warn "For Intel: sudo modprobe kvm_intel"
            log_warn "For AMD: sudo modprobe kvm_amd"
        fi
    else
        log_success "KVM support: Available"
    fi
    
    # Check disk space (minimum 10GB for operations)
    if ! validate_disk_space 10 "$VM_DIR"; then
        log_error "Insufficient disk space for VM operations."
        return 1
    fi
    log_success "Disk space: Sufficient"
    
    # Check available memory (warning only, don't fail)
    validate_memory 2048  # Reduced requirement
    
    log_success "System requirements satisfied"
    return 0
}

check_kickstart_template() {
    local template_path="$1"
    local distro_name="$2"
    
    if [[ ! -f "$template_path" ]]; then
        log_error "Kickstart template missing for $distro_name: $template_path"
        return 1
    fi
    
    if head -1 "$template_path" | grep -q "cat.*EOF"; then
        log_error "Invalid kickstart template - contains bash code: $template_path"
        return 1
    fi
    
    # Check for required placeholders
    local required_vars=("{{HOSTNAME}}" "{{USERNAME}}" "{{USER_PASSWORD_HASH}}" "{{ROOT_PASSWORD_HASH}}" "{{TIMEZONE}}")
    for var in "${required_vars[@]}"; do
        if ! grep -q "$var" "$template_path"; then
            log_error "Kickstart template missing required variable: $var"
            return 1
        fi
    done
    
    log_success "Kickstart template validated: $template_path"
    return 0
}

# === DISTRIBUTION VALIDATION ===
validate_distribution() {
    local distro="$1"
    local supported_distros=("rocky" "alma")
    
    for supported in "${supported_distros[@]}"; do
        if [[ "$distro" == "$supported" ]]; then
            return 0
        fi
    done
    
    log_error "Unsupported distribution: $distro"
    log_warn "Supported distributions: ${supported_distros[*]}"
    return 1
}

# === NETWORK VALIDATION ===
validate_network_connectivity() {
    log_info "Checking network connectivity..."
    
    if ! curl -s --connect-timeout 10 https://www.google.com > /dev/null; then
        log_warn "No internet connectivity detected. ISO downloads will fail."
        return 1
    fi
    
    log_success "Network connectivity confirmed"
    return 0
}

# Prevent multiple loads
if [[ -n "${KVM_SPIN_UPS_VALIDATION_LOADED:-}" ]]; then
    return 0
fi
KVM_SPIN_UPS_VALIDATION_LOADED=true

# === COMPREHENSIVE VALIDATION ===
validate_vm_parameters() {
    local vm_name="$1"
    local ram="$2"
    local vcpus="$3"
    local disk="$4"
    local timezone="$5"

    # Basic sanity checks
    if [[ -z "$vm_name" || -z "$ram" || -z "$vcpus" || -z "$disk" || -z "$timezone" ]]; then
        log_error "One or more VM parameters are missing."
        return 1
    fi

    if ! [[ "$ram" =~ ^[0-9]+$ ]] || (( ram < 512 )); then
        log_error "RAM must be a number (min 512MB)."
        return 1
    fi

    if ! [[ "$vcpus" =~ ^[0-9]+$ ]] || (( vcpus < 1 )); then
        log_error "vCPUs must be at least 1."
        return 1
    fi

    if ! [[ "$disk" =~ ^[0-9]+$ ]] || (( disk < 10 )); then
        log_error "Disk size must be at least 10GB."
        return 1
    fi

    if ! timedatectl list-timezones | grep -q "^$timezone$"; then
        log_error "Invalid timezone: $timezone"
        return 1
    fi

    log_success "VM parameters validated successfully."
    return 0
}
