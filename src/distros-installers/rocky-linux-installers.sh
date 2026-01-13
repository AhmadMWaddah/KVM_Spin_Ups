#!/bin/bash

###############################################################################
# KVM_Spin_Ups – Rocky Linux 9.6 Installer
# Distribution-specific installer for Rocky Linux 9.6
# Licensed under MIT License
# © 2025 Ahmad M. Waddah and the KVM_Spin_Ups contributors
###############################################################################

set -Euo pipefail

# -------------------- [ PATH SETUP ] --------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPEND_DIR="$PROJECT_ROOT/src"

# -------------------- [ SOURCE DEPENDENCIES ] --------------------
unset KVM_SPIN_UPS_COMMON_LOADED 2>/dev/null || true
unset KVM_SPIN_UPS_VALIDATION_LOADED 2>/dev/null || true

# Load dependencies with validation
if [[ -f "$DEPEND_DIR/common-functions.sh" ]]; then
    source "$DEPEND_DIR/common-functions.sh"
else
    echo "ERROR: Missing common-functions.sh in dependencies." >&2
    exit 1
fi

if [[ -f "$DEPEND_DIR/validation-functions.sh" ]]; then
    source "$DEPEND_DIR/validation-functions.sh"
else
    echo "WARN: validation-functions.sh not found — using fallback validator." >&2
    # === Fallback minimal validator ===
    validate_vm_parameters() {
        local vm_name="$1"
        local ram="$2"
        local vcpus="$3"
        local disk="$4"
        local timezone="$5"
        if [[ -z "$vm_name" || -z "$ram" || -z "$vcpus" || -z "$disk" || -z "$timezone" ]]; then
            echo "Missing required parameters" >&2
            return 1
        fi
        [[ "$ram" =~ ^[0-9]+$ && "$vcpus" =~ ^[0-9]+$ && "$disk" =~ ^[0-9]+$ ]] || {
            echo "RAM, vCPUs, and Disk must be integers" >&2
            return 1
        }
        return 0
    }
fi

# -------------------- [ VERIFY ENVIRONMENT ] --------------------
if [[ -z "${ISO_DIR:-}" ]]; then
    echo "ERROR: ISO_DIR not loaded. Common variables missing." >&2
    exit 1
fi

# -------------------- [ ROCKY CONFIGURATION ] --------------------
readonly ROCKY_ISO_URL="https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.7-x86_64-minimal.iso"
readonly ROCKY_ISO_PATH="$ISO_DIR/Rocky-9.7-x86_64-minimal.iso"
readonly ROCKY_OS_VARIANT="rocky9"
readonly ROCKY_BOOT_DIR="$BOOT_DIR/rocky9"

# -------------------- [ ROCKY KICKSTART GENERATOR ] --------------------
generate_rocky_kickstart() {
    local ks_file="$1"
    local vm_name="$2"
    local vm_user="$3"
    local user_pass_hash="$4"
    local root_pass_hash="$5"
    local timezone="$6"

    log_info "Generating Rocky Linux 9.6 kickstart file..."

    local template_file="$PROJECT_ROOT/src/templates/rocky-ks.cfg.template"
    if [[ ! -f "$template_file" ]]; then
        log_error "Template not found: $template_file"
        return 1
    fi

    cp "$template_file" "$ks_file" || {
        log_error "Failed to copy kickstart template"
        return 1
    }

    local safe_hostname=$(escape_sed_pattern "$vm_name")
    local safe_username=$(escape_sed_pattern "$vm_user")
    local safe_user_hash=$(escape_sed_pattern "$user_pass_hash")
    local safe_root_hash=$(escape_sed_pattern "$root_pass_hash")
    local safe_timezone=$(escape_sed_pattern "$timezone")

    sed -i "s/{{HOSTNAME}}/$safe_hostname/g" "$ks_file"
    sed -i "s/{{USERNAME}}/$safe_username/g" "$ks_file"
    sed -i "s/{{USER_PASSWORD_HASH}}/$safe_user_hash/g" "$ks_file"
    sed -i "s/{{ROOT_PASSWORD_HASH}}/$safe_root_hash/g" "$ks_file"
    sed -i "s/{{TIMEZONE}}/$safe_timezone/g" "$ks_file"

    log_success "Kickstart file generated: $ks_file"
    return 0
}

