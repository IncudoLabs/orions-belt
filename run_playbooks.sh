#!/bin/bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Copyright (c) 2023 - present Expiscor Group Inc.
#
# This file is part of Orion's Belt Project (https://github.com/IncudoLABS/orions-belt).
#
# Published by the IncudoLABS.
# Original author: Marko Sarunac <128757181+SaruWiz@users.noreply.github.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

#
# Orion's Belt - Playbook Runner
#
# This script provides a user-friendly menu system to select and run Ansible
# playbooks for system hardening and configuration.

# --- Virtual Environment Setup ---
VENV_DIR=".venv"
VENV_PYTHON="$VENV_DIR/bin/python"

setup_virtual_environment() {
    # Check if the virtual environment directory exists
    if [ ! -d "$VENV_DIR" ]; then
        echo -e "${YELLOW}Python virtual environment not found. Setting it up now...${NC}"
        
        # Ensure python3-venv is installed on Debian-based systems
        if command -v apt-get &> /dev/null; then
            if ! dpkg -s python3-venv &> /dev/null; then
                echo "Attempting to install python3-venv..."
                sudo apt-get update
                sudo apt-get install -y python3-venv
                if [ $? -ne 0 ]; then
                    echo -e "${RED}Failed to install python3-venv. Please install it manually and re-run this script.${NC}"
                    exit 1
                fi
            fi
        fi
        
        python3 -m venv "$VENV_DIR"
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to create virtual environment. Please check your Python installation.${NC}"
            exit 1
        fi
        
        echo "Virtual environment created. Installing dependencies from requirements.txt..."
        "$VENV_DIR/bin/pip" install -r requirements.txt
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to install dependencies. Please check requirements.txt and your internet connection.${NC}"
            exit 1
        fi
        echo -e "${GREEN}Virtual environment setup complete.${NC}"
    else
        # Always ensure dependencies are in sync on every run
        # This is an idempotent action and will be fast if everything is up to date
        "$VENV_DIR/bin/pip" install -r requirements.txt &>/dev/null
    fi
    
    # Set the VENV_ANSIBLE path after ensuring the virtual environment exists
    VENV_ANSIBLE="$(pwd)/$VENV_DIR/bin/ansible-playbook"
}

# Call the venv setup at the beginning of the script execution
setup_virtual_environment


# --- Environment Setup ---
# Load environment variables from .env file if it exists
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# --- Script Configuration ---
# Set the root directory for playbooks
PLAYBOOK_DIR="playbooks"


# Colors for better output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Global variables
KERBEROS_INITIALIZED=false
KERBEROS_PRINCIPAL=""
# Allow environment to be set via command line argument or environment variable
if [[ -n "$1" ]]; then
    ENVIRONMENT="$1"
elif [[ -n "$ANSIBLE_ENVIRONMENT" ]]; then
    ENVIRONMENT="$ANSIBLE_ENVIRONMENT"
else
    ENVIRONMENT="development"
    # Set the environment variable for future runs when using default
    export ANSIBLE_ENVIRONMENT="$ENVIRONMENT"
fi

# Validate environment parameter
if [[ "$ENVIRONMENT" != "production" && "$ENVIRONMENT" != "development" && "$ENVIRONMENT" != "staging" ]]; then
    echo -e "${RED}Error: Invalid environment '$ENVIRONMENT'${NC}"
    echo -e "${YELLOW}Valid environments are: production, development, staging${NC}"
    exit 1
fi

