#!/bin/bash

# Log file location
mkdir -p outputs/logs
LOG_FILE="outputs/logs/setup$(date +%Y%m%d_%H%M%S).log"

# Redirect stdout and stderr to the log file and the terminal
exec > >(tee -a "$LOG_FILE") 2>&1

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    local type=$1
    local message=$2
    case $type in
        "info")
            echo "  $message"
            ;;
        "success")
            echo -e "${GREEN}  $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}  $message${NC}"
            ;;
        "error")
            echo -e "${RED}  $message${NC}"
            ;;
    esac
}

# Function to check SSH keys
check_ssh_keys() {
    local ssh_key_dir="./ansible/inventory/ssh_keys"
    if [ ! -f "$ssh_key_dir/vsphere_ansible_key" ]; then
        print_status "warning" "SSH private key not found at $ssh_key_dir/vsphere_ansible_key"
        print_status "info" "Please copy your SSH private key to this location"
        return 1
    fi
    return 0
}

# Function to check bedrock world backup archive
check_bedrock_backup() {
    local backup_file="./ansible/inventory/files/bedrock-backup.gz"
    if [ ! -f "$backup_file" ]; then
        print_status "warning" "bedrock-backup.gz not found at $backup_file"
        print_status "info" "Place your Minecraft world backup archive at: $backup_file"
        print_status "info" "Expected archive structure: worlds/<WorldName>/ at the root"
        print_status "info" "Without it, Bedrock will generate fresh worlds on first start"
        return 1
    fi
    return 0
}

# Function to check SSH public keys
check_ssh_pub_keys() {
    local ssh_key_dir="./ansible/inventory/ssh_keys"
    if [ ! -f "$ssh_key_dir/vsphere_terraform_key.pub" ]; then
        print_status "warning" "SSH public key not found at $ssh_key_dir/vsphere_terraform_key.pub"
        print_status "info" "Please copy your SSH public key to this location"
        return 1
    fi
    return 0
}

# Function to check prerequisites
check_prerequisites() {
    print_status "info" "Checking prerequisites..."

    if ! command -v terraform &> /dev/null; then
        print_status "error" "Terraform is not installed. Please install Terraform first."
        exit 1
    fi
    print_status "success" "Terraform: OK"

    if ! command -v ansible-playbook &> /dev/null; then
        print_status "error" "Ansible is not installed. Please install Ansible first."
        exit 1
    fi
    print_status "success" "Ansible: OK"
}

# Function to validate and set permissions
validate_permissions() {
    print_status "info" "Validating and setting permissions..."

    # Check ansible inventory script
    if [ -f "./ansible/inventory/ansible_inventory.py" ]; then
        chmod +x ./ansible/inventory/ansible_inventory.py
        print_status "success" "Set execute permission for ansible_inventory.py"
    else
        print_status "warning" "ansible_inventory.py not found - skipping permission setting"
    fi

    # Setup SSH keys directory
    if [ ! -d "./ansible/inventory/ssh_keys" ]; then
        mkdir -p ./ansible/inventory/ssh_keys
        print_status "success" "Created SSH keys directory"
    else
        print_status "info" "SSH keys directory already exists"
    fi

    chmod 700 ./ansible/inventory/ssh_keys
    print_status "success" "Set SSH keys directory permissions"
}

# Main script execution
main() {
    print_status "info" "Starting environment setup..."

    # Check prerequisites
    check_prerequisites

    # Validate and set permissions
    validate_permissions

    # Check for SSH keys
    if check_ssh_keys; then
        chmod 600 ./ansible/inventory/ssh_keys/vsphere_ansible_key
        print_status "success" "SSH private key permissions set"
    else
        print_status "warning" "SSH private key validation failed - please add SSH keys before deployment"
    fi

    # Check for SSH public keys
    if check_ssh_pub_keys; then
        chmod 644 ./ansible/inventory/ssh_keys/vsphere_terraform_key.pub
        print_status "success" "SSH public key permissions set"
    else
        print_status "warning" "SSH public key validation failed - please add SSH keys before deployment"
    fi

    # Check for Minecraft world backup
    check_bedrock_backup || true

    print_status "success" "Environment setup complete!"

    # Print final status summary
    echo
    print_status "info" "Setup Status Summary:"
    print_status "info" "- Terraform: OK"
    print_status "info" "- Ansible: OK"
    [ -f "./ansible/inventory/ssh_keys/vsphere_ansible_key" ] && print_status "success" "- SSH private key: Available" || print_status "warning" "- SSH private key: Missing"
    [ -f "./ansible/inventory/ssh_keys/vsphere_terraform_key.pub" ] && print_status "success" "- SSH public key: Available" || print_status "warning" "- SSH public key: Missing"
    [ -f "./ansible/inventory/files/bedrock-backup.gz" ] && print_status "success" "- Bedrock world backup: Available" || print_status "warning" "- Bedrock world backup: Missing"
    print_status "info" "- Log output stored: $LOG_FILE"
}

# Run main function
main

exit 0
