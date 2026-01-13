#!/bin/bash

###############################################################################
# KVM_Spin_Ups – Main Launcher Script
# Orchestrates distribution-specific VM installations
# Licensed under MIT License
# © 2025 Ahmad M. Waddah and the KVM_Spin_Ups contributors
###############################################################################

set -Euo pipefail

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source dependencies using absolute paths
source "${SCRIPT_DIR}/common-functions.sh"
source "${SCRIPT_DIR}/validation-functions.sh"

# Distribution paths configurations
declare -A DISTRO_CONFIGS=(
    ["rocky"]="Rocky Linux 9.7|rocky-linux-installers.sh|rocky-ks.cfg.template"
    ["alma"]="AlmaLinux 10.1|alma-linux-installers.sh|alma-ks.cfg.template"
)

# Array to store all VM configurations
declare -a VM_CONFIGURATIONS=()

# === LAUNCHER FUNCTIONS ===
show_welcome() {
    clear
    echo -e "${MAGENTA}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║                   K V M _ S P I N _ U P S                     ║"
    echo "║           Automated Virtual Machine Creation System           ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}🎯 Purpose: Create multiple VMs in batch mode${NC}"
    echo ""
}

show_features_info() {
    echo -e "${GREEN}🌟  KVM_Spin_Ups - Open Source VM Creator  🌟${NC}"
    echo -e "${CYAN}   ✅ Free and open source${NC}"
    echo -e "${CYAN}   ✅ Rocky Linux + AlmaLinux support${NC}"
    echo -e "${CYAN}   ✅ Community support${NC}"
    echo -e "${CYAN}   ✅ Contributions welcome${NC}"
    echo ""
}

show_distro_menu() {
    echo -e "${BLUE}📦 Available Distributions:${NC}"
    echo ""

    local i=1
    for distro in "${!DISTRO_CONFIGS[@]}"; do
        IFS='|' read -r name script template <<< "${DISTRO_CONFIGS[$distro]}"
        local display_name="$name"

        echo -e "  ${GREEN}$i${NC}) $display_name"
        ((i++))
    done
    echo ""
}