VAULT_PASSWORD_FILE=""
USE_VAULT=true
clear
# Function to display menu
show_menu() {
    echo -e "${YELLOW}=== Orion's Belt Ansible Playbook Runner ===${NC}"
    echo ""
    echo -e "${YELLOW}Current Configuration:${NC}"
    echo -e "  Environment: ${CYAN}$ENVIRONMENT${NC}"
    echo -e "  Vault: ${CYAN}$([ "$USE_VAULT" = true ] && echo "Enabled" || echo "Disabled")${NC}"
    if [[ "$KERBEROS_INITIALIZED" = true ]]; then
        echo -e "  Kerberos: ${GREEN}Initialized (${KERBEROS_PRINCIPAL})${NC}"
    else
        echo -e "  Kerberos: ${YELLOW}Not Initialized${NC}"
    fi
    
    # Show configuration files being used
    echo -e "  Configuration: ${CYAN}config/config.yml${NC}"
    if [[ -f "config/config-$ENVIRONMENT.yml" ]]; then
        echo -e "    ${GREEN}✓ with overrides from config/config-$ENVIRONMENT.yml${NC}"
    else
        echo -e "    ${YELLOW}⚠ no environment-specific overrides (config/config-$ENVIRONMENT.yml not found)${NC}"
    fi
    
    # Show hosts file being used
    local hosts_file="inventory/hosts-$ENVIRONMENT"
    if [[ -f "$hosts_file" ]]; then
        echo -e "  Inventory: ${CYAN}$hosts_file${NC}"
    else
        echo -e "  Inventory: ${YELLOW}hosts (fallback - $hosts_file not found)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Available Categories:${NC}"
    echo "1. Orion's Belt Security Playbooks"
    echo "2. Server Configuration"
    echo "3. Custom Playbooks"
    echo "4. Runner Settings"
    echo "5. Exit"
    echo ""
}

# Function to configure environment
configure_environment() {
    echo -e "${GREEN}=== Runner Settings ===${NC}"
    echo ""
    echo -e "${YELLOW}Current Settings:${NC}"
    echo "  Environment: $ENVIRONMENT"
    echo "  Vault Usage: $([ "$USE_VAULT" = true ] && echo -e "${GREEN}Enabled${NC}" || echo -e "${YELLOW}Disabled${NC}")"
    if [[ "$USE_VAULT" = true ]]; then
        echo "  Vault Password File: ${VAULT_PASSWORD_FILE:-"Interactive Prompt"}"
    fi
    if [[ "$KERBEROS_INITIALIZED" = true ]]; then
        echo "  Kerberos: ${GREEN}Initialized (${KERBEROS_PRINCIPAL})${NC}"
    else
        echo "  Kerberos: ${YELLOW}Not Initialized${NC}"
    fi
    echo ""
    
    # Show configuration files being used
    echo -e "${YELLOW}Configuration Files:${NC}"
    echo -e "  Base config: ${CYAN}config/config.yml${NC}"
    if [[ -f "config/config-$ENVIRONMENT.yml" ]]; then
        echo -e "    ${GREEN}✓ Environment overrides: config/config-$ENVIRONMENT.yml${NC}"
    else
        echo -e "    ${YELLOW}⚠ No environment overrides (config/config-$ENVIRONMENT.yml not found)${NC}"
    fi
    
    # Show hosts file being used
    echo -e "  Inventory file:"
    local hosts_file="inventory/hosts-$ENVIRONMENT"
    if [[ -f "$hosts_file" ]]; then
        echo -e "    ${GREEN}✓ Using: $hosts_file${NC}"
    else
        echo -e "    ${YELLOW}⚠ Using fallback: hosts (environment-specific $hosts_file not found)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Available Options:${NC}"
    echo "1. Set Environment (development/staging/production)"
    echo "2. Toggle Vault Usage (On/Off)"
    echo "3. Set Vault Password File"
    echo "4. Test Configuration"
    echo "5. Kerberos Authentication"
    echo "6. Back to Main Menu"
    echo ""
    
    read -p "Enter your choice (1-6): " config_choice
    
    case $config_choice in
        1)
            echo -e "${YELLOW}Available Environments:${NC}"
            echo "1. development"
            echo "2. staging"
            echo "3. production"
            read -p "Enter environment choice (1-3): " env_choice
            case $env_choice in
                1) ENVIRONMENT="development" ;;
                2) ENVIRONMENT="staging" ;;
                3) ENVIRONMENT="production" ;;
                *) echo -e "${RED}Invalid choice. Keeping current environment.${NC}" ;;
            esac
            export ANSIBLE_ENVIRONMENT="$ENVIRONMENT"
            echo -e "${GREEN}Environment set to: $ENVIRONMENT${NC}"
            ;;
        2)
            if [[ "$USE_VAULT" = true ]]; then
                USE_VAULT=false
                echo -e "${YELLOW}Vault usage disabled.${NC}"
            else
                USE_VAULT=true
                echo -e "${GREEN}Vault usage enabled.${NC}"
            fi
            ;;
        3)
            read -p "Enter path to vault password file (or press Enter to use interactive): " vault_file
            if [[ -n "$vault_file" ]]; then
                if [[ -f "$vault_file" ]]; then
                    VAULT_PASSWORD_FILE="$vault_file"
                    USE_VAULT=true
                    echo -e "${GREEN}Vault password file set to: $vault_file${NC}"
                else
                    echo -e "${RED}File not found: $vault_file${NC}"
                fi
            else
                VAULT_PASSWORD_FILE=""
                USE_VAULT=true
                echo -e "${GREEN}Will use interactive vault password prompt${NC}"
            fi
            ;;
        4)
            test_configuration
            ;;
        5)
            handle_kerberos_auth
            ;;
        6)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
}

