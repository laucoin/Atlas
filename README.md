# Atlas 🪐

![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)

**Atlas** turns a single machine into a small, opinionated, self-hosted home cloud.

## This repository 📖

Atlas is a **single Debian node, described entirely in code**: one Ansible repository, no orchestrator. Full specification lives at [doc.laucoin.fr/atlas](https://doc.laucoin.fr/atlas); this repository holds only the implementation, built one role at a time against the [phased plan](https://doc.laucoin.fr/atlas/technical/implementation-plan).

### What's in the box

| Concern | Tooling                    |
| ------- | --------------------------- |
| Provisioning | Ansible, run by hand from the maintainer's workstation |
| Runtime | Docker, rootless, one daemon under one service user — including the reverse proxy |
| Secrets | Per-value encryption with an `age` key, never decrypted at rest on the host |

### Layout

```
atlas/
  inventory/            host and group variables — domain, timezone, sizes, image versions
  playbooks/
    site.yml            the everyday converge
    storage.yml         provisioning; requires an explicit confirmation variable, never shrinks
  roles/
    base/                packages, time, locale, the admin account
    hardening/           SSH, firewall, kernel settings, access control, ban rules, unattended updates
    storage/             volume assertion (site.yml) and reconciliation (storage.yml)
    docker/              the rootless runtime, the service user, identity mapping
    shell/               zsh, Starship, vim, port-inspection and volume-usage helpers
```

**Phase 1 / Foundation is complete**: `base`, `hardening`, `storage`, `docker` and `shell` all exist. Phase 2 (`traefik`, `authelia`, `theme`) is next, in the order set by the [implementation plan](https://doc.laucoin.fr/atlas/technical/implementation-plan).

## How to install and use it? ⚙️

### Prerequisites & runtime versions

| Requirement | Notes |
| ----------- | ----- |
| A fresh **Debian stable** install | SSH reachable; everything after that is Ansible's |
| **Ansible** on the workstation | Runs the converge; nothing is installed on the host beyond what a role declares |
| **age** on the workstation | Decrypts secrets during a converge; the key never reaches the host |
| **Docker** on the host | Installed and configured by the `docker` role, rootless under its own service user |
| **gh** on the workstation | Used to open the stacked pull requests described in AGENTS.md |

### Configuration variables

Atlas has no `.env` file; configuration is inventory variables and per-value encrypted secrets.

| Where | Holds | Default |
| ----- | ----- | ------- |
| `inventory/hosts.yml` | The `atlas` host declaration | — |
| `inventory/host_vars/atlas/main.yml` | `ansible_host` (the machine's real address) and `ansible_user` (bootstrap connects as `root`) | `CHANGE_ME` / `root` |
| `inventory/group_vars/all/main.yml` | `atlas_timezone`, `atlas_locale`, `atlas_admin_user`, `atlas_admin_ssh_public_key` | `Europe/Paris`, `en_US.UTF-8`, `atlas`, `CHANGE_ME` |
| `inventory/group_vars/all/images.yml` | Every image tag and digest | not yet created |
| `roles/storage/defaults/main.yml` | `storage_volume_group` and the five managed volumes (mount, size) | `vg_atlas`; see the role for the full list |
| `roles/docker/defaults/main.yml` | `docker_service_user` and its subordinate UID/GID range | `atlas-docker`; `100000`-`165535` |
| `roles/shell/defaults/main.yml` | `shell_targets` (admin + root) and the pinned Starship version | see the role |
| `roles/*/defaults` | Sensible per-role defaults, overridable | see each role |
| Encrypted values | Secrets, encrypted per value with an age key | not yet needed by any implemented role |

### Local setup

1. Install a fresh Debian stable machine; note its address and confirm SSH is reachable.
2. On the workstation, install Ansible and the collections this repository needs: `ansible-galaxy collection install -r requirements.yml`.
3. Set `ansible_host` in `inventory/host_vars/atlas/main.yml` to the machine's real address.
4. Set `atlas_admin_ssh_public_key` in `inventory/group_vars/all/main.yml` to the maintainer's workstation public key.
5. The `age` key that will decrypt future secrets stays on the workstation only; it is never copied to Atlas, and nothing is decrypted at rest on the host.

### Build, run, verify

There is no automated test suite, by choice — idempotency is enforced by how roles are written (see `technical/ansible-conventions`), and a clean second converge is the proof.

```bash
ansible-playbook playbooks/site.yml --check --diff   # review first, always
ansible-playbook playbooks/site.yml                  # apply
ansible-playbook playbooks/site.yml                  # re-run immediately: must report zero changes
ansible-playbook playbooks/site.yml --tags docker     # converge one role only

# Storage never changes as part of the above — site.yml only asserts it.
# Provisioning is separate and requires explicit confirmation:
ansible-playbook playbooks/storage.yml --check --diff
ansible-playbook playbooks/storage.yml -e storage_confirm=true
```

## Contributing 💻

TODO

## Contributors 🧑‍💻

TODO (all contributor)

## License

Distributed under the MIT License. See [`LICENSE`](./LICENSE) for details.
