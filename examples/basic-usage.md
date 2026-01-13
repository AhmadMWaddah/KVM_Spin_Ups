# KVM_Spin_Ups - DevOps Usage Examples

## 🚀 Quick Start Examples

### Single VM Creation (Development Environment)

```bash
# Make the launcher executable
chmod +x src/KVM_Spin_Ups.sh

# Run the interactive launcher
bash src/KVM_Spin_Ups.sh
```

**Sample Development VM Configuration:**
```yaml
VM Count: 1
VM #1:
  Distribution: Rocky Linux 9.7
  Hostname: dev-web-01
  RAM: 2048 MB
  vCPUs: 2
  Disk: 30 GB
  Timezone: UTC
  User: ops
  Purpose: Web application development and testing
```

---

## 🏗️ Multi-VM Environment Creation (DevOps Scenario)

### Example: 3-Tier Application Environment

**Scenario:** Create a complete application stack for testing

```yaml
Environment: Development/Test
VM Count: 3

VM #1 - Web Server:
  Distribution: Rocky Linux 9.7
  Hostname: web-dev-01
  RAM: 2048 MB
  vCPUs: 2
  Disk: 30 GB
  Timezone: UTC
  Purpose: Frontend web server

VM #2 - Application Server:
  Distribution: AlmaLinux 10.1
  Hostname: app-dev-01
  RAM: 3072 MB
  vCPUs: 2
  Disk: 40 GB
  Timezone: UTC
  Purpose: Application logic server

VM #3 - Database Server:
  Distribution: Rocky Linux 9.7
  Hostname: db-dev-01
  RAM: 4096 MB
  vCPUs: 2
  Disk: 50 GB
  Timezone: UTC
  Purpose: Database server
```

### Interactive Session Flow:
```bash
How many VMs do you want to create? (1-10): 3

# VM #1 Configuration
📦 Available Distributions:
  1) Rocky Linux 9.7
  2) AlmaLinux 10.1
Select distribution (1-2): 1

🎯 Configuring VM #1 - Rocky Linux 9.7
VM Hostname: web-dev-01
RAM in MB (default 2048): 2048
vCPUs (default 2): 2
Disk size in GB (default 30): 30
Timezone (default Africa/Cairo): UTC

🔐 Password Configuration
User password (min 8 chars): MySecurePass123!
Root password (min 8 chars): MySecureRoot123!

# VM #2 Configuration
📦 Available Distributions:
  1) Rocky Linux 9.7
  2) AlmaLinux 10.1
Select distribution (1-2): 2

🎯 Configuring VM #2 - AlmaLinux 10.1
VM Hostname: app-dev-01
RAM in MB (default 2048): 3072
vCPUs (default 2): 2
Disk size in GB (default 30): 40
Timezone (default Africa/Cairo): UTC

🔐 Password Configuration
User password (min 8 chars): MySecurePass123!
Root password (min 8 chars): MySecureRoot123!

# VM #3 Configuration
📦 Available Distributions:
  1) Rocky Linux 9.7
  2) AlmaLinux 10.1
Select distribution (1-2): 1

🎯 Configuring VM #3 - Rocky Linux 9.7
VM Hostname: db-dev-01
RAM in MB (default 2048): 4096
vCPUs (default 2): 2
Disk size in GB (default 30): 50
Timezone (default Africa/Cairo): UTC

🔐 Password Configuration
User password (min 8 chars): MySecurePass123!
Root password (min 8 chars): MySecureRoot123!

# Batch Summary
🎯 Batch Installation Summary
  • Total VMs to create: 3
  • VM #1: web-dev-01 (Rocky Linux 9.7) - 2048MB RAM, 2 vCPUs, 30GB Disk
  • VM #2: app-dev-01 (AlmaLinux 10.1) - 3072MB RAM, 2 vCPUs, 40GB Disk
  • VM #3: db-dev-01 (Rocky Linux 9.7) - 4096MB RAM, 2 vCPUs, 50GB Disk
```

