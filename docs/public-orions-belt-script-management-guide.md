# Orion's Belt Script Management Guide

## Overview

This guide provides community contributors with the standards and best practices for creating new hardening scripts for the Orion's Belt project. Following these guidelines will help streamline the review process and ensure your contribution can be integrated smoothly.

## Getting Started: The Contribution Workflow

Before writing any code, please review our `CONTRIBUTING.md` file, which outlines the full development and review process. All contributions should be submitted as Pull Requests to the `contrib` branch.

## Script Naming Convention

Since official Orion's Belt (OB) IDs are assigned by maintainers during the internal review process, all community submissions must use a temporary, descriptive name.

- **Format**: `UNASSIGNED_descriptive_name.yml`
- **Example**: `UNASSIGNED_secure_snmp.yml`
- **Location**: Place your script in the appropriate functional sub-directory within the `playbooks/` directory (e.g., `playbooks/os_hardening/network/`).

## Script Metadata Requirements

Every script must contain a metadata block at the top. This is critical for ensuring your script can be properly categorized and tested.

```yaml
# SPDX-License-Identifier: MIT
# Copyright (c) 2024 Your Name or Handle
#
# Part of the Orion's Belt project.
#
orions_belt:
  name: "Secure SNMP Configuration"              # Required, descriptive
  description: "Disables public SNMP community strings and configures secure settings" # Required, clear description
  category: "network"                             # Required: authentication|filesystem|network|boot|etc.
  tags:                                           # Recommended
    - "snmp"
    - "monitoring"
    - "security"
  version: "1.0.0"                                # Required, new scripts start at 1.0.0
  target_os: ["debian", "ubuntu", "rhel"]         # Required, list of supported OS
  target_arch: ["x86_64", "arm64"]                # Required, list of supported architectures
  framework_mappings:                             # Recommended
    - framework: "CIS"
      controls:
        - "CIS 3.12 - Ensure SNMP is configured securely" # Provide at least one high-level mapping
```

### Required Metadata Fields:

-   `name`: A human-readable name for the script.
-   `description`: A clear, one-sentence summary of what the script does.
-   `category`: The functional category (e.g., `network`, `authentication`).
-   `version`: New scripts should always start at `1.0.0`.
-   `target_os`: An array of operating systems the script is designed for and has been tested on.
-   `target_arch`: An array of CPU architectures the script supports.

### Recommended Metadata Fields:

-   `tags`: Add relevant tags to make the script easier to find and understand.
-   `framework_mappings`: Please provide a high-level mapping to at least one control from a known security framework (like CIS, NIST, or DISA). This provides valuable context for reviewers.

## Versioning Guidelines

Your new script submission should have its version set to `1.0.0`. The version will be incremented by maintainers as changes are made in subsequent releases. We follow Semantic Versioning (Major.Minor.Patch).

## Quality Assurance and Testing

To ensure the quality of your contribution, please:

-   **Test Thoroughly:** Test your script against the operating systems listed in the `target_os` metadata.
-   **Include Molecule Tests:** Whenever possible, include [Molecule](https://molecule.readthedocs.io/en/latest/) tests with your submission. This greatly accelerates the review and validation process.
-   **Write Clean Code:** Ensure your Ansible playbook is well-commented, easy to read, and follows standard Ansible best practices.

Thank you for contributing to the security of the open-source ecosystem! 