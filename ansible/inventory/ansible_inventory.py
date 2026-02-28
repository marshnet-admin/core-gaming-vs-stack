#!/usr/bin/env python3
import json
import os
import sys
import argparse
from typing import Dict, Any

class TerraformInventory:
    """Dynamic Ansible inventory from Terraform output"""
    
    def __init__(self):
        self.inventory: Dict[str, Any] = {
            '_meta': {
                'hostvars': {}
            },
            'all': {
                'children': []
            }
        }
        self.script_dir = os.path.dirname(os.path.abspath(__file__))
        self.terraform_state = os.path.join(self.script_dir, 'terraform.json')
        self.debug = os.environ.get('ANSIBLE_INVENTORY_DEBUG', 'false').lower() == 'true'

    def log(self, message: str) -> None:
        """Debug logging"""
        if self.debug:
            print(f"DEBUG: {message}", file=sys.stderr)

    def load_terraform_data(self) -> Dict:
        """Load the Terraform output data"""
        try:
            if not os.path.exists(self.terraform_state):
                self.log(f"Terraform state file not found at {self.terraform_state}")
                return {}
                
            with open(self.terraform_state, 'r') as f:
                data = json.load(f)
                self.log(f"Loaded data: {json.dumps(data, indent=2)}")
                return data
                
        except Exception as e:
            self.log(f"Error loading Terraform data: {str(e)}")
            return {}

    def sanitize_group_name(self, name: str) -> str:
        """Sanitize group names to be Ansible-compatible"""
        return name.lower().replace('-', '_').replace(' ', '_')

    def add_group(self, group_name: str) -> None:
        """Add a group to the inventory"""
        group_name = self.sanitize_group_name(group_name)
        if group_name not in self.inventory:
            self.inventory[group_name] = {
                'hosts': []
            }
            if group_name not in self.inventory['all']['children']:
                self.inventory['all']['children'].append(group_name)

    def process_host(self, hostname: str, host_data: Dict) -> None:
        """Process a single host and its data"""
        # Add host variables to _meta
        self.inventory['_meta']['hostvars'][hostname] = host_data

        # Disable host key checking
        self.inventory['_meta']['hostvars'][hostname]['ansible_ssh_common_args'] = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

        # Add Python interpreter
        self.inventory['_meta']['hostvars'][hostname]['ansible_python_interpreter'] = "/usr/bin/python3"

        # Process groups from host data
        groups = set()

        # Add to environment group
        # Rename 'environment' and 'tags' to avoid Ansible reserved variable names
        if 'environment' in host_data:
            host_data['vm_environment'] = host_data.pop('environment')
            groups.add(self.sanitize_group_name(host_data['vm_environment']))

        if 'tags' in host_data:
            host_data['vm_tags'] = host_data.pop('tags')

        # Process tags
        tags = host_data.get('vm_tags', {})
        if tags:
            # Application group
            if 'Application' in tags:
                groups.add(f"app_{self.sanitize_group_name(tags['Application'])}")
            
            # Component group
            if 'Component' in tags:
                groups.add(f"component_{self.sanitize_group_name(tags['Component'])}")
            
            # Service Tier group
            if 'ServiceTier' in tags:
                groups.add(f"tier_{self.sanitize_group_name(tags['ServiceTier'])}")
            
            # Ansible Role group
            if 'AnsibleRole' in tags:
                groups.add(self.sanitize_group_name(tags['AnsibleRole']))

            # Add to groups specified in tags
            if 'AnsibleGroup' in tags:
                groups.add(self.sanitize_group_name(tags['AnsibleGroup']))

        # Create all groups and add host to them
        for group in groups:
            self.add_group(group)
            if hostname not in self.inventory[group]['hosts']:
                self.inventory[group]['hosts'].append(hostname)

    def build_inventory(self) -> None:
        """Build the full inventory from Terraform data"""
        tf_data = self.load_terraform_data()
        
        if not tf_data:
            self.log("No Terraform data found or empty data")
            return

        # Process each service type (vault, gitlab, etc.)
        for service_type, service_data in tf_data.items():
            # Add service-type group
            self.add_group(service_type)
            
            # Process hosts for this service
            for hostname, host_data in service_data.get('hosts', {}).items():
                # Add host to service group
                if hostname not in self.inventory[service_type]['hosts']:
                    self.inventory[service_type]['hosts'].append(hostname)
                
                # Process host and its groups
                self.process_host(hostname, host_data)

        # Remove 'ungrouped' if we have other groups
        if 'ungrouped' in self.inventory['all']['children']:
            self.inventory['all']['children'].remove('ungrouped')

        self.log(f"Final inventory: {json.dumps(self.inventory, indent=2)}")

    def json_output(self) -> None:
        """Output the inventory in JSON format"""
        print(json.dumps(self.inventory, indent=2))

    def list_output(self) -> None:
        """Output the inventory in --list format"""
        self.json_output()

    def host_output(self, host: str) -> None:
        """Output specific host variables"""
        if host in self.inventory['_meta']['hostvars']:
            print(json.dumps(self.inventory['_meta']['hostvars'][host], indent=2))
        else:
            print(json.dumps({}))

def main():
    parser = argparse.ArgumentParser(description='Terraform dynamic inventory for Ansible')
    parser.add_argument('--list', action='store_true', help='List all inventory')
    parser.add_argument('--host', help='Get variables for a specific host')
    parser.add_argument('--debug', action='store_true', help='Enable debug output')
    args = parser.parse_args()

    if args.debug:
        os.environ['ANSIBLE_INVENTORY_DEBUG'] = 'true'

    inventory = TerraformInventory()
    inventory.build_inventory()

    if args.host:
        inventory.host_output(args.host)
    else:
        inventory.list_output()

if __name__ == '__main__':
    main()