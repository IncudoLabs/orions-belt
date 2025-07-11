# Configuration System Usage Examples

## Overview

The Orion's Belt project uses a hierarchical configuration system with three levels:

1. **Base Configuration** (`config.yml`) - Default values for all environments
2. **Environment-Specific Overrides** (`config-{environment}.yml`) - Environment-specific values
3. **Secure Configuration** (`vault.yml`) - Encrypted sensitive data

## Configuration Hierarchy

Values are loaded in this order, with later files overriding earlier ones:

```
config.yml (base) → config-{environment}.yml (overrides) → vault.yml (secrets)
```

## Usage Examples

### 1. Running with Different Environments

#### Command Line Usage
```bash
# Run with production environment (default)
./run_playbooks.sh

# Run with specific environment
./run_playbooks.sh production
./run_playbooks.sh development
./run_playbooks.sh staging

# Set environment via environment variable
export ANSIBLE_ENVIRONMENT=development
./run_playbooks.sh
```

#### Interactive Menu Usage
```bash
./run_playbooks.sh
# Then select "3. Configuration Management" → "1. Set Environment"
```

### 2. Configuration Values by Environment

#### Network Configuration
```yaml
# config.yml (base)
network:
  default_local_subnet: "192.168.1.0/24"

# config-production.yml (override)
network:
  default_local_subnet: "10.100.0.0/24"  # Overrides base

# config-development.yml (override)
network:
  default_local_subnet: "192.168.1.0/24"  # Same as base
```

#### Security Settings
```yaml
# config.yml (base)
security_hardening:
  firewall:
    default_policy: "drop"
    rate_limit_ssh: true
    ssh_rate_limit: "5/minute"

# config-production.yml (override)
security_hardening:
  firewall:
    ssh_rate_limit: "3/minute"  # Stricter in production

# config-development.yml (override)
security_hardening:
  firewall:
    default_policy: "accept"  # More permissive in development
    rate_limit_ssh: false     # No rate limiting in development
```

### 3. Using Configuration in Playbooks

#### Method 1: Direct Variable Reference
```yaml
---
- name: Configure Firewall
  hosts: all
  become: yes
  
  vars_files:
    - "config.yml"
    - "config-{{ environment | default('production') }}.yml"
  
  tasks:
    - name: Configure nftables
      template:
        src: nftables.conf.j2
        dest: /etc/nftables.conf
        vars:
          local_subnet: "{{ network.default_local_subnet }}"
          ssh_rate_limit: "{{ security_hardening.firewall.ssh_rate_limit }}"
```

#### Method 2: Using Configuration Loader
```yaml
---
- name: Install Wazuh Agent
  hosts: all
  become: yes
  
  pre_tasks:
    - name: Load configuration
      include_tasks: config_loader.yml
      run_once: true
      delegate_to: localhost
  
  tasks:
    - name: Install Wazuh agent
      package:
        name: wazuh-agent
        state: present
      
    - name: Configure Wazuh agent
      template:
        src: ossec.conf.j2
        dest: /var/ossec/etc/ossec.conf
        vars:
          manager_host: "{{ wazuh.agent.manager_host }}"
          default_group: "{{ wazuh.agent.default_group }}"
```

### 4. Environment-Specific Behavior

#### Production Environment
- **Security**: Maximum security settings
- **Monitoring**: Full monitoring and alerting
- **Backups**: Encrypted backups enabled
- **Updates**: Manual updates only
- **Logging**: Extended retention (365 days)

#### Staging Environment
- **Security**: Moderate security settings
- **Monitoring**: Basic monitoring
- **Backups**: Unencrypted backups
- **Updates**: Weekly security updates
- **Logging**: Moderate retention (90 days)

#### Development Environment
- **Security**: Relaxed security for development
- **Monitoring**: Disabled
- **Backups**: Disabled
- **Updates**: Daily auto-updates
- **Logging**: Minimal retention (30 days)

### 5. Testing Configuration

```bash
# Test current configuration
./run_playbooks.sh
# Select "3. Configuration Management" → "3. Test Configuration"

# This will show:
# ✓ config.yml
# ✓ config-production.yml (or development/staging)
# ✓ vault.yml (if exists)
```

### 6. Adding New Configuration Variables

#### Step 1: Add to Base Config
```yaml
# config.yml
new_feature:
  enabled: false
  timeout: 30
  retries: 3
```

#### Step 2: Override in Environment Configs
```yaml
# config-production.yml
new_feature:
  enabled: true
  timeout: 60
  retries: 5

# config-development.yml
new_feature:
  enabled: true
  timeout: 10
  retries: 1
```

#### Step 3: Use in Playbooks
```yaml
- name: Configure new feature
  template:
    src: feature.conf.j2
    dest: /etc/feature.conf
    vars:
      enabled: "{{ new_feature.enabled }}"
      timeout: "{{ new_feature.timeout }}"
      retries: "{{ new_feature.retries }}"
```

## Best Practices

1. **Always specify environment** when running playbooks
2. **Test in development first** before staging/production
3. **Use descriptive variable names** in configuration
4. **Document configuration changes** in commit messages
5. **Keep sensitive data in vault.yml** only
6. **Use environment variables** for CI/CD pipelines 