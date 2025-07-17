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
#!/bin/bash

# This script sets up the private configuration for Orion's Belt Usage
# It can clone a private repository and create symbolic links from it
# to the main project directories.

# --- Configuration ---
# The script sources its configuration from a .env file located in the
# parent directory of this script's location.
ENV_FILE="$(dirname "$0")/../.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: Configuration file not found!"
    echo "Please copy '.env.example' to '.env' in the '/orion/orions-belt' directory and configure it."
    exit 1
fi

# Load environment variables
export $(grep -v '^#' "$ENV_FILE" | xargs)

# --- Validation ---
if [ -z "$ORIONS_BELT_DIR" ] || [ -z "$PRIVATE_REPO_DIR" ] || [ -z "$PRIVATE_REPO_URL" ]; then
    echo "ERROR: One or more required variables (ORIONS_BELT_DIR, PRIVATE_REPO_DIR, PRIVATE_REPO_URL) are not set in your .env file."
    exit 1
fi

# --- Functions ---

clone_repo() {
    echo "--- Cloning Private Repository ---"
    if [ -d "$PRIVATE_REPO_DIR" ]; then
        if [ "$(ls -A $PRIVATE_REPO_DIR)" ]; then
            echo "WARN: Destination directory $PRIVATE_REPO_DIR already exists and is not empty."
            read -p "Do you want to remove it and re-clone? (y/N): " choice
            case "$choice" in
              y|Y )
                echo "Removing existing directory..."
                rm -rf "$PRIVATE_REPO_DIR"
                ;;
              * )
                echo "Skipping clone. Will proceed with linking files from the existing directory."
                return
                ;;
            esac
        fi
    fi

    echo "Cloning from $PRIVATE_REPO_URL into $PRIVATE_REPO_DIR..."
    git clone "$PRIVATE_REPO_URL" "$PRIVATE_REPO_DIR"
    if [ $? -ne 0 ]; then
        echo "ERROR: Git clone failed. Please check the URL and your permissions."
        exit 1
    fi
    echo "--- Clone complete ---"
    echo ""
}

link_files() {
    local src_dir_name=$1
    local src_dir_path="$PRIVATE_REPO_DIR/$src_dir_name"
    local dest_dir_path="$ORIONS_BELT_DIR/$src_dir_name"

    echo "--- Linking files from $src_dir_path to $dest_dir_path ---"

    if [ ! -d "$src_dir_path" ]; then
        echo "Source directory $src_dir_path not found. Skipping."
        return
    fi

    if [ ! -d "$dest_dir_path" ]; then
        echo "Destination directory $dest_dir_path not found. Creating it."
        mkdir -p "$dest_dir_path"
    fi

    for src_file_path in "$src_dir_path"/*; do
        if [ -f "$src_file_path" ]; then
            filename=$(basename "$src_file_path")
            dest_link_path="$dest_dir_path/$filename"

            if [ -e "$dest_link_path" ] || [ -L "$dest_link_path" ]; then
                echo "Removing existing file/link at: $dest_link_path"
                rm -f "$dest_link_path"
            fi

            echo "Creating link: $dest_link_path -> $src_file_path"
            ln -s "$src_file_path" "$dest_link_path"
        fi
    done
    echo "--- Finished linking for $src_dir_name ---"
    echo ""
}

# --- Main Logic ---

echo "Orion's Belt Setup Environment for Private inventory, config, and Custom"
echo "--------------------------"
echo "What would you like to do?"
echo "  1) Clone private repo AND create symbolic links"
echo "  2) Create symbolic links ONLY (assumes repo is already cloned)"
read -p "Enter your choice (1 or 2): " main_choice

case "$main_choice" in
  1)
    clone_repo
    link_files "inventory"
    link_files "config"
    link_files "Custom"
    echo "All tasks completed successfully."
    ;;
  2)
    echo "Skipping clone, proceeding with linking..."
    link_files "inventory"
    link_files "config"
    link_files "Custom"
    echo "All symbolic links have been created successfully."
    ;;
  *)
    echo "Invalid choice. Exiting."
    exit 1
    ;;
esac 