# -------------------- [ ROCKY VM CREATION ] --------------------
create_rocky_vm() {
    local vm_name="$1"
    local ram="$2"
    local vcpus="$3"
    local disk="$4"
    local timezone="$5"
    local user_pass="$6"
    local root_pass="$7"

    log_info "Starting Rocky Linux 9.6 VM creation: $vm_name"

    # Validate parameters
    if ! validate_vm_parameters "$vm_name" "$ram" "$vcpus" "$disk" "$timezone"; then
        log_error "VM parameter validation failed"
        return 1
    fi

    # Check VM existence
    if ! check_vm_exists "$vm_name"; then
        return 1
    fi

    local disk_path="$IMAGE_DIR/$vm_name.qcow2"
    if ! check_disk_exists "$disk_path"; then
        return 1
    fi

    # Generate password hashes
    log_info "Generating password hashes..."
    local user_pass_hash=$(generate_password_hash "$user_pass")
    local root_pass_hash=$(generate_password_hash "$root_pass")

    [[ -z "$user_pass_hash" || -z "$root_pass_hash" ]] && {
        log_error "Password hash generation failed"
        return 1
    }

    # Validate hash format
    validate_password_hash "$user_pass_hash" "User password hash" || return 1
    validate_password_hash "$root_pass_hash" "Root password hash" || return 1

    # Download ISO
    if ! download_iso "$ROCKY_ISO_URL" "$ROCKY_ISO_PATH" "$ROCKY_OS_VARIANT"; then
        log_error "Failed to download or prepare ISO"
        return 1
    fi

    # Setup network & firewall
    setup_network || { log_error "Network setup failed"; return 1; }
    configure_firewall

    # Detect host IP
    HOST_IP=$(detect_host_ip)
    [[ -z "$HOST_IP" ]] && { log_error "Failed to detect host IP"; return 1; }
    log_success "Detected host IP: $HOST_IP"

    # Generate kickstart
    local ks_file="$IMAGE_DIR/ks_$vm_name.cfg"
    generate_rocky_kickstart "$ks_file" "$vm_name" "ops" "$user_pass_hash" "$root_pass_hash" "$timezone"

    # Start HTTP kickstart server
    start_ks_server "$IMAGE_DIR" || {
        log_error "Failed to start kickstart server"
        return 1
    }

    # Create disk
    log_info "Creating disk: $disk_path (${disk}GB)"
    qemu-img create -f qcow2 "$disk_path" "${disk}G" || {
        log_error "Failed to create disk image"
        return 1
    }

    # Install Rocky VM
    log_info "Launching virt-install for Rocky Linux 9.6"
    log_cyan "----------------------------------------------"
    log_cyan "VM Name : $vm_name"
    log_cyan "RAM     : ${ram}MB"
    log_cyan "vCPUs   : $vcpus"
    log_cyan "Disk    : ${disk}GB"
    log_cyan "Timezone: $timezone"
    log_cyan "----------------------------------------------"

    if ! virt-install \
        --name "$vm_name" \
        --memory "$ram" \
        --vcpus "$vcpus" \
        --disk "path=$disk_path,format=qcow2" \
        --network network=default \
        --os-variant "$ROCKY_OS_VARIANT" \
        --location "$ROCKY_ISO_PATH" \
        --extra-args "inst.ks=http://$HOST_IP:$HTTP_PORT/ks_$vm_name.cfg console=ttyS0,115200n8 inst.text inst.repo=cdrom" \
        --graphics none \
        --console pty,target_type=serial \
        --noautoconsole \
        --wait -1; then
        log_error "virt-install failed for $vm_name"
        return 1
    fi

    # Monitor installation
    if monitor_installation "$vm_name"; then
        log_success "Rocky Linux 9.6 VM '$vm_name' created successfully!"
        log_cyan "Access:"
        log_cyan "   virsh console $vm_name"
        log_cyan "   ssh ops@<vm-ip>"
        rm -f "$ks_file"
        return 0
    else
        log_error "Rocky installation failed for $vm_name"
        log_warn "Kickstart file retained: $ks_file"
        return 1
    fi
}

# -------------------- [ MAIN FUNCTION ] --------------------
main() {
    local vm_name="$1"
    local ram="$2"
    local vcpus="$3"
    local disk="$4"
    local timezone="$5"
    local user_pass="$6"
    local root_pass="$7"

    if [[ -z "${ISO_DIR:-}" ]]; then
        log_error "Common environment variables missing"
        return 1
    fi

    CLEANUP_ALLOWED=true
    trap 'handle_error $LINENO' ERR
    trap 'handle_interrupt' INT TERM
    trap cleanup EXIT

    log_info "🚀 Starting Rocky Linux 9.6 VM creation..."
    log_cyan "=============================================="

    if create_rocky_vm "$vm_name" "$ram" "$vcpus" "$disk" "$timezone" "$user_pass" "$root_pass"; then
        log_success "🎉 Rocky Linux 9.6 VM installation completed!"
        return 0
    else
        log_error "💥 Rocky Linux VM creation failed!"
        return 1
    fi
}

# -------------------- [ ENTRY POINT ] --------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -ne 7 ]]; then
        echo "Usage: $0 <vm_name> <ram_mb> <vcpus> <disk_gb> <timezone> <user_pass> <root_pass>"
        echo "Example: $0 my-rocky-vm 3072 2 40 Africa/Cairo myuserpass myrootpass"
        exit 1
    fi
    main "$@"
fi
