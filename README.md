<!-- PROJECT LOGO -->
<p align="center">
  <a href="https://github.com/IncudoLABS/orions-belt">
   <img src="images/OBelt.png" alt="Orion's Belt Logo" width="100">
  </a>
</p>

# Orion's Belt: A Framework for Principled, Automated System Hardening

Orion's Belt is an open-source collection of metadata-driven Ansible playbooks designed to automate system hardening and security compliance. Our goal is to provide a robust, community-vetted library of scripts mapped to established cybersecurity benchmarks like CIS, NIST CSF, and ISO 27001.

## Our Approach

While many configuration scripts exist, creating a truly robust, reliable, and adaptable hardening solution presents significant technical challenges. Standard approaches often result in brittle, platform-specific scripts that are difficult to maintain and verify. Our work on Orion's Belt is focused on overcoming these systemic issues through three key areas of investigation:

1.  **Developing a Flexible Hardening Architecture:** We are engineering a modular framework for Ansible that moves beyond static, hard-coded configurations. The primary technical challenge is designing an architecture that is truly platform-agnostic and remains idempotent across a vast and unpredictable range of target environments.

2.  **Systematic Translation of Controls to Code:** We are developing a systematic methodology to translate high-level security requirements into concrete, verifiable automation tasks. This involves creating a logical model to manage dependencies between controls and ensure that automated remediation is both effective and non-disruptive.

3.  **Investigating AI-Assisted Generation:** We are exploring novel techniques for leveraging AI to assist in the development of hardening playbooks, including new validation and verification strategies to overcome the inherent limitations of current AI models.

Our development is continuously guided by these core research principles.

## Key Features

*   **Framework-Aligned:** Each playbook is mapped to specific controls from well-known security frameworks, providing clear context for compliance.
*   **Metadata-Driven:** Scripts are self-documenting, with rich metadata defining their purpose, target systems, and version.
*   **Community-Vetted:** We use a transparent, multi-stage review process via our `contrib` branch to ensure high-quality contributions.
*   **Enterprise-Ready:** Contributions undergo a rigorous internal testing and enrichment pipeline to ensure they are robust and secure for enterprise use.
*   **Extensible by Design:** The project is structured to support hardening across different operating systems, network devices, and cloud environments.

## Getting Started

You can easily run any playbook using the interactive script included in the repository.

```bash
./run_playbooks.sh
```

This will launch a menu where you can browse and select playbooks by category to run against your target hosts (defined in `hosts`). For first-time use, copy the example configuration:

```bash
cp hosts.example hosts
cp config-example.yml config.yml
# Edit 'hosts' and 'config.yml' to match your environment
```

## How to Contribute

We welcome contributions from the community! Our development model is centered around the `contrib` branch, where new ideas and scripts are submitted and reviewed.

For detailed instructions on how to prepare your script, format your pull request, and navigate our review process, please read our **[CONTRIBUTING.md](CONTRIBUTING.md)** file.

## License

This project is licensed under the GPLv3 License. See the [LICENSE](LICENSE) file for details.