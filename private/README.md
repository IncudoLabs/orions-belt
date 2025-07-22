# Private Asset Management for Orion's Belt

This directory and the `setup_env.sh` script provide a structured way to manage private configuration files (inventory, playbooks, etc.) alongside the public Orion's Belt repository.

The primary goal is to keep sensitive and environment-specific files in a separate, private Git repository while seamlessly integrating them with the main Orion's Belt application. This allows you to update the public `orions-belt` repository without overwriting or exposing your private configurations.

## How It Works

The `setup_env.sh` script automates the process of cloning your private repository and linking your private files into the correct locations within the `orions-belt` directory structure.

The script works by creating a **symbolic link** from your private repository to the `inventory/` directory in `orions-belt`. This single link makes your entire private inventory structure—including `hosts`, `group_vars`, and `host_vars`—available to Ansible.

The `Custom/` directory, which is intended for your private playbooks, is also linked.

### A Note on Playbook Execution: The Script is a Convenience, Not a Dependency

Orion's Belt is designed to follow standard Ansible practices. Ansible's core engine is responsible for finding and loading all variables from your `inventory/` and `group_vars/` directories, ensuring a robust, predictable, and well-documented configuration process.

**This has a significant benefit: your playbooks are now completely independent.**

-   **You can run any playbook directly** using the standard `ansible-playbook` command.
-   The `run_playbooks.sh` script is provided as a helpful **launcher with a user-friendly menu**, but it is no longer required for the playbooks to function correctly.

This design decouples the playbook logic from the execution script, making the entire framework more robust, predictable, and easier to maintain.

## Setup Instructions

1.  **Configure Environment:**
    The script uses a `.env` file for configuration, located in the root of the `orions-belt` repository.
    
    First, copy the example file:
    ```bash
    cd /orion/orions-belt
    cp .env.example .env
    ```

2.  **Edit `.env` File (IMPORTANT):**
    Open the newly created `.env` file and set the following variables:
    - `ORIONS_BELT_DIR`: The absolute path to your `orions-belt` project root.
    - `PRIVATE_REPO_DIR`: The absolute path where the script should clone your private repository. This should be within the `private/` directory to remain ignored by git.
    - `PRIVATE_REPO_URL`: The SSH or HTTPS URL for your private git repository.

3.  **Run the Interactive Script:**
    Execute the setup script from this `private/` directory:
    ```bash
    cd /orion/orions-belt/private
    bash ./setup_env.sh
    ```
    The script will present you with two choices:
    - **Option 1: Clone and Link:** This will first clone the repository from `PRIVATE_REPO_URL` into the `PRIVATE_REPO_DIR`. If the directory already exists, it will ask for confirmation before removing it. After cloning, it will create the symbolic links.
    - **Option 2: Link Only:** This option skips the cloning step and proceeds directly to creating the symbolic links. Use this if you have already cloned the repository or are managing it manually.

## Managing Secrets with Ansible Vault

The recommended way to handle secrets (passwords, API keys) is with Ansible Vault. This feature allows you to encrypt sensitive data directly within your repository.

### The Private Repository Workflow (Recommended)

This project is designed to facilitate a secure and standard industry practice: storing your encrypted `vault.yml` file within your private configuration repository.

1.  **Store Your Vault File**: Place your `ansible-vault` encrypted file(s) in the `group_vars/all/` directory inside your **private** repository. For example: `.../your-private-repo/group_vars/all/vault.yml`.

2.  **Automated Symlinking**: The `setup_env.sh` script symlinks the entire `group_vars` directory from your private repository into the `orions-belt` project. This action makes your `vault.yml` file (and any other group variables) available to Ansible without exposing them in the public repository.

**CRITICAL SECURITY NOTICE:**
-   **DO NOT** commit your `vault.yml` file or any file containing secrets to the public `orions-belt` repository or any public forks.
-   Your vault file should **ONLY** be committed to your private repository. The `.gitignore` file in the main project is configured to prevent accidental commits of these linked files.

### Why This is an Industry Standard

This approach of separating logic from secrets is a cornerstone of modern DevOps and GitOps practices. It allows you to:
-   **Keep Public Code Clean**: The public automation logic in Orion's Belt remains free of any sensitive data.
-   **Version Control Secrets Securely**: You get the benefits of version control (history, branching) for your secrets without exposing them publicly.
-   **Maintain a Single Source of Truth**: Your private repository becomes the single source of truth for your environment's specific configuration and secrets, while the public repo provides the tooling.

By following this model, you can maintain a clean separation between public code and private configuration, making your Orion's Belt deployment both secure and easy to maintain. 