# Function to handle Kerberos authentication
handle_kerberos_auth() {
    echo -e "${GREEN}=== Kerberos Authentication ===${NC}"
    echo ""

    if ! command -v kinit &> /dev/null; then
        echo -e "${RED}Error: 'kinit' command not found.${NC}"
        echo -e "${YELLOW}Please install Kerberos client utilities.${NC}"
        echo "  - For Debian/Ubuntu: sudo apt-get install krb5-user"
        echo "  - For RHEL/CentOS: sudo yum install krb5-workstation"
        echo ""
        read -p "Would you like to run the Active Directory join playbook to configure this now? (y/n): " run_ad_join
        if [[ "$run_ad_join" == "y" ]]; then
            handle_server_configuration
        fi
        return
    fi

    echo -e "${YELLOW}Kerberos Ticket Status:${NC}"
    if klist -s; then
        echo -e "${GREEN}An active Kerberos ticket exists:${NC}"
        klist | head -n 3
    else
        echo -e "${YELLOW}No active Kerberos ticket found.${NC}"
    fi
    echo ""

    echo -e "${YELLOW}Available Options:${NC}"
    echo "1. Initialize/Refresh Kerberos Ticket (kinit)"
    echo "2. Destroy Kerberos Ticket (kdestroy)"
    echo "3. Back to Configuration Menu"
    echo ""
    read -p "Enter your choice (1-3): " krb_choice

    case $krb_choice in
        1)
            read -p "Enter your Kerberos principal (e.g., user@YOUR.DOMAIN.COM): " principal
            if [[ -n "$principal" ]]; then
                if kinit "$principal"; then
                    echo -e "${GREEN}Kerberos ticket obtained successfully for $principal.${NC}"
                    KERBEROS_INITIALIZED=true
                    KERBEROS_PRINCIPAL="$principal"
                else
                    echo -e "${RED}Failed to obtain Kerberos ticket.${NC}"
                    KERBEROS_INITIALIZED=false
                    KERBEROS_PRINCIPAL=""
                fi
            else
                echo -e "${RED}Principal cannot be empty.${NC}"
            fi
            ;;
        2)
            if kdestroy; then
                echo -e "${GREEN}Kerberos ticket destroyed.${NC}"
                KERBEROS_INITIALIZED=false
                KERBEROS_PRINCIPAL=""
            else
                echo -e "${RED}Failed to destroy Kerberos ticket. It might not exist.${NC}"
            fi
            ;;
        3)
            return
            ;;
        *)
            echo -e "${RED}Invalid choice. Please try again.${NC}"
            ;;
    esac
}

