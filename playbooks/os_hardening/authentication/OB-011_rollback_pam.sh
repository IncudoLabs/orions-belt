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
# Script ID: OB-011

# PAM Configuration Rollback Script
# Use this script if SSH authentication breaks after PAM hardening
# Run this script from console access if SSH is not working

set -e

echo "=== PAM Configuration Rollback Script ==="
echo "This script will restore the original PAM configuration files."
echo "Use this if SSH authentication breaks after security hardening."
echo

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root"
    exit 1
fi

# Function to restore backup files
restore_backup() {
    local config_file="$1"
    local backup_pattern="${config_file}.backup.*"
    
    echo "Looking for backups of $config_file..."
    
    # Find the most recent backup
    local latest_backup=$(ls -t ${backup_pattern} 2>/dev/null | head -1)
    
    if [ -n "$latest_backup" ]; then
        echo "✅ Found backup: $latest_backup"
        echo "Restoring $config_file from backup..."
        cp "$latest_backup" "$config_file"
        echo "✅ Restored $config_file"
    else
        echo "⚠️  No backup found for $config_file"
        echo "Attempting to restore from package..."
        
        # Try to restore from package
        if command -v dpkg >/dev/null 2>&1; then
            dpkg-reconfigure libpam-modules
        else
            echo "❌ Cannot restore $config_file - no backup or package manager available"
        fi
    fi
}

# List of PAM configuration files to restore
PAM_FILES=(
    "/etc/pam.d/common-auth"
    "/etc/pam.d/common-account"
    "/etc/pam.d/common-password"
    "/etc/pam.d/common-session"
    "/etc/pam.d/login"
    "/etc/pam.d/sshd"
    "/etc/pam.d/passwd"
)

echo "🔍 Scanning for backup files..."
echo

# Restore each PAM configuration file
for config_file in "${PAM_FILES[@]}"; do
    if [ -f "$config_file" ]; then
        restore_backup "$config_file"
    else
        echo "⚠️  $config_file does not exist, skipping..."
    fi
    echo
done

# Also restore password configuration files
echo "🔍 Restoring password configuration files..."
restore_backup "/etc/login.defs"
restore_backup "/etc/security/pwquality.conf"
restore_backup "/etc/default/useradd"

# Reset PAM tally if available
if command -v pam_tally2 >/dev/null 2>&1; then
    echo "🔧 Resetting PAM tally..."
    pam_tally2 --user root --reset 2>/dev/null || echo "⚠️  Could not reset PAM tally"
fi

echo
echo "=== Rollback Complete ==="
echo "✅ PAM configuration has been restored to previous state"
echo
echo "=== Next Steps ==="
echo "1. Try SSH login again"
echo "2. If still having issues, check:"
echo "   - SSH service status: systemctl status ssh"
echo "   - SSH configuration: sshd -t"
echo "   - PAM configuration: pam_tally2 --user root --reset"
echo "3. Consider rebooting if issues persist"
echo
echo "⚠️  IMPORTANT: Security hardening has been reverted!"
echo "   Re-apply hardening with caution after fixing the root cause." 