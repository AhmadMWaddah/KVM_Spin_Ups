# 📦 KVM_Spin_Ups – DevOps Installation Guide

## 🖥️ System Requirements

### Minimum Requirements (Development/Testing)
- **OS:** Ubuntu 20.04+, CentOS 8+, RHEL 8+, Rocky Linux 8+, AlmaLinux 8+
- **RAM:** 8GB minimum (16GB recommended for multi-VM environments)
- **Storage:** 50GB free space minimum (100GB+ for multiple VMs)
- **CPU:** 64-bit processor with virtualization support (VT-x/AMD-V)
- **Network:** Internet connection for ISO downloads

### Production-Ready Requirements (Recommended)
- **RAM:** 16GB+ for multiple VMs or resource-intensive applications
- **Storage:** 200GB+ SSD for optimal performance
- **CPU:** 4+ cores with hardware virtualization enabled
- **Network:** Stable internet connection for initial ISO downloads

---

## 📥 Step 1: Install Virtualization Dependencies

### Ubuntu/Debian Systems
```bash
# Update package lists
sudo apt update

# Install KVM virtualization stack
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients virtinst bridge-utils curl python3

# Enable and start libvirtd service
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

### CentOS/RHEL/Rocky/AlmaLinux Systems
```bash
# Enable virtualization group packages
sudo dnf install -y @virtualization virt-install libvirt curl python3

# Enable and start libvirtd service
sudo systemctl enable libvirtd
sudo systemctl start libvirtd
```

### Verify Virtualization Support
```bash
# Check if virtualization extensions are available
egrep -c '(vmx|svm)' /proc/cpuinfo

# Should return 1 or more; if 0, enable VT-x/AMD-V in BIOS
```

---

## 👤 Step 2: Configure User Permissions (Critical for DevOps Workflow)

Add your user to required groups for seamless VM management:

```bash
# Add user to libvirt and kvm groups
sudo usermod -a -G libvirt,kvm $USER

# Apply changes immediately (or log out and back in)
newgrp libvirt

# Verify group membership
groups $USER | grep -E "(libvirt|kvm)"
```

### Verify Permissions
```bash
# Test libvirt access
virsh list --all

# Should return without permission errors
```

---

## 📦 Step 3: Clone and Prepare KVM_Spin_Ups

### Clone the Repository
```bash
git clone https://github.com/your-username/KVM_Spin_Ups.git
cd KVM_Spin_Ups
```

### Set Proper Permissions
```bash
# Make the main script executable
chmod +x src/KVM_Spin_Ups.sh
```

---

## 🚀 Step 4: Initial Configuration and First Run

### Make the Launcher Executable and Run
```bash
# Navigate to project directory
cd KVM_Spin_Ups

# Make launcher executable
chmod +x src/KVM_Spin_Ups.sh

# Run the interactive launcher
bash src/KVM_Spin_Ups.sh
```

### What Happens During First Run
The script performs these DevOps-ready operations:
- ✅ **System validation** - Checks dependencies and virtualization support
- ✅ **Directory preparation** - Creates necessary project structure
- ✅ **ISO management** - Downloads required distribution ISOs (one-time)
- ✅ **Network setup** - Configures NAT network with DHCP
- ✅ **Firewall configuration** - Opens HTTP port 8080 for kickstart delivery
- ✅ **Interactive VM configuration** - Collects VM specifications
- ✅ **Automated provisioning** - Creates and installs VMs with kickstart

---

## 📁 Project Structure & DevOps Integration

```
KVM_Spin_Ups/
├── README.md                    # Project overview
├── LICENSE                      # MIT License
├── INSTALLATION_Guide.md        # This guide
├── Debugging.md                # Troubleshooting reference
├── src/                        # Source code
│   ├── KVM_Spin_Ups.sh         # Main orchestration script
│   ├── common-functions.sh     # Shared utilities and helpers
│   ├── validation-functions.sh # Input validation and system checks
│   ├── distros-installers/     # Distribution-specific installers
│   │   ├── rocky-linux-installers.sh
│   │   └── alma-linux-installers.sh
│   └── templates/              # Kickstart configuration templates
│       ├── rocky-ks.cfg.template
│       └── alma-ks.cfg.template
├── docs/                       # Documentation
│   └── architecture.md
├── examples/                   # Usage examples and scenarios
│   └── basic-usage.md
├── iso/                        # Downloaded ISO images (managed automatically)
├── mounts/                     # ISO mount points for boot files
└── vms/                        # VM disk images and configurations
```

---

## 🌐 Network Configuration for DevOps Workflows

### Default Network Setup
KVM_Spin_Ups automatically configures:

- **Network Type:** NAT with DHCP (192.168.122.0/24)
- **DHCP Range:** 192.168.122.2 - 192.168.122.254
- **Gateway:** 192.168.122.1
- **DNS:** Provided by libvirt
- **HTTP Server:** Port 8080 (for kickstart delivery)

### Network Management Commands
```bash
# Check network status
virsh net-list --all