# Function to test configuration
test_configuration() {
    echo -e "${GREEN}=== Testing Configuration ===${NC}"
    echo ""
    
    # Check if config files exist
    echo -e "${YELLOW}Checking configuration files:${NC}"
    if [[ -f "config/config.yml" ]]; then
        echo -e "  ${GREEN}✓ config/config.yml${NC}"
    else
        echo -e "  ${RED}✗ config/config.yml (missing)${NC}"
    fi
    
    if [[ -f "config/config-$ENVIRONMENT.yml" ]]; then
        echo -e "  ${GREEN}✓ config/config-$ENVIRONMENT.yml${NC}"
    else
        echo -e "  ${RED}✗ config/config-$ENVIRONMENT.yml (missing)${NC}"
    fi
    
    if [[ -f "vault.yml" ]]; then
        echo -e "  ${GREEN}✓ vault.yml${NC}"
        if [[ "$USE_VAULT" = true ]]; then
            echo -e "  ${CYAN}  (encrypted - will prompt for password)${NC}"
        fi
    else
        echo -e "  ${YELLOW}⚠ vault.yml (not found - some playbooks may fail)${NC}"
    fi
    
    # Check if hosts file exists
    echo -e "${YELLOW}Checking inventory file:${NC}"
    local hosts_file="inventory/hosts-$ENVIRONMENT"
    local fallback_hosts_file="hosts"
    
    if [[ -f "$hosts_file" ]]; then
        echo -e "  ${GREEN}✓ $hosts_file (environment-specific)${NC}"
        # Count hosts in the environment-specific file
        host_count=$(grep -c "^[[:space:]]*[a-zA-Z]" "$hosts_file" || echo "0")
        echo -e "  ${CYAN}  (contains $host_count host definitions)${NC}"
    elif [[ -f "$fallback_hosts_file" ]]; then
        echo -e "  ${YELLOW}⚠ $fallback_hosts_file (fallback - environment-specific file not found)${NC}"
        # Count hosts in the fallback file
        host_count=$(grep -c "^[[:space:]]*[a-zA-Z]" "$fallback_hosts_file" || echo "0")
        echo -e "  ${CYAN}  (contains $host_count host definitions)${NC}"
        echo -e "  ${YELLOW}  Consider creating $hosts_file for environment-specific hosts${NC}"
    else
        echo -e "  ${RED}✗ No hosts file found (neither $hosts_file nor $fallback_hosts_file)${NC}"
    fi
    
    # Check Kerberos status
    echo -e "${YELLOW}Checking Kerberos ticket:${NC}"
    if klist -s &>/dev/null; then
        principal=$(klist 2>/dev/null | grep "Default principal" | awk '{print $3}')
        echo -e "  ${GREEN}✓ Active ticket found for: $principal${NC}"
    else
        echo -e "  ${YELLOW}⚠ No active Kerberos ticket. Windows authentication might fail.${NC}"
        echo -e "  ${CYAN}  (Use Configuration Management -> Kerberos Authentication to get a ticket)${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Configuration Summary:${NC}"
    echo "  Environment: $ENVIRONMENT"
    echo "  Vault Enabled: $USE_VAULT"
    if [[ -n "$VAULT_PASSWORD_FILE" ]]; then
        echo "  Vault Password File: $VAULT_PASSWORD_FILE"
    fi
}

g_playbook_paths=()
g_playbook_names=()

