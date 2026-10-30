# Temporary Pre-Customer Recovery Exception

Decision date: 2026-10-30 (Asia/Tehran)
Review deadline: 2026-11-30 or before the first customer/real financial dataset, whichever occurs first.
Status: temporarily accepted by the product owner in this work session.

## Context

The product owner confirmed that ZAR+ currently has no customers, no planned customer onboarding and no separate server or approved cloud destination for backups. The owner requested that stabilization continue while this infrastructure is unavailable.

This exception is deliberately narrow. It permits the tested containment migrations to proceed in the current pre-customer environment; it does not approve launching the product with same-server-only backups.

## Temporarily accepted risk

- Automated backups remain on the production server with seven-day retention.
- The secondary recovery copy is on the owner's Windows computer, not in an independent cloud account or second physical medium.
- The local encrypted bundle key is protected by Windows DPAPI and therefore depends on the same Windows user and Windows installation.
- Loss of both the server and this Windows computer could still cause permanent data loss.
- No customer-facing RPO, RTO or availability commitment exists yet.

## Compensating controls in place

- Production has no customers and no approved real customer dataset.
- A fresh SQLite `.backup` was captured immediately before containment work:
  `/backups/zar-pre-containment-20261030T114150Z.db`.
- Database SHA-256: `a0da2edc42d46ddff0737ccaa4e40be7f5b141b3be92188c7cbae00828948907`.
- The full recovery set includes database, all production migrations, Caddy/systemd/backup configuration and the exact PocketBase binary.
- The recovery set is encrypted with GnuPG AES-256 on the owner's Windows computer.
- Bundle SHA-256: `3b3d24d964217a1ba7580f5086101e7fc73f625a44a14710e611029bb95059e6`.
- The protected key uses Windows DPAPI CurrentUser scope; the directory ACL permits only the owner and SYSTEM.
- The bundle was decrypted immediately after creation and all 10 manifest hashes matched.
- The fresh database copy passed PocketBase health, SQLite integrity, migration and all eight domain-table reconciliation checks.
- Production changes are limited to the two reviewed deletion-lock migrations; unrelated hardening is excluded from the same window.

Local protected recovery location:

```text
C:\Users\simin\Documents\Codex\ZAR-Recovery
```

Do not copy the `.key.dpapi` content into Git, chat, tickets or public storage.

## Risks not accepted

This exception does not permit:

- onboarding a customer or storing real customer financial data;
- advertising the service as production-ready;
- deleting or weakening the local encrypted recovery bundle;
- disabling daily server backups;
- combining database containment with SSH, service-user, filesystem and proxy hardening in one change;
- ignoring restore, integrity or reconciliation failures;
- leaving the known public workspace-deletion defect unfixed solely because the system is pre-customer.

## Mandatory exit conditions

Before the first customer, real financial dataset, public launch or the review deadline:

1. Select an independent backup destination under owner control.
2. Encrypt at source with a recovery key stored separately from both copies.
3. Implement automated upload, checksum verification, retention and backup-age alerting.
4. Maintain at least three copies across two media with one independent/off-site copy.
5. Approve RPO, RTO, retention, jurisdiction and data-residency requirements.
6. Repeat the restore drill from the independent copy with a second operator.
7. Remove this exception only after evidence is attached to the handoff.

If any customer onboarding becomes likely before these conditions are met, stabilization stops at the release gate and this exception expires automatically.