---

## 🛠️ Post-Creation DevOps Tasks

### Access and Manage VMs

```bash
# Get VM IP addresses
virsh net-dhcp-leases default

# Example output:
# Expiry Time          MAC address        Protocol  IP address                Hostname        Client ID or DUID
# 2024-01-13 15:30:45  52:54:00:12:34:56  ipv4      192.168.122.100/24      web-dev-01      -
# 2024-01-13 15:30:45  52:54:00:12:34:57  ipv4      192.168.122.101/24      app-dev-01      -
# 2024-01-13 15:30:45  52:54:00:12:34:58  ipv4      192.168.122.102/24      db-dev-01       -

# SSH to VMs
ssh ops@192.168.122.100  # web-dev-01
ssh ops@192.168.122.101  # app-dev-01
ssh ops@192.168.122.102  # db-dev-01

# Console access (if needed)
virsh console web-dev-01
```

### DevOps Automation Examples

```bash
#!/bin/bash
# deploy-application.sh - Example automation script

# Wait for all VMs to be accessible
wait_for_vms() {
  local ips=("$@")
  for ip in "${ips[@]}"; do
    echo "Waiting for $ip to be accessible..."
    until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no ops@"$ip" 'true' 2>/dev/null; do
      sleep 10
      echo "Still waiting for $ip..."
    done
    echo "VM at $ip is ready"
  done
}

# Deploy application stack
deploy_stack() {
  local web_ip=$1
  local app_ip=$2
  local db_ip=$3

  # Deploy web server
  ssh ops@"$web_ip" 'sudo yum install -y nginx && sudo systemctl start nginx && sudo systemctl enable nginx'

  # Deploy application server
  ssh ops@"$app_ip" 'sudo yum install -y python3-pip && pip3 install flask'

  # Deploy database
  ssh ops@"$db_ip" 'sudo yum install -y mariadb-server && sudo systemctl start mariadb && sudo systemctl enable mariadb'

  echo "Application stack deployed successfully!"
}

# Get IPs from libvirt
WEB_IP=$(virsh net-dhcp-leases default | grep web-dev-01 | awk '{print $5}' | cut -d'/' -f1)
APP_IP=$(virsh net-dhcp-leases default | grep app-dev-01 | awk '{print $5}' | cut -d'/' -f1)
DB_IP=$(virsh net-dhcp-leases default | grep db-dev-01 | awk '{print $5}' | cut -d'/' -f1)

# Execute deployment
wait_for_vms "$WEB_IP" "$APP_IP" "$DB_IP"
deploy_stack "$WEB_IP" "$APP_IP" "$DB_IP"
```

---

## 🧪 CI/CD Pipeline Integration Example

### Jenkins/GitLab CI Pipeline

```groovy
// Jenkinsfile example
pipeline {
    agent any

    stages {
        stage('Setup Test Environment') {
            steps {
                sh '''
                    # Clone KVM_Spin_Ups
                    git clone https://github.com/your-org/KVM_Spin_Ups.git
                    cd KVM_Spin_Ups

                    # Make executable and run with predefined answers
                    chmod +x src/KVM_Spin_Ups.sh
                    # Use expect or similar to automate interactive prompts
                    bash src/KVM_Spin_Ups.sh << EOF
                    1
                    1
                    test-app-01
                    2048
                    2
                    30
                    UTC
                    MySecurePass123!
                    MySecureRoot123!
                    y
                    EOF
                '''
            }
        }

        stage('Deploy Application') {
            steps {
                sh '''
                    # Get VM IP
                    TEST_VM_IP=$(virsh net-dhcp-leases default | grep test-app-01 | awk '{print $5}' | cut -d'/' -f1)

                    # Wait for VM to be ready
                    while ! ssh -o ConnectTimeout=5 ops@$TEST_VM_IP 'true' 2>/dev/null; do
                        sleep 10
                    done

                    # Deploy application
                    scp application.tar.gz ops@$TEST_VM_IP:~/
                    ssh ops@$TEST_VM_IP 'tar -xzf application.tar.gz && ./install.sh'
                '''
            }
        }

        stage('Run Tests') {
            steps {
                sh '''
                    TEST_VM_IP=$(virsh net-dhcp-leases default | grep test-app-01 | awk '{print $5}' | cut -d'/' -f1)
                    ssh ops@$TEST_VM_IP 'cd /opt/application && ./run-tests.sh'
                '''
            }
        }
    }

    post {
        always {
            sh '''
                # Cleanup - destroy test VM
                virsh destroy test-app-01 || true
                virsh undefine test-app-01 || true
            '''
        }
    }
}
```