# Function to find the most specific vault file for a host
find_host_vault_file() {
    local host_key="$1" # Assume this is always a valid hostname from inventory
    local vault_pass_source="$2" # Can be a file path or the raw password
    local hosts_file="inventory/hosts-$ENVIRONMENT"
    if [[ ! -f "$hosts_file" ]]; then
        hosts_file="hosts"
    fi

    # 1. Check for host-specific vault file
    if [[ -f "host_vars/$host_key/vault.yml" ]]; then
        echo "host_vars/$host_key/vault.yml"
        return
    fi

    # 2. Check group_vars for the host's groups using a robust method
    local groups
    local inventory_cmd="ansible-inventory -i \"$hosts_file\" --list"

    # If we have a password, provide it to the command so it can read vaulted inventories
    if [[ -f "$vault_pass_source" ]]; then
        inventory_cmd="$inventory_cmd --vault-password-file \"$vault_pass_source\""
    elif [[ -n "$vault_pass_source" ]]; then
        inventory_cmd="$inventory_cmd --vault-password-file <(echo \"$vault_pass_source\")"
    fi
    
    # Use python to safely parse the --list output and find all groups for a host
    groups=$(eval "$inventory_cmd" 2>/dev/null | python3 -c '
import json, sys
host_to_find = sys.argv[1]
try:
    inventory = json.load(sys.stdin)
    host_groups = []
    for group, data in inventory.items():
        if group.startswith("_") or group == "all": continue
        if isinstance(data, dict) and "hosts" in data:
            if host_to_find in data.get("hosts", []):
                host_groups.append(group)
    print(" ".join(host_groups))
except (json.JSONDecodeError, IndexError, TypeError):
    sys.exit(0)
' "$host_key" 2>/dev/null)


    for group in $groups; do
        # Check for directory-style group_vars
        if [[ -f "group_vars/$group/vault.yml" ]]; then
            echo "group_vars/$group/vault.yml"
            return
        fi
        # Check for file-style group_vars
        if [[ -f "group_vars/${group}.yml" && "$(head -n1 "group_vars/${group}.yml")" == "\$ANSIBLE_VAULT;1.1;AES256" ]]; then
             echo "group_vars/${group}.yml"
             return
        fi
    done
    
    # 3. Fallback to the 'all' group vault file
    if [[ -f "group_vars/all/vault.yml" ]]; then
        echo "group_vars/all/vault.yml"
        return
    fi
    
    # 4. Fallback to legacy vault.yml
    if [[ -f "vault.yml" ]]; then
        echo "vault.yml"
        return
    fi

    echo "" # Return empty if no vault file is found
}


# Function to build ansible-playbook command
build_ansible_command() {
    local playbook_path="$1"
    local extra_vars="$2"
    local vault_pass_source="$3" # This can now be a file path OR the raw password
    local vault_file_for_injection="$4" # The specific vault file to decrypt for injection

    local cmd="\"$VENV_ANSIBLE\" \"$playbook_path\""

    # Add inventory file - use environment-specific hosts file
    local hosts_file="inventory/hosts-$ENVIRONMENT"
    if [[ ! -f "$hosts_file" ]]; then
        # Fallback to generic hosts file
        hosts_file="hosts"
    fi
    cmd="$cmd -i \"$hosts_file\""

    # Add environment variable, using a non-reserved name
    cmd="$cmd -e \"target_env=$ENVIRONMENT\""

    # Add extra vars if provided
    if [[ -n "$extra_vars" ]]; then
        cmd="$cmd -e \"$extra_vars\""
    fi

    # Add vault options if needed
    if [[ "$USE_VAULT" = true ]]; then
        if [[ -f "$vault_pass_source" ]]; then
            # It's a file path
            cmd="$cmd --vault-password-file \"$vault_pass_source\""
        elif [[ -n "$vault_pass_source" ]]; then
            # It's the raw password, use process substitution
            cmd="$cmd --vault-password-file <(echo \"$vault_pass_source\")"
        else
            # Fallback to interactive prompt
            cmd="$cmd --ask-vault-pass"
        fi
    fi

    # For network device playbooks, inject credentials from the vault
    if [[ "$playbook_path" == *network_hardening* && "$USE_VAULT" = true ]]; then
        local target_host
        target_host=$(echo "$extra_vars" | sed -n "s/.*target_hosts=\\([^,]*\\).*/\\1/p")
        
        local vault_file_to_use
        vault_file_to_use=$(find_host_vault_file "$target_host" "$vault_pass_source")

        if [[ -n "$vault_file_to_use" ]]; then
            echo "Network playbook detected. Using vault '$vault_file_to_use' for credentials..." >&2
            
            local decrypted_vault_content=""
            if [[ -f "$vault_pass_source" ]]; then
                # It's a file path
                decrypted_vault_content=$(ansible-vault view --vault-password-file "$vault_pass_source" "$vault_file_to_use" 2>/dev/null)
            elif [[ -n "$vault_pass_source" ]]; then
                # It's the raw password, use process substitution
                decrypted_vault_content=$(ansible-vault view --vault-password-file <(echo "$vault_pass_source") "$vault_file_to_use" 2>/dev/null)
            fi

            if [[ $? -eq 0 && -n "$decrypted_vault_content" ]]; then
                local vault_user=$(echo "$decrypted_vault_content" | grep "ansible_user:" | head -n1 | cut -d'"' -f2 | tr -d ' ')
                local vault_password=$(echo "$decrypted_vault_content" | grep "ansible_password:" | head -n1 | cut -d'"' -f2 | tr -d ' ')
                local vault_enable=$(echo "$decrypted_vault_content" | grep "ansible_become_password:" | head -n1 | cut -d'"' -f2 | tr -d ' ')
                
                if [[ -n "$vault_user" && -n "$vault_password" && -n "$vault_enable" ]]; then
                    cmd="$cmd -e ansible_user=\"$vault_user\" -e ansible_password=\"$vault_password\" -e ansible_become_password=\"$vault_enable\""
                    echo "Successfully injected vault credentials for network device." >&2
                else
                    echo "Warning: Could not extract all required credentials from vault '$vault_file_to_use'." >&2
                fi
            else
                echo "Warning: Failed to decrypt or read vault file '$vault_file_to_use'. Playbook may fail." >&2
            fi
        else
            echo "Warning: No vault file found for host '$target_host'. Relying on other credential sources." >&2
        fi
    elif [[ "$playbook_path" == *network_hardening* && "$USE_VAULT" = false ]]; then
        # Fallback to environment variables if vault is not used for network devices
        if [[ -n "$CISCO_USER" && -n "$CISCO_PASSWORD" && -n "$CISCO_ENABLE_PASSWORD" ]]; then
            cmd="$cmd -e ansible_user=$CISCO_USER -e ansible_password=$CISCO_PASSWORD -e ansible_become_password=$CISCO_ENABLE_PASSWORD"
            echo "Using environment variable credentials for network device." >&2
        else
            echo "Warning: Vault is disabled and Cisco environment variables not set. Playbook may fail." >&2
        fi
    fi

    # Add static network connection parameters ONLY IF they aren't in the command already
    # This avoids overriding inventory variables but ensures they are present if needed.
    if ! echo "$cmd" | grep -q "ansible_connection=network_cli"; then
        cmd="$cmd -e ansible_connection=network_cli -e ansible_network_os=cisco.ios.ios -e ansible_network_cli_ssh_type=paramiko -e ansible_paramiko_host_key_auto_add=true -e \"ansible_ssh_common_args=-o KexAlgorithms=diffie-hellman-group14-sha1 -o HostKeyAlgorithms=ssh-rsa -o Ciphers=aes256-cbc -o MACs=hmac-sha1 -o StrictHostKeyChecking=no\" -e \"ansible_ssh_extra_args=-o PubkeyAuthentication=no\""
    fi

    echo "$cmd"
}

# Function to list playbooks in a directory
list_playbooks() {
    local dir="$1"
    g_playbook_paths=()
    g_playbook_names=()
    
    # Find all .yml, .yaml, and .sh files, excluding _tasks files
    for file in "$dir"/*.yml "$dir"/*.yaml "$dir"/*.sh; do
        # Skip files that don't exist (in case no files match pattern)
        [[ -f "$file" ]] || continue
        
        # Skip tasks-only files (ending with _tasks.yml or _tasks.yaml)
        if [[ "$file" =~ _tasks\.(yml|yaml)$ ]]; then
            continue
        fi
        
        # Skip configuration files by checking the basename
        if [[ "$(basename "$file")" =~ ^config.*\.(yml|yaml)$ ]]; then
            continue
        fi
        
        # Get the filename without path
        g_playbook_paths+=("$file")
        
        # Extract the name from the script metadata
        local script_name=""
        if [[ "$file" =~ \.(yml|yaml)$ ]]; then
            # For YAML files, look for the name field in the playbook
            # Extract the name from the first playbook's name field
            script_name=$(grep "^[[:space:]]*-[[:space:]]*name:" "$file" | head -1 | sed 's/^[[:space:]]*-[[:space:]]*name:[[:space:]]*//' | sed -e 's/^"//' -e 's/"$//' 2>/dev/null)
        elif [[ "$file" =~ \.sh$ ]]; then
            # For shell scripts, use the filename as fallback
            script_name=$(basename "$file" .sh | sed 's/OB-[0-9]*_//' | sed 's/_/ /g')
        fi
        
        # If we couldn't extract a name, use the filename as fallback
        if [[ -z "$script_name" ]]; then
            script_name=$(basename "$file" | sed 's/\.yml$//' | sed 's/\.yaml$//' | sed 's/\.sh$//' | sed 's/OB-[0-9]*_//' | sed 's/_/ /g')
        fi
        
        g_playbook_names+=("$script_name")
    done
    
    # Display the filtered playbooks
    if [[ ${#g_playbook_paths[@]} -eq 0 ]]; then
        echo -e "${RED}No runnable playbooks found in $dir${NC}"
        return 1
    fi
    
    for i in "${!g_playbook_names[@]}"; do
        echo "$((i+1)). ${g_playbook_names[$i]}"
    done
    
    return 0
}

# Function to select and run a playbook from a given path
select_playbook_and_run() {
    local playbook_path_prefix="$1"

    if list_playbooks "$playbook_path_prefix"; then
        read -p "Enter the number of the playbook you want to execute: " choice
        read -p "Enter the hosts/group/IPs (comma-separated) to execute the playbook on: " hosts_input

        local final_targets=()
        local hosts_file="inventory/hosts-$ENVIRONMENT"
        if [[ ! -f "$hosts_file" ]]; then
            hosts_file="hosts"
        fi

        IFS=',' read -ra targets_array <<< "$hosts_input"
        for target in "${targets_array[@]}"; do
            target=$(echo "$target" | xargs)
            if [[ -z "$target" ]]; then
                continue
            fi
            if [[ "$target" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
                echo -e "${CYAN}    -> Searching for host with IP $target in $hosts_file...${NC}"
                local host_key
                host_key=$(awk -v ip="$target" '
                    NF == 1 && /:/ { current_host = $1; sub(/:$/, "", current_host); }
                    NF == 2 && ($1 == "ansible_host:" || $1 == "ansible_ip:") && $2 == ip { print current_host; exit; }
                ' "$hosts_file")
                if [[ -n "$host_key" ]]; then
                    echo -e "${GREEN}    -> Found host key: '$host_key'. Targeting this host.${NC}"
                    final_targets+=("$host_key")
                else
                    echo -e "${YELLOW}    -> WARNING: IP $target not found in inventory. Using IP directly.${NC}"
                    final_targets+=("$target")
                fi
            else
                final_targets+=("$target")
            fi
        done
        local target_hosts
        target_hosts=$(IFS=,; echo "${final_targets[*]}")

        if [[ $choice -gt 0 && $choice -le ${#g_playbook_paths[@]} ]]; then
            local playbook_to_run="${g_playbook_paths[$((choice-1))]}"
            echo -e "${GREEN}Executing $(basename "$playbook_to_run") on hosts '$target_hosts'...${NC}"
            echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"

            local vault_pass_source="$VAULT_PASSWORD_FILE"
            
            # If vault is enabled and no password file is set, prompt the user generically once.
            if [[ "$USE_VAULT" = true && -z "$vault_pass_source" ]]; then
                echo "Enter vault password:"
                read -s vault_pass_source
            fi

            # Now, find the correct vault file to use for credential injection, passing the password if we have it.
            local first_target_host
            first_target_host=$(echo "$target_hosts" | cut -d, -f1)
            local vault_file_to_use
            vault_file_to_use=$(find_host_vault_file "$first_target_host" "$vault_pass_source")

            # Build and execute command
            local cmd
            cmd=$(build_ansible_command "$playbook_to_run" "target_hosts=$target_hosts" "$vault_pass_source" "$vault_file_to_use")
            echo ""
            
            # Execute the command
            export ANSIBLE_CONFIG="$(pwd)/ansible.cfg"
            eval "$cmd"
            
            local cmd_exit_code=$?
            # Clean up temporary vault pass file if it was created
            unset ANSIBLE_CONFIG
            
            return $cmd_exit_code
        else
            echo -e "${RED}Invalid choice. Exiting.${NC}"
        fi
    fi
}


# Function to handle Orion's Belt Security playbooks
handle_security_hardening() {
    echo -e "${GREEN}=== Orion's Belt Security Playbooks ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    echo -e "${YELLOW}Available Categories:${NC}"
    echo "1. OS Hardening"
    echo "2. Network Device Hardening"
    echo "3. Cloud Environment Hardening"
    echo "4. Back to Main Menu"
    echo ""
    
    read -p "Enter your choice (1-4): " sec_choice
    
    case $sec_choice in
        1) handle_os_hardening ;;
        2) handle_network_hardening ;;
        3) handle_cloud_hardening ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
}

# Function to handle OS Hardening submenu
handle_os_hardening() {
    echo -e "${GREEN}=== OS Hardening ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    echo -e "${YELLOW}Available OS Hardening Categories:${NC}"
    echo "1. Filesystem Security"
    echo "2. Boot & System Security"
    echo "3. Network Security"
    echo "4. Authentication & SSH"
    echo "5. Back to Security Playbooks Menu"
    echo ""
    
    read -p "Enter your choice (1-5): " os_choice
    
    case $os_choice in
        1) select_playbook_and_run "playbooks/os_hardening/filesystem" ;;
        2) select_playbook_and_run "playbooks/os_hardening/boot" ;;
        3) select_playbook_and_run "playbooks/os_hardening/network" ;;
        4) select_playbook_and_run "playbooks/os_hardening/authentication" ;;
        5) return ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
}

# Function to handle Network Device Hardening
handle_network_hardening() {
    echo -e "${GREEN}=== Network Device Hardening ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    echo -e "${YELLOW}Available Device Types:${NC}"
    echo "1. Cisco IOS"
    echo "2. Juniper JunOS"
    echo "3. Palo Alto PAN-OS"
    echo "4. Back to Security Playbooks Menu"
    echo ""
    
    read -p "Enter your choice (1-4): " net_choice
    
    case $net_choice in
        1) select_playbook_and_run "playbooks/network_hardening/cisco_ios" ;;
        2) select_playbook_and_run "playbooks/network_hardening/juniper_junos" ;;
        3) select_playbook_and_run "playbooks/network_hardening/paloalto_panos" ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
}

