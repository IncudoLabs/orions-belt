#!/usr/bin/awk -f

# SCRIPT: deduplicate_hosts.sh
#
# This script processes an Ansible inventory file to find and remove duplicate host
# definitions from a 'misc' group. It is written using portable awk syntax to ensure
# compatibility with different awk implementations (e.g., mawk, nawk, gawk).
#
# A duplicate is identified if any of the following match between a 'misc' host
# and a non-'misc' host:
#   - The inventory host key (e.g., 'obelisk3:')
#   - The value of 'ansible_host'
#   - The value of 'ansible_ip'
#
# USAGE:
# ./deduplicate_hosts.sh <inventory_file> <inventory_file> > <inventory_file>.tmp && mv <inventory_file>.tmp <inventory_file>
# e.g., ./deduplicate_hosts.sh hosts-production hosts-production > hosts-production.tmp && mv hosts-production.tmp hosts-production

# First pass: Build a database of all identifiers (host keys, ansible_host, ansible_ip)
# that exist *outside* of the 'misc' group.
NR==FNR {
    if ($0 ~ /^misc:/) { in_misc_section = 1 }

    if (!in_misc_section) {
        # Match a host key (e.g., "  obelisk3:")
        if ($0 ~ /^[[:space:]]*[a-zA-Z0-9._-]+:/) {
            host_key = $0
            sub(/^[[:space:]]*/, "", host_key); sub(/:.*/, "", host_key)
            main_identifiers[host_key] = 1
        }
        # Match ansible_host or ansible_ip value
        if ($0 ~ /ansible_(host|ip):/) {
            identifier_value = $0
            sub(/.*ansible_(host|ip):[[:space:]]*/, "", identifier_value)
            main_identifiers[identifier_value] = 1
        }
    }
    next
}

# Second pass: Process the file to print the cleaned version
{
    if ($0 ~ /^misc:/) { in_misc_section = 1 }

    if (!in_misc_section) {
        print
        next
    }

    # --- Start of 'misc' section processing ---

    # If a line defines a new host block in the misc section...
    if ($0 ~ /^[[:space:]]+[a-zA-Z0-9._-]+:/) {
        if (current_block && !is_duplicate) { print current_block }
        
        current_block = $0
        is_duplicate = 0
        
        host_key = $0
        sub(/^[[:space:]]*/, "", host_key); sub(/:.*/, "", host_key)
        if (host_key in main_identifiers) {
            is_duplicate = 1
            print sprintf("    -> Found duplicate host key '%s' in 'misc'. Removing block.", host_key) > "/dev/stderr"
        }
        next
    }

    # If we are inside a block within the 'misc' section...
    if (current_block) {
        current_block = current_block "\n" $0
        
        if ($0 ~ /ansible_(host|ip):/) {
            identifier_value = $0
            sub(/.*ansible_(host|ip):[[:space:]]*/, "", identifier_value)
            if (identifier_value in main_identifiers) {
                is_duplicate = 1
                print sprintf("    -> Found duplicate identifier '%s' in 'misc'. Removing block.", identifier_value) > "/dev/stderr"
            }
        }
    } else {
        print
    }
}

# END block: After processing all lines, print the last block if it wasn't a duplicate
END {
    if (current_block && !is_duplicate) {
        print current_block
    }
} 