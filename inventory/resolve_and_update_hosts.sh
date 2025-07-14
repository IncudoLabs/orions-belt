#!/bin/bash
#
# SCRIPT: resolve_and_update_hosts.sh
#
# This script updates an Ansible inventory file (default: hosts-production) to ensure
# hosts are consistently defined with both a hostname and an IP address.
# It handles two main scenarios and gracefully handles DNS lookup failures.
#
# 1. IP to Hostname: For hosts defined with an IP, it resolves the hostname. On success, it
#    updates 'ansible_host' to the hostname and adds 'ansible_ip' with the original IP.
# 2. Hostname to IP: For hosts defined by hostname that are missing an 'ansible_ip'
#    variable, it resolves the IP address and adds the 'ansible_ip' variable.
#
# On any DNS lookup failure (e.g., NXDOMAIN), the original host entry is left unchanged.
# The script is idempotent and safe to run multiple times.
#
# USAGE:
# ./resolve_and_update_hosts.sh

# --- Configuration ---
INVENTORY_FILE="hosts-production"

# --- Pre-flight Checks ---
if [ ! -f "$INVENTORY_FILE" ]; then
    echo "ERROR: Inventory file '$INVENTORY_FILE' not found in the current directory." >&2
    exit 1
fi

if ! command -v host &> /dev/null; then
    echo "ERROR: 'host' command not found. Please install dnsutils (Debian/Ubuntu) or bind-utils (CentOS/RHEL)." >&2
    exit 1
fi

# --- Main Logic ---
BACKUP_FILE="${INVENTORY_FILE}.bak.$(date +%Y%m%d-%H%M%S)"
TEMP_FILE=$(mktemp)

# Ensure the temp file is removed on exit
trap 'rm -f "$TEMP_FILE"' EXIT

echo ">>> Starting bidirectional inventory update process for '$INVENTORY_FILE'..."
cp "$INVENTORY_FILE" "$BACKUP_FILE"
echo "    -> Backup created at: $BACKUP_FILE"

changes_made=0
# Read file into an array to allow lookahead for 'ansible_ip'
mapfile -t lines < "$INVENTORY_FILE"

for i in "${!lines[@]}"; do
    line="${lines[i]}"
    
    # Pattern to match 'ansible_host' and capture its value
    if [[ "$line" =~ ^([[:space:]]+)ansible_host:[[:space:]]+(.+) ]]; then
        indent="${BASH_REMATCH[1]}"
        host_val="${BASH_REMATCH[2]}"
        
        # Case 1: Value is an IP address
        if [[ "$host_val" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
            ip="$host_val"
            # Reverse lookup: get hostname from IP
            host_output=$(host "$ip")
            if [ $? -eq 0 ]; then
                hostname=$(echo "$host_output" | awk 'NF>1{print $NF}' | sed 's/\.$//' | head -n 1)
                # Sanity check that we got a valid FQDN
                if [[ "$hostname" =~ \. ]]; then
                    echo "    [IP -> Host] SUCCESS: ${ip} -> ${hostname}"
                    echo "${indent}ansible_host: ${hostname}" >> "$TEMP_FILE"
                    echo "${indent}ansible_ip: ${ip}" >> "$TEMP_FILE"
                    changes_made=$((changes_made + 1))
                else
                    echo "    [IP -> Host] FAILED (Parsed non-FQDN result: '${hostname}'). Keeping original: ${ip}"
                    echo "$line" >> "$TEMP_FILE"
                fi
            else
                echo "    [IP -> Host] FAILED (NXDOMAIN or other error). Keeping original: ${ip}"
                echo "$line" >> "$TEMP_FILE"
            fi
        # Case 2: Value is a hostname
        else
            hostname="$host_val"
            # Look ahead to see if ansible_ip already exists for this host
            next_line_is_ip=false
            if (( i + 1 < ${#lines[@]} )); then
                if [[ "${lines[i+1]}" =~ ansible_ip: ]]; then
                    next_line_is_ip=true
                fi
            fi
            
            if ! $next_line_is_ip; then
                # Forward lookup: get IP from hostname
                host_output=$(host "$hostname")
                if [ $? -eq 0 ]; then
                    ip=$(echo "$host_output" | grep 'has address' | awk '{print $NF}' | head -n 1)
                    if [[ -n "$ip" ]]; then
                        echo "    [Host -> IP] SUCCESS: ${hostname} -> ${ip}"
                        echo "$line" >> "$TEMP_FILE" # Original ansible_host line
                        echo "${indent}ansible_ip: ${ip}" >> "$TEMP_FILE"
                        changes_made=$((changes_made + 1))
                    else
                        echo "    [Host -> IP] FAILED (Could not parse IP for ${hostname}). Keeping original."
                        echo "$line" >> "$TEMP_FILE"
                    fi
                else
                    echo "    [Host -> IP] FAILED (NXDOMAIN or other error). Keeping original: ${hostname}"
                    echo "$line" >> "$TEMP_FILE"
                fi
            else
                 # ansible_ip already exists, just copy the line
                echo "$line" >> "$TEMP_FILE"
            fi
        fi
    else
        # Not an ansible_host line, just copy it
        echo "$line" >> "$TEMP_FILE"
    fi
done

# --- Finalization ---
if [ "$changes_made" -gt 0 ]; then
    mv "$TEMP_FILE" "$INVENTORY_FILE"
    echo ">>> SUCCESS: Inventory file updated with $changes_made change(s)."
    # Prevent trap from deleting the temp file we just moved
    trap - EXIT
else
    echo ">>> INFO: No new hosts to resolve. Inventory file remains unchanged."
fi 