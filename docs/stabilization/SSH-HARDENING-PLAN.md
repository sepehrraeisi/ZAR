# ZAR+ SSH Hardening Change Plan

Status: prepared; execute as a separate change from PocketBase/service hardening.

## Objective

Replace direct root/password administration with a named non-root account using the already-verified ED25519 deployment key and non-interactive `sudo`, while keeping a tested rollback session open.

Target state:

```text
administrative user: zaradmin
public-key authentication: enabled
password authentication: disabled
keyboard-interactive authentication: disabled
direct root login: disabled
maximum authentication attempts: 3
login grace time: 30 seconds
```

## Verified starting state — 2026-10-30

- SSH port: `22`
- `PermitRootLogin yes`
- `PasswordAuthentication yes`
- `KbdInteractiveAuthentication no`
- `PubkeyAuthentication yes`
- `MaxAuthTries 6`
- `LoginGraceTime 120`
- Current local SSH alias uses `root` and `~/.ssh/zar_vps` with `IdentitiesOnly yes`.
- Root authorized-key fingerprint: `SHA256:+kDNnHLgms8UaBoXDRuY1O6HcUQT5kTW9WM9QKs/ZdI` (ED25519, comment `zar-deploy`).
- `zaradmin` did not exist at capture.

No private key material is copied to the server, Git, documentation or chat.

## Safety sequence

1. Archive current `sshd_config`, all drop-ins, root authorized keys and sudoers configuration to a mode-`0600` rollback set; hash and copy it off-server.
2. Create `zaradmin` with a home directory, `/bin/bash` and membership in `sudo`.
3. Copy only the existing public authorized-key file into `/home/zaradmin/.ssh/authorized_keys`; enforce directory `0700`, file `0600` and `zaradmin:zaradmin` ownership.
4. Add a dedicated mode-`0440` sudoers drop-in for `zaradmin`; validate all sudoers files with `visudo -cf`.
5. Before changing sshd, open a new `zaradmin` session with the expected key and prove `sudo -n true` and `sudo -n whoami` succeed.
6. Open and keep one existing root SSH session alive for rollback.
7. Install `/etc/ssh/sshd_config.d/00-zar-hardening.conf`. The `00-` prefix is intentional because OpenSSH uses the first value obtained and the current cloud-init drop-in is `50-cloud-init.conf`.
8. Validate with `sshd -t` and confirm effective values with `sshd -T` before reload.
9. Reload, not restart, the SSH service.
10. In separate new connections, prove:
    - `zaradmin` public-key login succeeds;
    - `sudo -n` succeeds;
    - a new root login fails;
    - password-only authentication fails;
    - effective sshd values match the target.
11. Close the preserved root session only after every test passes.

## Intended drop-in

```text
PermitRootLogin no
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
AuthenticationMethods publickey
MaxAuthTries 3
LoginGraceTime 30
```

This change intentionally does not alter the SSH port, firewall, fail2ban, TCP forwarding or provider-specific accounts. Those require separate evidence.

## Stop conditions

- The public-key fingerprint differs from the recorded value.
- `zaradmin` login or non-interactive sudo fails before sshd changes.
- `visudo -cf` or `sshd -t` fails.
- Effective `sshd -T` values differ from the target.
- The preserved root rollback session disconnects before new-login tests pass.
- Any new SSH connection behaves unexpectedly after reload.

## Rollback

From the preserved root session:

1. Move `00-zar-hardening.conf` into the timestamped quarantine directory; do not delete evidence.
2. Restore the captured SSH/sudo configuration if any pre-existing file was changed.
3. Run `sshd -t`.
4. Reload SSH.
5. Confirm a new key-authenticated root connection succeeds.
6. Keep `zaradmin` disabled or intact for investigation; do not recursively delete its home during the incident window.
7. Record the failure and do not retry without a revised plan.

## Success evidence

Record UTC stop/start/reload timestamps, config archive hash, public-key fingerprint, effective sshd values, new-user login/sudo result, root/password rejection result and journal warnings. Do not record private keys, passwords or full authorized-key lines.
