# nerdygriffin.proxmox_repositories

Manage **Proxmox VE** and **Ceph** apt repositories in the modern deb822
(`.sources`) format, and optionally remove the **"No valid subscription"**
web-UI nag — keeping both correct and idempotent across upgrades.

On a fresh Proxmox VE install the *enterprise* PVE and Ceph repos are enabled
but `apt update` fails (HTTP 401) without a subscription key, and the web UI
shows a subscription pop-up on every login. This role switches an unsubscribed
host to the no-subscription channel (or any channel you choose) and suppresses
the nag in a way that survives `proxmox-widget-toolkit` upgrades.

Repository definitions follow the Proxmox VE 9 documentation:
<https://pve.proxmox.com/pve-docs/chapter-sysadmin.html>

## What it does

- Writes deb822 `.sources` files via the native `ansible.builtin.deb822_repository`
  module (no hand-rolled templates), using the `proxmox-archive-keyring.gpg`
  that Proxmox already ships:
  - `proxmox.sources` — PVE no-subscription (enabled by default)
  - `pve-enterprise.sources` — PVE enterprise (`Enabled: no` by default)
  - `pve-test.sources` — PVE test (disabled)
  - `ceph.sources` / `ceph-enterprise.sources` / `ceph-test.sources` — Ceph
    channels, all disabled by default (built for clusters; the role takes
    ownership of the installer's `ceph.sources`)
- Runs `apt update` after any repository change.
- Optionally removes the "No valid subscription" nag by patching `proxmoxlib.js`
  and installing an APT `DPkg::Post-Invoke` hook that re-applies the patch after
  `proxmox-widget-toolkit` upgrades. A `proxmoxlib.js.orig` backup is kept.

## Requirements

- Proxmox VE host (Debian; the role asserts `/usr/bin/pveversion` exists).
- ansible-core >= 2.15 (for `deb822_repository`).
- Connection as `root` (or with privilege escalation) to write `/etc/apt` and
  `/usr/share`.

## Role Variables

| Variable | Default | Description |
|---|---|---|
| `proxmox_repositories_release` | `{{ ansible_distribution_release }}` | Debian suite (`trixie` for PVE 9, `bookworm` for PVE 8). |
| `proxmox_repositories_keyring` | `/usr/share/keyrings/proxmox-archive-keyring.gpg` | `Signed-By` keyring. |
| `proxmox_repositories_pve_enterprise_enabled` | `false` | Enable the PVE enterprise repo. |
| `proxmox_repositories_pve_no_subscription_enabled` | `true` | Enable the PVE no-subscription repo. |
| `proxmox_repositories_pve_test_enabled` | `false` | Enable the PVE test repo. |
| `proxmox_repositories_ceph_release` | `squid` | Ceph repo version (`squid`, `tentacle`, …). |
| `proxmox_repositories_ceph_no_subscription_enabled` | `false` | Enable Ceph no-subscription. |
| `proxmox_repositories_ceph_enterprise_enabled` | `false` | Enable Ceph enterprise. |
| `proxmox_repositories_ceph_test_enabled` | `false` | Enable Ceph test. |
| `proxmox_repositories_update_cache` | `true` | Run `apt update` after changes. |
| `proxmox_repositories_remove_subscription_nag` | `true` | Patch out the web-UI nag. |
| `proxmox_repositories_nag_script_path` | `/usr/local/bin/pve-no-subscription-nag.sh` | Where the patch script is installed. |
| `proxmox_repositories_remove_subscription_nag_mobile` | `false` | Reserved; the PVE 9 Yew/WASM mobile UI nag is not yet patched. |

> Set the `*_enabled` toggles; do not override the internal
> `proxmox_repositories__pve` / `proxmox_repositories__ceph` lists in `vars/`.

## Example Playbook

```yaml
- name: Proxmox post-install — repositories + subscription nag
  hosts: proxmox
  become: false        # connecting as root
  roles:
    - nerdygriffin.proxmox_repositories
```

Hyper-converged Ceph cluster node (enable the no-subscription Ceph repo):

```yaml
- hosts: proxmox_cluster
  vars:
    proxmox_repositories_ceph_release: tentacle
    proxmox_repositories_ceph_no_subscription_enabled: true
  roles:
    - nerdygriffin.proxmox_repositories
```

## Notes

- After the nag patch, do a **hard browser refresh** to drop the cached
  `proxmoxlib.js`.
- Patching a packaged file is a homelab convenience, not vendor-supported. To
  revert: restore `proxmoxlib.js.orig`, remove
  `/etc/apt/apt.conf.d/86-pve-no-subscription-nag`, and
  `apt-get install --reinstall proxmox-widget-toolkit`.
- The no-subscription channel is not recommended by Proxmox for production; buy
  a subscription to support the project where appropriate.

## License

MIT