---

## 📊 Resource Planning Examples

### Memory Requirements Calculation
```bash
# Formula: Total RAM = Base System + (VM RAM × Number of VMs) + Overhead
# Example: 4GB base + (2GB × 3 VMs) + 2GB overhead = 12GB minimum

# For 5 VMs with 4GB each:
# Base: 4GB
# VMs: 5 × 4GB = 20GB
# Overhead: 4GB
# Total: 28GB recommended
```

### Storage Requirements Calculation
```bash
# Formula: Total Storage = ISO Cache + (VM Disk × Number of VMs) + Logs
# Example: 10GB ISOs + (30GB × 3 VMs) + 5GB logs = 105GB minimum

# For 5 VMs with 50GB disks each:
# ISOs: 10GB
# VMs: 5 × 50GB = 250GB
# Logs: 10GB
# Total: 270GB recommended
```

---

## 🔧 Troubleshooting Quick Reference

### Common DevOps Scenarios

#### VM Not Accessible After Creation
```bash
# Check VM state
virsh domstate vm-name

# Check network leases
virsh net-dhcp-leases default

# Access via console
virsh console vm-name
```

#### Insufficient Resources
```bash
# Check available memory
free -h

# Check disk space
df -h

# Adjust VM configuration to fit available resources
```

#### Network Issues
```bash
# Check network status
virsh net-list --all

# Restart network if needed
virsh net-destroy default
virsh net-start default
```

---

## 🚀 Advanced Usage Patterns

### Automated VM Creation Script
```bash
#!/bin/bash
# automated-vm-creation.sh

# Configuration file approach
CONFIG_FILE="vm-config.yaml"

# Function to parse configuration and create VMs
create_vms_from_config() {
  local config_file=$1

  # This would parse the YAML and create VMs accordingly
  # Implementation depends on available YAML parser (jq, yq, etc.)
  echo "Creating VMs from configuration: $config_file"
}

# Example usage
create_vms_from_config "$CONFIG_FILE"
```

### Infrastructure as Code Pattern
```bash
#!/bin/bash
# infrastructure-definition.sh

# Define infrastructure requirements
declare -A INFRASTRUCTURE=(
  ["web-servers"]="rocky|2|2048|30|UTC"
  ["app-servers"]="alma|2|3072|40|UTC"
  ["db-servers"]="rocky|2|4096|50|UTC"
)

# Provision infrastructure based on definition
for tier in "${!INFRASTRUCTURE[@]}"; do
  IFS='|' read -r distro count ram disk tz <<< "${INFRASTRUCTURE[$tier]}"
  echo "Provisioning $count $tier with $distro..."
  # Logic to create VMs based on definition
done
```

---

## 📋 Supported Distributions

| Distribution | Version | Use Case | Enterprise Ready |
|--------------|---------|----------|------------------|
| **Rocky Linux** | 9.7 | Production-like EL | ✅ Yes |
| **AlmaLinux** | 10.1 | Latest EL features | ✅ Yes |

Both distributions are ideal for DevOps workflows, offering enterprise stability and compatibility with production environments.

---

*These examples demonstrate how KVM_Spin_Ups integrates seamlessly into DevOps workflows, from simple development environments to complex CI/CD pipelines.*