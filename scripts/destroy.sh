#!/bin/bash

# Log file location
mkdir -p outputs/logs
LOG_FILE="outputs/logs/destroy$(date +%Y%m%d_%H%M%S).log"

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
        "danger")
            echo -e "${RED}💀 $message${NC}"
            ;;
    esac
}

# Function to clean up
cleanup() {
    print_status "info" "Cleaning up environment variables..."
    unset TF_VAR_gbl_vsphere_password
}

# Error handler
error_handler() {
    print_status "error" "An error occurred on line $1"
    cleanup
    exit 1
}

# Set cleanup to run on script exit and error handling
trap cleanup EXIT
trap 'error_handler ${LINENO}' ERR

# Function to validate environment files
validate_env_files() {
    local missing_files=0
    
    if [ ! -f "environments/local.tfvars" ]; then
        print_status "error" "Missing environments/local.tfvars file"
        missing_files=$((missing_files + 1))
    fi
    
    if [ ! -f "environments/production.tfvars" ]; then
        print_status "error" "Missing environments/production.tfvars file"
        missing_files=$((missing_files + 1))
    fi
    
    return $missing_files
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

# Function to confirm destruction with multiple confirmations
confirm_destroy() {
    local environment=$1
    print_status "danger" "DESTRUCTION WARNING!"
    print_status "danger" "This will destroy ALL resources in the $environment environment!"
    print_status "danger" "This action CANNOT be undone!"
    echo
    read -p "Type the environment name '$environment' to confirm: " typed_env

    if [ "$typed_env" != "$environment" ]; then
        print_status "info" "Destruction cancelled - environment name mismatch"
        exit 0
    fi
    
    echo
    read -p "Are you absolutely sure you want to continue? (yes/NO): " confirmation
    
    if [[ ! "$confirmation" =~ ^([yY][eE][sS])$ ]]; then
        print_status "info" "Destruction cancelled - confirmation rejected"
        exit 0
    fi
}

# Function to check Terraform state and installation
check_terraform() {
    print_status "info" "Checking Terraform installation and state..."
    
    if ! command -v terraform &> /dev/null; then
        print_status "error" "Terraform is not installed"
        exit 1
    fi

    if [ ! -d ".terraform" ]; then
        print_status "info" "Terraform not initialized."
        print_status "error" "Cancelling destruction..."
        exit 1
    fi
}

# Function to handle workspace operations
handle_workspace() {
    local workspace=$1
    print_status "info" "Verifying workspace '$workspace'..."
    
    if ! terraform workspace list | grep -q "$workspace"; then
        print_status "error" "Workspace '$workspace' does not exist"
        exit 1
    fi
    
    print_status "info" "Selecting workspace '$workspace'..."
    terraform workspace select "$workspace" || {
        print_status "error" "Failed to select workspace '$workspace'"
        exit 1
    }
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

# Main function
main() {
    print_status "warning" "Starting infrastructure destruction process..."

    # Check Terraform installation and state
    check_terraform
    
    # Validate environment files
    validate_env_files || {
        print_status "error" "Missing required environment files"
        exit 1
    }

    # Get multiple confirmations for destruction
    confirm_destroy "production"

    # Backup state files
    backup_state_files

    # Get and set vSphere password
    while ! get_vsphere_password; do
        print_status "info" "Please try again..."
    done

    # Handle workspace selection
    handle_workspace "production"

    # Destroy infrastructure
    print_status "danger" "Destroying infrastructure..."
    if terraform destroy \
        -var-file=environments/local.tfvars \
        -var-file=environments/production.tfvars \
        -auto-approve; then
        print_status "success" "Infrastructure destroyed successfully"
    else
        print_status "error" "Failed to destroy infrastructure"
        exit 1
    fi

    # Clean up files
    print_status "info" "Cleaning up files..."
    rm -rf .terraform*
    rm -rf terraform*
    rm -rf ./ansible/inventory/terraform.json
    rm -rf ./ansible/inventory/outputs

    print_status "success" "Infrastructure destruction complete!"
    print_status "info" "Log output stored: $LOG_FILE"
}

# Run main function
main

exit 0