# Get DHCP lease information
virsh net-dhcp-leases default

# Check network details
virsh net-info default
```

---

## 🎯 DevOps VM Creation Workflow

### Interactive Process (Optimized for DevOps)

1. **Environment Planning**
   - **VM Count:** 1-10 VMs in a single batch operation
   - **Distribution Selection:** Choose from supported enterprise distributions

2. **Per-VM Configuration Parameters**
   - **Hostname:** Unique identifier (e.g., `web01-prod`, `db01-staging`)
   - **Resources:** RAM (1024-16384 MB), vCPUs (1-16), Disk (10-500 GB)
   - **Timezone:** Any valid timezone (default: Africa/Cairo)
   - **Security:** User and root passwords with minimum 8-character requirement

3. **Batch Validation**
   - **Summary Review:** Comprehensive overview of all VM configurations
   - **Confirmation:** Explicit approval before installation begins

4. **Automated Installation**
   - **Sequential Provisioning:** All VMs install in order with monitoring
   - **Progress Tracking:** Real-time installation status
   - **Result Reporting:** Success/failure summary for each VM

### Example DevOps VM Configuration
```yaml
Environment: Development
VM Count: 3
VM #1 - Web Server:
  Distribution: Rocky Linux 9.7
  Hostname: web-dev-01
  RAM: 2048 MB
  vCPUs: 2
  Disk: 30 GB
  Timezone: UTC
  Purpose: Web application testing

VM #2 - Database Server:
  Distribution: AlmaLinux 10.1
  Hostname: db-dev-01
  RAM: 4096 MB
  vCPUs: 2
  Disk: 50 GB
  Timezone: UTC
  Purpose: Database testing

VM #3 - Application Server:
  Distribution: Rocky Linux 9.7
  Hostname: app-dev-01
  RAM: 3072 MB
  vCPUs: 2
  Disk: 40 GB
  Timezone: UTC
  Purpose: Application logic testing
```

---

## 🔌 Post-Installation DevOps Access Patterns

### VM Management Commands
```bash
# List all VMs (active and inactive)
virsh list --all

# Start/Stop/Restart VMs
virsh start vm-name
virsh shutdown vm-name
virsh destroy vm-name  # Force stop

# Get VM status
virsh domstate vm-name

# Get VM IP address
virsh net-dhcp-leases default

# Get VM details
virsh dominfo vm-name
```

### Access Methods
```bash
# Console access (interactive)
virsh console vm-name

# SSH access (automation-friendly)
ssh ops@vm-ip-address

# Execute commands remotely
ssh ops@vm-ip-address 'sudo systemctl status httpd'
```

### DevOps Automation Examples
```bash
# Wait for VM to be accessible
wait_for_vm() {
  local vm_ip=$1
  until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ops@"$vm_ip" 'true' 2>/dev/null; do
    sleep 5
    echo "Waiting for VM at $vm_ip to be accessible..."
  done
  echo "VM at $vm_ip is ready"
}

# Deploy configuration after VM creation
deploy_config() {
  local vm_ip=$1
  ssh ops@"$vm_ip" 'sudo yum install -y ansible'
  scp playbook.yml ops@"$vm_ip":~/
  ssh ops@"$vm_ip" 'ansible-playbook playbook.yml'
}
```

---

## 🔧 DevOps Troubleshooting Guide

### Common Issues and Solutions

#### 1. Permission Denied for Libvirt Operations
```bash
# Check group membership
groups $USER | grep -E "(libvirt|kvm)"

# If groups are missing, add user and reload
sudo usermod -a -G libvirt,kvm $USER
newgrp libvirt

# Verify permissions work
virsh list --all
```

#### 2. Virtualization Not Available or Disabled
```bash
# Check CPU virtualization support
egrep -c '(vmx|svm)' /proc/cpuinfo  # Should return > 0

# If 0, enable VT-x/AMD-V in BIOS settings

# Load KVM modules if not loaded
sudo modprobe kvm
sudo modprobe kvm_intel  # For Intel CPUs
# OR
sudo modprobe kvm_amd    # For AMD CPUs

# Check if modules are loaded
lsmod | grep kvm
```

#### 3. ISO Download Failures
```bash
# Check internet connectivity
curl -I https://download.rockylinux.org/pub/rocky/9/isos/x86_64/

# Check firewall settings
sudo ufw status  # Ubuntu
sudo firewall-cmd --list-all  # RHEL/CentOS

# Manual download if needed
wget -O /path/to/iso/directory/iso-name.iso [ISO_URL]
```

#### 4. VM Network Issues
```bash
# Check network status
virsh net-list --all

# Restart default network if needed
sudo virsh net-destroy default
sudo virsh net-start default