get_distro_choice() {
    local choice
    local distros=(${!DISTRO_CONFIGS[@]})
    local distro_count=${#distros[@]}

    while true; do
        read -p "Select distribution (1-${distro_count}): " choice

        # Handle empty input
        if [[ -z "$choice" ]]; then
            log_error "Please enter a number"
            continue
        fi

        # Remove any whitespace
        choice=$(echo "$choice" | tr -d '[:space:]')

        # Check if it's a valid number
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && [ "$choice" -le "$distro_count" ]; then
            local index=$((choice - 1))
            local selected_distro="${distros[$index]}"

            echo "$selected_distro"
            return 0
        else
            log_error "Invalid choice: $choice. Please select 1-${distro_count}"
        fi
    done
}

get_vm_count() {
    while true; do
        read -p "How many VMs do you want to create? (1-10): " vm_count

        if [[ -z "$vm_count" ]]; then
            log_error "Please enter a number"
            continue
        fi

        if [[ "$vm_count" =~ ^[1-9][0-9]*$ ]] && [ "$vm_count" -ge 1 ] && [ "$vm_count" -le 10 ]; then
            echo "$vm_count"
            return 0
        else
            log_error "Invalid number. Please enter between 1 and 10"
        fi
    done
}

get_vm_parameters() {
    local vm_number="$1"
    local distro_name="$2"
    
    {
        echo -e "\n${CYAN}🎯 Configuring VM #$vm_number - $distro_name${NC}"
        echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    } > /dev/tty
    
    # Hostname
    local vm_name=""
    while true; do
        read -p "VM Hostname: " vm_name
        if validate_hostname "$vm_name"; then
            break
        fi
    done
    
    # RAM
    local ram=""
    while true; do
        read -p "RAM in MB (default 2048): " input_ram
        ram="${input_ram:-2048}"
        if validate_number_range "$ram" 1024 16384 "RAM"; then
            break
        fi
    done
    
    # vCPUs
    local vcpus=""
    while true; do
        read -p "vCPUs (default 2): " input_vcpus
        vcpus="${input_vcpus:-2}"
        if validate_number_range "$vcpus" 1 16 "vCPUs"; then
            break
        fi
    done
    
    # Disk
    local disk=""
    while true; do
        read -p "Disk size in GB (default 30): " input_disk
        disk="${input_disk:-30}"
        if validate_number_range "$disk" 10 500 "Disk size"; then
            break
        fi
    done
    
    # Timezone
    local timezone=""
    while true; do
        read -p "Timezone (default Africa/Cairo): " input_timezone
        timezone="${input_timezone:-Africa/Cairo}"
        if validate_timezone "$timezone"; then
            break
        fi
    done
    
    # Passwords
    {
        echo -e "\n${YELLOW}🔐 Password Configuration${NC}"
    } > /dev/tty
    
    local user_pass=""
    while true; do
        user_pass=$(read_password "User password (min 8 chars): ")
        if validate_password "$user_pass" "User password"; then
            break
        fi
    done
    
    local root_pass=""
    while true; do
        root_pass=$(read_password "Root password (min 8 chars): ")
        if validate_password "$root_pass" "Root password"; then
            break
        fi
    done
    
    # Return ONLY the parameter string - no other output!
    printf "%s|%s|%s|%s|%s|%s|%s" "$vm_name" "$ram" "$vcpus" "$disk" "$timezone" "$user_pass" "$root_pass"
}

show_vm_summary() {
    local vm_number="$1"
    local distro_name="$2"
    local vm_name="$3"
    local ram="$4"
    local vcpus="$5"
    local disk="$6"
    local timezone="$7"
    
    echo -e "\n${GREEN}📋 VM #$vm_number Summary${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}•${NC} Distribution: ${GREEN}$distro_name${NC}"
    echo -e "  ${CYAN}•${NC} Hostname: ${GREEN}$vm_name${NC}"
    echo -e "  ${CYAN}•${NC} RAM: ${GREEN}${ram}MB${NC}"
    echo -e "  ${CYAN}•${NC} vCPUs: ${GREEN}$vcpus${NC}"
    echo -e "  ${CYAN}•${NC} Disk: ${GREEN}${disk}GB${NC}"
    echo -e "  ${CYAN}•${NC} Timezone: ${GREEN}$timezone${NC}"
    echo -e "  ${CYAN}•${NC} Username: ${GREEN}ops${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
}

show_batch_summary() {
    echo -e "\n${GREEN}🎯 Batch Installation Summary${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}•${NC} Total VMs to create: ${GREEN}${#VM_CONFIGURATIONS[@]}${NC}"
    
    local i=1
    for config in "${VM_CONFIGURATIONS[@]}"; do
        IFS='|' read -r distro vm_name ram vcpus disk timezone user_pass root_pass <<< "$config"
        IFS='|' read -r distro_name installer template <<< "${DISTRO_CONFIGS[$distro]}"
        echo -e "  ${CYAN}•${NC} VM #$i: ${GREEN}$vm_name${NC} (${distro_name}) - ${ram}MB RAM, ${vcpus} vCPUs, ${disk}GB Disk"
        ((i++))
    done
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
}

launch_distro_installer() {
    local distro="$1"
    local vm_name="$2"
    local ram="$3"
    local vcpus="$4"
    local disk="$5"
    local timezone="$6"
    local user_pass="$7"
    local root_pass="$8"

    IFS='|' read -r distro_name installer_script template_path <<< "${DISTRO_CONFIGS[$distro]}"

    # Use absolute paths based on PROJECT_ROOT (source code location)
    local full_installer_path="$DISTROS_DIR/${installer_script}"
    local full_template_path="$TEMPLATE_DIR/${template_path}"

    if [[ ! -f "$full_installer_path" ]]; then
        log_error "Installer script not found: $full_installer_path"
        return 1
    fi

    if [[ ! -f "$full_template_path" ]]; then
        log_error "Template not found: $full_template_path"
        return 1
    fi

    # ISO is guaranteed to be downloaded already — no need to check again
    log_info "Launching $distro_name installer for $vm_name..."

    bash "$full_installer_path" "$vm_name" "$ram" "$vcpus" "$disk" "$timezone" "$user_pass" "$root_pass"

    return $?
}

collect_vm_configurations() {
    local vm_count="$1"
    
    log_info "Collecting configurations for $vm_count VMs..."
    
    # First pass: Collect all VM configs and determine which ISOs we need
    declare -A ISO_NEEDED=()  # Track unique ISOs needed
    
    for ((i=1; i<=vm_count; i++)); do
        echo -e "\n${CYAN}📝 Configuration for VM #$i${NC}"
        echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
        
        # Show distribution menu and get choice
        show_distro_menu
        local distro_choice=$(get_distro_choice)
        IFS='|' read -r distro_name installer template <<< "${DISTRO_CONFIGS[$distro_choice]}"
        
        # Get VM parameters
        local params
        params=$(get_vm_parameters "$i" "$distro_name")
        
        # Parse parameters
        local temp_file=$(mktemp)
        echo "$params" > "$temp_file"
        IFS='|' read -r vm_name ram vcpus disk timezone user_pass root_pass < "$temp_file"
        rm -f "$temp_file"
        
        # Show individual VM summary
        show_vm_summary "$i" "$distro_name" "$vm_name" "$ram" "$vcpus" "$disk" "$timezone"
        
        # Store configuration in array
        local config="${distro_choice}|${vm_name}|${ram}|${vcpus}|${disk}|${timezone}|${user_pass}|${root_pass}"
        VM_CONFIGURATIONS+=("$config")
        
        # Record which ISO we need (by distro choice)
        ISO_NEEDED["$distro_choice"]=1
    done
    
    # Second pass: Download ALL needed ISOs — one by one — before any installation
    log_info "Downloading all required ISOs before installation..."
    
    for distro in "${!ISO_NEEDED[@]}"; do
        case "$distro" in
            "rocky")
                iso_url="https://download.rockylinux.org/pub/rocky/9/isos/x86_64/Rocky-9.7-x86_64-minimal.iso"
                iso_path="$ISO_DIR/Rocky-9.7-x86_64-minimal.iso"
                iso_name="Rocky Linux 9.7"
                ;;
            "alma")
                iso_url="https://repo.almalinux.org/almalinux/10/isos/x86_64/AlmaLinux-10.1-x86_64-minimal.iso"
                iso_path="$ISO_DIR/AlmaLinux-10.1-x86_64-minimal.iso"
                iso_name="AlmaLinux 10.1"
                ;;
            *)
                log_error "Unsupported distribution: $distro"
                exit 1
                ;;
        esac
        
        if [[ -f "$iso_path" ]]; then
            log_info "ISO already exists: $iso_name"
        else
            log_warn "Downloading ISO: $iso_name"
            mkdir -p "$(dirname "$iso_path")"
            if ! curl -L -o "$iso_path" "$iso_url" --progress-bar; then
                log_error "Failed to download ISO: $iso_name"
                exit 1
            fi
            log_success "ISO downloaded: $iso_name"
        fi
    done
    
    log_success "✅ All ISOs downloaded. Starting VM installations..."
}

