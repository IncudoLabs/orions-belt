<!-- PROJECT LOGO -->
<p align="center">
  <a href="https://github.com/IncudoLABS/orions-belt">
   <img src="images/OBelt.png" alt="Orion's Belt Logo" width="100">
  </a>
</p>

# Orion's Belt: A Framework for Principled, Automated System Hardening

Orion's Belt is an open-source collection of metadata-driven Ansible playbooks designed to automate system hardening and security compliance. Our goal is to provide a robust, community-vetted library of scripts mapped to established cybersecurity benchmarks like CIS, NIST CSF, and ISO 27001.

## Table of Contents

- [Our Approach](#our-approach)
- [Key Features](#key-features)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Private Configuration](#private-configuration-inventory-config-and-custom-playbooks)
- [License](#license)

## Our Approach

While many configuration scripts exist, creating a truly robust, reliable, and adaptable hardening solution presents significant technical challenges. Standard approaches often result in brittle, platform-specific scripts that are difficult to maintain and verify. Our work on Orion's Belt is focused on overcoming these systemic issues through three key areas of investigation:

1.  **Developing a Flexible Hardening Architecture:** We are engineering a modular framework for Ansible that moves beyond static, hard-coded configurations. The primary technical challenge is designing an architecture that is truly platform-agnostic and remains idempotent across a vast and unpredictable range of target environments.

2.  **Systematic Translation of Controls to Code:** We are developing a systematic methodology to translate high-level security requirements into concrete, verifiable automation tasks. This involves creating a logical model to manage dependencies between controls and ensure that automated remediation is both effective and non-disruptive.

3.  **Investigating AI-Assisted Generation:** We are exploring novel techniques for leveraging AI to assist in the development of hardening playbooks, including new validation and verification strategies to overcome the inherent limitations of current AI models.

Our development is continuously guided by these core research principles.

[Back to top](#table-of-contents)

## Key Features

- **Framework-Aligned:** Each playbook is mapped to specific controls from well-known security frameworks, providing clear context for compliance.
- **Metadata-Driven:** Scripts are self-documenting, with rich metadata defining their purpose, target systems, and version.
- **Community-Vetted:** We use a transparent, multi-stage review process via our `contrib` branch to ensure high-quality contributions.
- **Enterprise-Ready:** Contributions undergo a rigorous internal testing and enrichment pipeline to ensure they are robust and secure for enterprise use.
- **Extensible by Design:** The project is structured to support hardening across different operating systems, network devices, and cloud environments.

[Back to top](#table-of-contents)

## Getting Started

Orion's Belt is designed to be used with a separate, private repository where you manage your sensitive and environment-specific files, such as your inventory, group variables, and secrets. This approach keeps your private data secure while allowing you to keep the main Orion's Belt codebase up to date.

The core principle of this design is that **playbooks are independent**. You can run any playbook directly with the standard `ansible-playbook` command, and Ansible's native `group_vars` and inventory logic will automatically load the correct configuration.

The `run_playbooks.sh` script is provided as a **convenience**, offering a user-friendly menu to help you select playbooks and targets, but it is **not a dependency**.

For detailed instructions on how to set up your private repository, structure your inventory, and securely manage secrets, please see our comprehensive guide:
- **[Private Asset Management Guide](private/README.md)**

A high-level overview of the setup is:
1.  Create a private Git repository for your inventory and variables.
2.  Use the `inventory.example` directory as a blueprint for your structure.
3.  Run the `private/setup_env.sh` script to git clone and create a symbolic link from your private repo to the `inventory/` directory in this project.
4.  Run playbooks using the `run_playbooks.sh` menu or directly with the `ansible-playbook` command.

[Back to top](#table-of-contents)

## Private Configuration (Inventory, Config and Custom Playbooks)

Orion's Belt is designed to work with a separate, private repository to manage your sensitive and environment-specific files, such as inventory hosts, custom playbooks, and configurations. This keeps your private data secure while allowing you to keep the main Orion's Belt codebase up to date.

**A note on secrets:** While this method is ideal for inventory and configuration, special care must be taken with secrets. Do not store sensitive data like Ansible Vault files in the public `orions-belt` repository. The private repository workflow provides a secure, industry-standard method for managing secrets.

For detailed instructions on how to set up your private repository and securely manage secrets using this workflow, please see the guide here:
- **[Private Asset Management Guide](private/README.md)**

[Back to top](#table-of-contents)

## How to Contribute

We welcome contributions from the community! Our development model is centered around the `contrib` branch, where new ideas and scripts are submitted and reviewed.

For detailed instructions on how to prepare your script, format your pull request, and navigate our review process, please read our **[CONTRIBUTING.md](CONTRIBUTING.md)** file.

[Back to top](#table-of-contents)

## License

This project is licensed under the GPLv3 License. See the [LICENSE](LICENSE) file for details.

[Back to top](#table-of-contents)