# Function to handle Cloud Environment Hardening
handle_cloud_hardening() {
    echo -e "${GREEN}=== Cloud Environment Hardening ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    echo -e "${YELLOW}Available Cloud Platforms:${NC}"
    echo "1. Amazon Web Services (AWS)"
    echo "2. Microsoft Azure"
    echo "3. Google Cloud Platform (GCP)"
    echo "4. Back to Security Playbooks Menu"
    echo ""
    
    read -p "Enter your choice (1-4): " cloud_choice
    
    case $cloud_choice in
        1) select_playbook_and_run "playbooks/cloud_hardening/aws" ;;
        2) select_playbook_and_run "playbooks/cloud_hardening/azure" ;;
        3) select_playbook_and_run "playbooks/cloud_hardening/gcp" ;;
        4) return ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
}

# Function to handle Custom playbooks
handle_custom() {
    echo -e "${GREEN}=== Custom Playbooks ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    select_playbook_and_run "Custom"
}

# Function to handle Server Configuration playbooks
handle_server_configuration() {
    echo -e "${GREEN}=== Server Configuration ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    echo -e "${YELLOW}Available Categories:${NC}"
    echo "1. Linux Configuration"
    echo "2. Windows Configuration"
    echo "3. Back to Main Menu"
    echo ""
    
    read -p "Enter your choice (1-3): " server_config_choice
    
    case $server_config_choice in
        1) handle_linux_configuration ;;
        2) handle_windows_configuration ;;
        3) return ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
}

