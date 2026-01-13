#!/bin/bash

###############################################################################
# KVM_Spin_Ups – AlmaLinux 10.0 Installer
# Distribution-specific installer for AlmaLinux 10.0
# Licensed under MIT License
# © 2025 Ahmad M. Waddah and the KVM_Spin_Ups contributors
###############################################################################

set -Euo pipefail

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# --- Robustly source common dependencies -----------------------------------

# Try to unset guard variables so files will re-load cleanly (harmless if not set)
unset KVM_SPIN_UPS_COMMON_LOADED 2>/dev/null || true
unset KVM_SPIN_UPS_VALIDATION_LOADED 2>/dev/null || true

# Primary attempt to source from expected location
if [[ -f "$PROJECT_ROOT/src/common-functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/src/common-functions.sh"
fi

if [[ -f "$PROJECT_ROOT/src/validation-functions.sh" ]]; then
    # shellcheck disable=SC1090
    source "$PROJECT_ROOT/src/validation-functions.sh"
fi

# Fallback attempts if functions are still missing: try relative locations and alternatives
FALLBACKS=(
    "$PROJECT_ROOT/src/lib/common-functions.sh"
    "$PROJECT_ROOT/src/lib/validation-functions.sh"
    "$PROJECT_ROOT/src/dependencies/vm-functions.sh"
)

for f in "${FALLBACKS[@]}"; do
    # If the main function is not defined yet, try additional fallback files
    if ! type validate_vm_parameters >/dev/null 2>&1 && [[ -f "$f" ]]; then
        # shellcheck disable=SC1090
        source "$f" || true
    fi
done

# --- Verify required functions exist ---------------------------------------

# List of functions this installer expects (if you add features, extend here)
required_funcs=(
    validate_vm_parameters
    check_vm_exists
    check_disk_exists
    generate_password_hash
    validate_password_hash
    download_iso
    setup_network
    configure_firewall
    detect_host_ip
    start_ks_server
    monitor_installation
    escape_sed_pattern
    log_info
    log_error
    log_warn
    log_success
    log_cyan
    handle_error
    handle_interrupt
    cleanup
)

missing_funcs=()
for fn in "${required_funcs[@]}"; do
    if ! type "$fn" >/dev/null 2>&1; then
        missing_funcs+=("$fn")
    fi
done

if [[ ${#missing_funcs[@]} -gt 0 ]]; then
    echo "ERROR: The following required helper functions are missing: ${missing_funcs[*]}" >&2
    echo "Attempted to source:" >&2
    echo "  $PROJECT_ROOT/dependencies/common-functions.sh" >&2
    echo "  $PROJECT_ROOT/dependencies/validation-functions.sh" >&2
    echo ""
    echo "Please ensure those files exist and define the listed functions." >&2
    echo "You can search for a missing function with:" >&2
    echo "  grep -R \"${missing_funcs[0]}\" \"$PROJECT_ROOT\" || true" >&2
    exit 1
fi

# --------------------------------- Debugging Only (can be removed) ----------
# echo "DEBUG: Sourced validation-functions.sh from: $PROJECT_ROOT/dependencies/validation-functions.sh"

# Check if variables are loaded (ISO_DIR and other project variables should be set in common-functions)
if [[ -z "${ISO_DIR:-}" ]]; then
    log_error "ERROR: Common variables not loaded in Alma installer (ISO_DIR is empty)."
    log_error "Make sure common-functions.sh sets ISO_DIR, IMAGE_DIR, BOOT_DIR, HTTP_PORT, etc."
    exit 1
fi

# AlmaLinux specific configuration
readonly ALMA_ISO_URL="https://repo.almalinux.org/almalinux/10/isos/x86_64/AlmaLinux-10.1-x86_64-minimal.iso"
readonly ALMA_ISO_PATH="$ISO_DIR/AlmaLinux-10.1-x86_64-minimal.iso"
readonly ALMA_OS_VARIANT="almalinux10"
readonly ALMA_BOOT_DIR="$BOOT_DIR/almalinux10"

# === ALMA-SPECIFIC FUNCTIONS ===
generate_alma_kickstart() {
    local ks_file="$1"
    local vm_name="$2"
    local vm_user="$3"
    local user_pass_hash="$4"
    local root_pass_hash="$5"
    local timezone="$6"
    
    log_info "Generating Alma Linux 10.0 kickstart file from template..."
    
    local template_file="$PROJECT_ROOT/src/templates/alma-ks.cfg.template"
    
    if [[ ! -f "$template_file" ]]; then
        log_error "Template file not found: $template_file"
        return 1
    fi
    
    if ! cp "$template_file" "$ks_file"; then
        log_error "Failed to copy template to $ks_file"
        return 1
    fi
    
    local safe_hostname
    local safe_username
    local safe_user_hash
    local safe_root_hash
    local safe_timezone

    safe_hostname=$(escape_sed_pattern "$vm_name")
    safe_username=$(escape_sed_pattern "$vm_user")
    safe_user_hash=$(escape_sed_pattern "$user_pass_hash")
    safe_root_hash=$(escape_sed_pattern "$root_pass_hash")
    safe_timezone=$(escape_sed_pattern "$timezone")
    
    sed -i "s/{{HOSTNAME}}/$safe_hostname/g" "$ks_file"
    sed -i "s/{{USERNAME}}/$safe_username/g" "$ks_file"
    sed -i "s/{{USER_PASSWORD_HASH}}/$safe_user_hash/g" "$ks_file"
    sed -i "s/{{ROOT_PASSWORD_HASH}}/$safe_root_hash/g" "$ks_file"
    sed -i "s/{{TIMEZONE}}/$safe_timezone/g" "$ks_file"
    
    log_success "Alma Linux kickstart file generated: $ks_file"
    return 0
}

create_alma_vm() {
    local vm_name="$1"
    local ram="$2"
    local vcpus="$3"
    local disk="$4"
    local timezone="$5"
    local user_pass="$6"
    local root_pass="$7"

    log_info "Starting AlmaLinux 10.0 VM creation: $vm_name"
    
    # Validate parameters
    if ! validate_vm_parameters "$vm_name" "$ram" "$vcpus" "$disk" "$timezone"; then
        return 1
    fi
    
    # Check if VM already exists (check_vm_exists should return non-zero if exists)
    if ! check_vm_exists "$vm_name"; then
        return 1
    fi
    
    local disk_path="$IMAGE_DIR/$vm_name.qcow2"
    if ! check_disk_exists "$disk_path"; then
        return 1
    fi
    
    # Generate password hashes
    log_info "Generating password hashes..."
    local user_pass_hash
    local root_pass_hash
    user_pass_hash=$(generate_password_hash "$user_pass")
    root_pass_hash=$(generate_password_hash "$root_pass")
    
    if [[ -z "$user_pass_hash" || -z "$root_pass_hash" ]]; then
        log_error "Failed to generate password hashes"
        return 1
    fi
    
    # Validate hash format
    if ! validate_password_hash "$user_pass_hash" "User password hash"; then
        log_error "Invalid user password hash format"
        return 1
    fi
    
    if ! validate_password_hash "$root_pass_hash" "Root password hash"; then
        log_error "Invalid root password hash format"
        return 1
    fi
    
    # Download and extract ISO
    if ! download_iso "$ALMA_ISO_URL" "$ALMA_ISO_PATH" "$ALMA_OS_VARIANT"; then
        log_error "Failed to prepare AlmaLinux ISO"
        return 1
    fi
    
    # Setup network
    if ! setup_network; then
        log_error "Network setup failed"
        return 1
    fi
    
    # Configure firewall
    configure_firewall
    
    # Detect host IP
    HOST_IP=$(detect_host_ip)
    if [[ -z "$HOST_IP" ]]; then
        log_error "Could not detect host IP"
        return 1
    fi
    log_success "Detected host IP: $HOST_IP"
    
    # Generate kickstart file
    local ks_file="$IMAGE_DIR/ks_$vm_name.cfg"
    generate_alma_kickstart "$ks_file" "$vm_name" "ops" "$user_pass_hash" "$root_pass_hash" "$timezone"
    
    # Start HTTP server
    if ! start_ks_server "$IMAGE_DIR"; then
        log_error "Failed to start HTTP server"
        return 1
    fi
    
    # Create disk
    log_info "Creating disk: $disk_path (${disk}GB)"
    if ! qemu-img create -f qcow2 "$disk_path" "${disk}G"; then
        log_error "Failed to create disk image"
        return 1
    fi
    
    # Create VM with virt-install
    log_info "Starting AlmaLinux 10.0 installation..."
    log_cyan "   VM Name: $vm_name"
    log_cyan "   RAM: ${ram}MB"
    log_cyan "   vCPUs: $vcpus"
    log_cyan "   Disk: ${disk}GB"
    log_cyan "   Timezone: $timezone"
    
    if ! virt-install \
        --name "$vm_name" \
        --memory "$ram" \
        --vcpus "$vcpus" \
        --disk "path=$disk_path,format=qcow2" \
        --network network=default \
        --os-variant "$ALMA_OS_VARIANT" \
        --location "$ALMA_ISO_PATH" \
        --extra-args "inst.ks=http://$HOST_IP:$HTTP_PORT/ks_$vm_name.cfg console=ttyS0,115200n8 inst.text inst.repo=cdrom" \
        --graphics none \
        --console pty,target_type=serial \
        --noautoconsole \
        --wait -1; then
    
        log_error "Failed to create AlmaLinux VM: $vm_name"
        return 1
    fi
    
    # Monitor installation
    if monitor_installation "$vm_name"; then
        log_success "AlmaLinux 10.0 VM '$vm_name' created successfully"
        log_cyan "   Connect via: virsh console $vm_name"
        log_cyan "   SSH via: ssh ops@<vm-ip>"
        log_cyan "   Disk location: $disk_path"
        
        # Clean up kickstart file after successful installation
        rm -f "$ks_file"
        return 0
    else
        log_error "AlmaLinux installation failed for $vm_name"
        log_warn "Kickstart file kept for debugging: $ks_file"
        return 1
    fi
}

# === MAIN INSTALLER FUNCTION ===
main() {
    local vm_name="$1"
    local ram="$2"
    local vcpus="$3"
    local disk="$4"
    local timezone="$5"
    local user_pass="$6"
    local root_pass="$7"
    
    # Verify common variables are available
    if [[ -z "${ISO_DIR:-}" ]]; then
        log_error "Common variables not loaded. ISO_DIR is empty."
        return 1
    fi
    
    # Enable cleanup
    CLEANUP_ALLOWED=true
    
    # Set error handling
    trap 'handle_error $LINENO' ERR
    trap 'handle_interrupt' INT TERM
    trap cleanup EXIT
    
    log_info "🚀 Starting Alma Linux 10.0 VM creation process"
    log_cyan "=================================================="
    
    if create_alma_vm "$vm_name" "$ram" "$vcpus" "$disk" "$timezone" "$user_pass" "$root_pass"; then
        log_success "🎉 Alma Linux 10.0 VM creation completed successfully!"
        return 0
    else
        log_error "💥 Alma Linux 10.0 VM creation failed"
        return 1
    fi
}

# === SCRIPT ENTRY POINT ===
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check if called with correct number of parameters
    if [[ $# -ne 7 ]]; then
        echo "Usage: $0 <vm_name> <ram_mb> <vcpus> <disk_gb> <timezone> <user_pass> <root_pass>"
        echo "Example: $0 my-alma-vm 3072 2 40 Africa/Cairo myuserpass myrootpass"
        exit 1
    fi
    
    # Execute main function with parameters
    main "$1" "$2" "$3" "$4" "$5" "$6" "$7"
fi
