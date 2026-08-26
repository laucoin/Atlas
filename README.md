# Atlas 🪐

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

**Atlas** turns a single machine into a small, opinionated, self-hosted home cloud.

## This repository 📖

Atlas is a **single Debian node, described entirely in code**: one Ansible repository, no orchestrator. Full specification lives at [doc.laucoin.fr/atlas](https://doc.laucoin.fr/atlas); this repository holds only the implementation, built one role at a time against the [phased plan](https://doc.laucoin.fr/atlas/technical/implementation-plan).

### What's in the box

| Concern | Tooling                    |
| ------- | --------------------------- |
| Provisioning | Ansible, run by hand from the maintainer's workstation |
| Runtime | Docker (rootless), plus one privileged runtime for the reverse proxy |
| Secrets | Per-value encryption with an `age` key, never decrypted at rest on the host |

### Layout

```
atlas/
  inventory/            host and group variables — domain, timezone, sizes, image versions
  playbooks/
    site.yml            the everyday converge
    storage.yml         destructive; requires an explicit confirmation variable
  roles/
    base/                packages, time, locale, the admin account
    hardening/           SSH, firewall, kernel settings, access control, ban rules   [not yet implemented]
    ...                  see technical/ansible-conventions for the full role list    [not yet implemented]
```

Only `base` exists today. Roles land one stacked PR at a time, in the order set by the [implementation plan](https://doc.laucoin.fr/atlas/technical/implementation-plan).

## How to install and use it? ⚙️

### Prerequisites & runtime versions

| Requirement | Notes |
| ----------- | ----- |
| A fresh **Debian stable** install | SSH reachable; everything after that is Ansible's |
| **Ansible** on the workstation | Runs the converge; nothing is installed on the host beyond what a role declares |
| **age** on the workstation | Decrypts secrets during a converge; the key never reaches the host |
| **Docker** on the host | Installed and configured by the (not yet implemented) `docker` role |
| **gh** on the workstation | Used to open the stacked pull requests described in AGENTS.md |

### Configuration variables

Atlas has no `.env` file; configuration is inventory variables and per-value encrypted secrets.

| Where | Holds | Default |
| ----- | ----- | ------- |
| `inventory/hosts.yml` | The `atlas` host declaration | — |
| `inventory/host_vars/atlas/main.yml` | `ansible_host` (the machine's real address) and `ansible_user` (bootstrap connects as `root`) | `CHANGE_ME` / `root` |
| `inventory/group_vars/all/main.yml` | `atlas_timezone`, `atlas_locale`, `atlas_admin_user`, `atlas_admin_ssh_public_key`, `atlas_ssh_port` (documentation only — see below) | `Europe/Paris`, `en_US.UTF-8`, `atlas`, `CHANGE_ME`, `222` |
| `inventory/group_vars/all/images.yml` | Every image tag and digest | not yet created |
| `roles/*/defaults` | Sensible per-role defaults, overridable | see each role |
| Encrypted values | Secrets, encrypted per value with an age key | not yet needed by any implemented role |

### Local setup

1. Install a fresh Debian stable machine; note its address and confirm SSH is reachable.
2. On the workstation, install Ansible and the collections this repository needs: `ansible-galaxy collection install -r requirements.yml`.
3. Set `ansible_host` in `inventory/host_vars/atlas/main.yml` to the machine's real address.
4. Set `atlas_admin_ssh_public_key` in `inventory/group_vars/all/main.yml` to the maintainer's workstation public key.
5. The `age` key that will decrypt future secrets stays on the workstation only; it is never copied to Atlas, and nothing is decrypted at rest on the host.
6. From the internet, SSH reaches Atlas on the gateway's external port (`atlas_ssh_port`, `222`), which the gateway translates to `22` before it reaches the host — sshd itself is never configured with `222`. `ssh -p 222 atlas@<domain>` from off the local network; `ssh -p 22 atlas@<host>` (or just the default port) from the workstation's own LAN, gateway rules depending.

### Build, run, verify

There is no automated test suite, by choice — idempotency is enforced by how roles are written (see `technical/ansible-conventions`), and a clean second converge is the proof.

```bash
ansible-playbook playbooks/site.yml --check --diff   # review first, always
ansible-playbook playbooks/site.yml                  # apply
ansible-playbook playbooks/site.yml                  # re-run immediately: must report zero changes
ansible-playbook playbooks/site.yml --tags base       # converge one role only
```

## Contributing 💻

TODO

## Contributors 🧑‍💻

TODO (all contributor)

## License

Distributed under the MIT License. See [`LICENSE`](./LICENSE) for details.
