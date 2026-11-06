# ZAR+ SSH Hardening Evidence — 2026-10-30

Change identifier: `zar-ssh-hardening-20261030T115200Z`
Reload time: 2026-10-30 11:53:05 UTC
Result: **PASS — key-only non-root administration active; rollback not required**

## Pre-change state

```text
PermitRootLogin yes
PasswordAuthentication yes
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 6
LoginGraceTime 120
```

The server was receiving continuous automated password attempts against root and guessed usernames.

Verified administrative public-key fingerprint:

```text
SHA256:+kDNnHLgms8UaBoXDRuY1O6HcUQT5kTW9WM9QKs/ZdI  ED25519  zar-deploy
```

No private key was copied to the server, repository, evidence or chat.

## Rollback evidence

The pre-change SSH, authorized-key and sudo configuration was archived before mutation:

```text
server: /root/zar-ssh-hardening-20261030T115200Z/ssh-sudo-config.tar
local:  work/ssh-recovery-20261030T115200Z/ssh-sudo-config.tar
sha256: 4b8c8e3e1dc6e4358a114d9349e3afa9a7762ce77ad1d8edfb0e75d05eb5a2c1
mode:   0600 on server
```

One existing root session was kept open through reload and all new-connection tests, then deliberately closed after success.

## Administrative account

- Account: `zaradmin`
- UID/GID: `1001/1001`
- Groups: `zaradmin`, `sudo`
- Shell: `/bin/bash`
- Password: locked
- `.ssh` mode/owner: `0700`, `zaradmin:zaradmin`
- `authorized_keys` mode/owner: `0600`, `zaradmin:zaradmin`
- Key fingerprint matched the verified root deployment key.
- Sudoers drop-in: `/etc/sudoers.d/90-zaradmin`, mode `0440`
- Full `visudo -cf /etc/sudoers`: pass
- New login before sshd change: pass
- `sudo -n whoami`: `root`

## Active sshd policy

Drop-in:

```text
/etc/ssh/sshd_config.d/00-zar-hardening.conf
sha256: 47ad2541a5f842022ea21bd99d4cf2c28e1f22befe51cdf5089c458c13e1ac4d
mode: 0644 root:root
```

Effective values after reload:

```text
LoginGraceTime 30
MaxAuthTries 3
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey
```

The `00-` prefix is required because OpenSSH uses the first value obtained and the server has a `50-cloud-init.conf` drop-in.

## New-connection validation

- New `zaradmin` public-key connection: pass
- Non-interactive sudo: pass
- New root connection with the valid key: rejected
- Password-only `zaradmin` connection: rejected
- `sshd -t`: pass
- SSH service after reload: active
- PocketBase service during/after SSH change: active
- Preserved root rollback session remained functional until validation completed, then closed
- Local `zar-vps` alias updated from `root` to `zaradmin` and retested successfully

Journal evidence after reload showed the expected explicit root rejection for the controlled test. Internet scanning continued, but new attempts no longer reached password authentication under the effective policy.

## Remaining SSH/network work

- Add a separately reviewed rate-limit/fail2ban control for scanning and log volume.
- Review whether provider-specific emergency access is required.
- Review TCP/agent forwarding and source-IP restrictions after the operational access model is defined.
- Periodically rotate and review authorized keys.
- Preserve console/provider recovery access before any future SSH-port or firewall change.