# Check DHCP leases
virsh net-dhcp-leases default

# Check VM network interface
virsh domiflist vm-name
```

#### 5. VM Installation Stuck or Failing
```bash
# Check VM state
virsh domstate vm-name

# Access console for debugging
virsh console vm-name

# Check VM logs
sudo journalctl -u libvirtd -f

# Get detailed VM configuration
virsh dumpxml vm-name | grep -A5 -B5 "serial\|interface"

# Force stop if VM is unresponsive
virsh destroy vm-name
```

#### 6. HTTP Server Issues (Kickstart Delivery)
```bash
# Check if HTTP server is running
sudo netstat -tlnp | grep :8080

# Check firewall for port 8080
sudo ufw status | grep 8080  # Ubuntu
sudo firewall-cmd --list-ports  # RHEL/CentOS

# Test HTTP server manually
curl http://localhost:8080/
```

---

## 🔥 Firewall Configuration for DevOps Security

### Automatic Configuration
The script automatically configures firewall rules:

- **Port 8080:** HTTP server for kickstart file delivery
- **SSH (22):** Enabled in VM firewall for remote access
- **Supported firewalls:** firewalld (RHEL/CentOS) and ufw (Ubuntu)

### Manual Firewall Management
```bash
# Ubuntu/Debian (ufw)
sudo ufw allow 8080/tcp
sudo ufw reload

# RHEL/CentOS (firewalld)
sudo firewall-cmd --permanent --add-port=8080/tcp
sudo firewall-cmd --reload
```

---

## 🔒 Security Best Practices for DevOps Environments

### Default Security Configuration
- ✅ **Root login disabled** via SSH for all VMs
- ✅ **User 'ops' with passwordless sudo** for administrative tasks
- ✅ **Firewall enabled** with SSH access allowed
- ✅ **SELinux enforcing** (on supported distributions)
- ✅ **Encrypted password hashes** using SHA-512

### DevOps Security Recommendations
```bash
# Generate strong passwords programmatically
generate_password() {
  openssl rand -base64 16
}

# Use SSH keys instead of passwords for automation
ssh-keygen -t rsa -b 4096 -C "devops@company.com"

# Configure SSH key access after VM creation
ssh-copy-id ops@vm-ip-address
```

---

## 🚀 DevOps Integration Examples

### CI/CD Pipeline Integration
```bash
#!/bin/bash
# ci-cd-example.sh

# Create test environment
bash src/KVM_Spin_Ups.sh << EOF
1
1
test-vm
2048
2
20
UTC
SecurePass123!
SecureRoot123!
y
EOF

# Wait for VM to be ready
VM_IP=$(virsh net-dhcp-leases default | grep test-vm | awk '{print $5}' | cut -d'/' -f1)
while ! ssh -o ConnectTimeout=5 ops@$VM_IP 'true' 2>/dev/null; do
  sleep 10
  echo "Waiting for VM to be ready..."
done

# Deploy and test application
scp application.tar.gz ops@$VM_IP:~/
ssh ops@$VM_IP 'tar -xzf application.tar.gz && ./test-script.sh'

# Cleanup
virsh destroy test-vm
virsh undefine test-vm
```

### Infrastructure as Code Pattern
```bash
#!/bin/bash
# infrastructure-as-code.sh

# Define infrastructure requirements
declare -A VM_SPECS=(
  ["web-server"]="Rocky Linux 9.7|2048|2|30|UTC"
  ["db-server"]="AlmaLinux 10.1|4096|2|50|UTC"
  ["app-server"]="Rocky Linux 9.7|3072|2|40|UTC"
)

# Provision infrastructure
for vm_name in "${!VM_SPECS[@]}"; do
  IFS='|' read -r distro ram vcpus disk tz <<< "${VM_SPECS[$vm_name]}"
  echo "Provisioning $vm_name with $distro..."
  # Use API or automation to create VM
done
```

---

## 💬 Getting DevOps Support

### Community Support Channels
- **GitHub Issues:** Report bugs and feature requests
- **Documentation:** Check README.md and this guide first
- **Contributions:** Submit pull requests for improvements

### Information to Include in Support Requests
- **System details:** OS version, virtualization support status
- **Error messages:** Full error output with timestamps
- **Steps to reproduce:** Clear sequence of actions leading to issue
- **Expected vs actual behavior:** What you expected vs what happened

---

## 🎉 Ready for DevOps Excellence!

You're now ready to leverage KVM_Spin_Ups for your DevOps workflows. The tool provides:

- **Rapid environment provisioning** for testing and development
- **Production-like environments** using enterprise distributions
- **Infrastructure as Code** principles with declarative configuration
- **Complete automation** from ISO download to VM ready state

Start creating your first DevOps-ready VM environment and experience the power of local infrastructure automation!

---

*Made with ❤️ by the open-source community for DevOps engineers worldwide*