install_all_vms() {
    log_info "🚀 Starting batch installation of ${#VM_CONFIGURATIONS[@]} VMs..."
    
    local success_count=0
    local fail_count=0
    local total_vms=${#VM_CONFIGURATIONS[@]}
    
    for ((i=0; i<total_vms; i++)); do
        local config="${VM_CONFIGURATIONS[$i]}"
        IFS='|' read -r distro vm_name ram vcpus disk timezone user_pass root_pass <<< "$config"
        IFS='|' read -r distro_name installer template <<< "${DISTRO_CONFIGS[$distro]}"
        
        echo -e "\n${CYAN}🔧 Installing VM $((i+1))/$total_vms: $vm_name ($distro_name)${NC}"
        echo -e "${YELLOW}─────────────────────────────────────────────────────────────────${NC}"
        
        if launch_distro_installer "$distro" "$vm_name" "$ram" "$vcpus" "$disk" "$timezone" "$user_pass" "$root_pass"; then
            log_success "✅ VM $vm_name installed successfully"
            ((success_count++))
        else
            log_error "❌ VM $vm_name installation failed"
            ((fail_count++))
        fi
        
        # Small delay between installations
        if [ $i -lt $((total_vms - 1)) ]; then
            log_info "⏳ Preparing next VM..."
            sleep 5
        fi
    done
    
    # Final summary
    echo -e "\n${GREEN}🎊 Batch Installation Complete${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}•${NC} Total VMs: ${GREEN}$total_vms${NC}"
    echo -e "  ${CYAN}•${NC} Successful: ${GREEN}$success_count${NC}"
    echo -e "  ${CYAN}•${NC} Failed: ${RED}$fail_count${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    if [ $fail_count -eq 0 ]; then
        log_success "🎉 All VMs installed successfully!"
    else
        log_warn "⚠️  Some VMs failed to install. Check the logs above."
    fi
}

main() {
    # Initial setup
    show_welcome
    ensure_directories

    # System checks
    check_permissions
    check_dependencies
    check_system_requirements

    # Show features info
    show_features_info

    # Get number of VMs
    local vm_count=$(get_vm_count)

    # Collect all VM configurations
    collect_vm_configurations "$vm_count"

    # Show batch summary
    show_batch_summary

    # Final confirmation
    read -p "Proceed with batch installation? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        log_warn "Batch installation cancelled"
        exit 0
    fi

    # Install all VMs
    install_all_vms

    log_info "Thank you for using KVM_Spin_Ups - Open Source VM Creator!"
}

# Script entry point
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    CLEANUP_ALLOWED=true
    main "$@"
fi