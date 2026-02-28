#!/bin/bash

# Log file location
mkdir -p outputs/logs
LOG_FILE="outputs/logs/deploy$(date +%Y%m%d_%H%M%S).log"

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
            echo "ℹ️  $message"
            ;;
        "success")
            echo -e "${GREEN}✅ $message${NC}"
            ;;
        "warning")
            echo -e "${YELLOW}⚠️  $message${NC}"
            ;;
        "error")
            echo -e "${RED}❌ $message${NC}"
            ;;
    esac
}

# Function to clean up
cleanup() {
    print_status "info" "Cleaning up environment variables..."
    unset TF_VAR_gbl_vsphere_password
}

# Set cleanup to run on script exit
trap cleanup EXIT

# Function to check state files
check_state_files() {
    local state_files_exist=false
    
    if [ -d ".terraform" ] || [ -f "terraform.tfstate" ] || [ -f "terraform.tfstate.backup" ]; then
        state_files_exist=true
        print_status "warning" "Terraform state files found:"
        [ -d ".terraform" ] && echo "  - .terraform directory"
        [ -f "terraform.tfstate" ] && echo "  - terraform.tfstate"
        [ -f "terraform.tfstate.backup" ] && echo "  - terraform.tfstate.backup"
        
        echo
        read -p "Do you want to remove existing state files and continue? (yes/no): " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            # Backup state files first
            backup_state_files
            print_status "info" "Removing state files..."
            rm -rf .terraform*
            rm -rf terraform*
            print_status "success" "State files removed"
        else
            print_status "info" "Deployment cancelled"
            exit 0
        fi
    fi
}

# Function to backup state files
backup_state_files() {
    mkdir -p outputs/states
    local backup_dir="outputs/states/terraform_backup_$(date +%Y%m%d_%H%M%S)"
    print_status "info" "Creating state file backup in $backup_dir..."
    
    mkdir -p "$backup_dir"
    if [ -d "terraform.tfstate.d" ]; then
        cp -r terraform.tfstate.d "$backup_dir/"
    fi
    if [ -d "terraform.tfstate.backup" ]; then
        cp terraform.tfstate.backup "$backup_dir/"
    fi
    if [ -d ".terraform" ]; then
        cp -r .terraform "$backup_dir/"
    fi
    if [ -f "ansible/inventory/terraform.json" ]; then
        cp ansible/inventory/terraform.json "$backup_dir/"
    fi
    
    print_status "success" "State files backed up to $backup_dir"
}

# Check prerequisites
check_prerequisites() {
    print_status "info" "Checking prerequisites..."
    
    if ! command -v terraform >/dev/null 2>&1; then
        print_status "error" "Terraform is required but not installed."
        exit 1
    fi
    
    if ! command -v ansible-playbook >/dev/null 2>&1; then
        print_status "error" "Ansible is required but not installed."
        exit 1
    fi
    
    if [ ! -f "./ansible/inventory/ssh_keys/vsphere_ansible_key" ]; then
        print_status "error" "SSH private key not found. Please set up SSH keys first."
        exit 1
    fi

    if [ ! -f "./ansible/inventory/ssh_keys/vsphere_terraform_key.pub" ]; then
        print_status "error" "SSH public key not found. Please set up SSH keys first."
        exit 1
    fi

    print_status "success" "Prerequisites check passed"
}

# Function to wait for SSH to be available on all hosts
wait_for_ssh() {
    local max_attempts=30
    local attempt=1
    local wait_seconds=10

    # Extract host IPs from the terraform inventory
    local hosts=$(python3 -c "
import json
with open('./ansible/inventory/terraform.json') as f:
    data = json.load(f)
for service in data.values():
    for host, details in service.get('hosts', {}).items():
        print(details.get('ansible_host', ''))
" 2>/dev/null | grep -v '^$')

    if [ -z "$hosts" ]; then
        print_status "warning" "No hosts found in inventory, skipping SSH wait"
        return 0
    fi

    for host in $hosts; do
        print_status "info" "Waiting for SSH on $host..."
        attempt=1

        while [ $attempt -le $max_attempts ]; do
            if nc -z -w 5 "$host" 22 2>/dev/null; then
                print_status "success" "SSH available on $host"
                # Give sshd a moment to fully initialize
                sleep 5
                break
            fi

            if [ $attempt -eq $max_attempts ]; then
                print_status "error" "Timeout waiting for SSH on $host after $((max_attempts * wait_seconds)) seconds"
                return 1
            fi

            echo "  Attempt $attempt/$max_attempts - waiting ${wait_seconds}s..."
            sleep $wait_seconds
            ((attempt++))
        done
    done

    print_status "success" "All hosts are reachable via SSH"
    return 0
}

# Function to get vSphere password
get_vsphere_password() {
    local vsphere_pw1 vsphere_pw2
    print_status "info" "vSphere Authentication"
    read -sp "Enter password for vSphere user: " vsphere_pw1
    echo
    read -sp "Confirm vSphere password: " vsphere_pw2
    echo
    
    if [ "$vsphere_pw1" = "$vsphere_pw2" ]; then
        if [ -z "$vsphere_pw1" ]; then
            print_status "error" "Password cannot be empty"
            return 1
        fi
        export TF_VAR_gbl_vsphere_password="$vsphere_pw1"
        print_status "success" "vSphere password set successfully"
        unset vsphere_pw1 vsphere_pw2
        return 0
    else
        print_status "error" "Passwords do not match. Please try again."
        unset vsphere_pw1 vsphere_pw2
        return 1
    fi
}

# Main deployment function
main() {
    print_status "info" "Starting deployment..."

    # Check prerequisites
    check_prerequisites

    # Check and handle existing state files
    check_state_files

    # Set permissions
    print_status "info" "Setting permissions..."
    chmod 755 ./ansible/inventory/ansible_inventory.py
    chmod 600 ./ansible/inventory/ssh_keys/vsphere_ansible_key
    chmod 700 ./ansible/inventory/ssh_keys
    mkdir -p ./ansible/inventory/outputs

    # Get and set vSphere password
    while ! get_vsphere_password; do
        print_status "info" "Please try again..."
    done

    # Initialize and apply Terraform
    print_status "info" "Applying Terraform configuration..."
    terraform init
    
    # Handle workspace creation/selection
    if terraform workspace list | grep -q production; then
        terraform workspace select production
    else
        terraform workspace new production
    fi

    terraform apply -var-file=environments/local.tfvars \
                   -var-file=environments/production.tfvars \
                   -auto-approve

    # Generate Ansible inventory
    print_status "info" "Generating Ansible inventory..."
    terraform output -json ansible_inventory > ./ansible/inventory/terraform.json

    # Wait for VM to be ready
    print_status "info" "Waiting for VM to be ready..."
    wait_for_ssh

    # Run Ansible playbooks (add -v, -vv or -vvv for verbose logs)
    print_status "info" "Running Ansible playbooks..."
    ansible-playbook -i ./ansible/inventory/ansible_inventory.py ./ansible/playbooks/site_gaming.yml

    backup_state_files

    print_status "success" "Deployment complete!"
    print_status "info" "Log output stored: $LOG_FILE"
}

# Run main function with error handling
main || {
    print_status "error" "Deployment failed!"
    exit 1
}

exit 0