# Function to handle Linux Server Configuration
handle_linux_configuration() {
    echo -e "${GREEN}=== Linux Server Configuration ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    select_playbook_and_run "playbooks/server_configurations/linux"
}

# Function to handle Windows Server Configuration
handle_windows_configuration() {
    echo -e "${GREEN}=== Windows Server Configuration ===${NC}"
    echo -e "${CYAN}Environment: $ENVIRONMENT${NC}"
    echo ""
    select_playbook_and_run "playbooks/server_configurations/windows"
}


# Function to display help
show_help() {
    echo -e "${BLUE}=== Orion's Belt Ansible Playbook Runner Help ===${NC}"
    echo ""
    echo -e "${YELLOW}Configuration System:${NC}"
    echo "  This script supports the new configuration system with:"
    echo "  - Environment-specific configurations (dev/staging/prod)"
    echo "  - Environment-specific hosts files (hosts-development, hosts-staging, hosts-production)"
    echo "  - Ansible Vault integration for secure credentials"
    echo "  - Centralized configuration management"
    echo ""
    echo -e "${YELLOW}Usage:${NC}"
    echo "  1. Configure environment and vault settings (Option 3)"
    echo "  2. Select playbook category"
    echo "  3. Choose specific playbook"
    echo "  4. Enter target hosts"
    echo ""
    echo -e "${YELLOW}Configuration Files:${NC}"
    echo "  - config/config.yml: Main configuration"
    echo "  - config/config-{environment}.yml: Environment overrides"
    echo "  - vault.yml: Encrypted sensitive data"
    echo ""
    echo -e "${YELLOW}Hosts Files:${NC}"
    echo "  - inventory/hosts-{environment}: Environment-specific inventory (recommended)"
    echo "  - hosts: Fallback inventory file (intentionally empty)"
    echo ""
    echo -e "${YELLOW}For more information, see: CONFIGURATION.md${NC}"
}

# Main menu loop
while true; do
    show_menu
    read -p "Enter your choice (1-5): " main_choice
    
    case $main_choice in
        1) handle_security_hardening ;;
        2) handle_server_configuration ;;
        3) handle_custom ;;
        4) configure_environment ;;
        5) echo -e "${GREEN}Goodbye!${NC}"; exit 0 ;;
        *) echo -e "${RED}Invalid choice. Please try again.${NC}" ;;
    esac
    
    echo ""
    read -p "Press Enter to continue..."
    clear
done

