# Second-operator drills — tracker

Runbooks with checklists ready:

| Drill | Runbook | Status |
|---|---|---|
| Restore (clone only) | `RESTORE-RUNBOOK.md` | **Pending second operator** |
| Release (build/install) | `RELEASE-RUNBOOK.md` §7 | **Pending second operator** |
| Incident (tabletop) | `INCIDENT-RUNBOOK.md` | **Pending second operator** |

## First-operator readiness (agent / primary)

- [x] Checklists written and linked from ROADMAP
- [x] Off-site pull path documented (`pull-offsite-backups.ps1`)
- [x] Clone restore tooling exists under `server/scripts/`
- [ ] Logged execution by a **second** human on a separate machine

## How to log a completed drill

Add one HANDOFF §0 line:

```text
YYYY-MM-DD — Second-operator <restore|release|incident> drill: Pass/Fail;
snapshot/APK id; operator initials; notes.
```

Until all three Pass lines exist, Phase 3 «اپراتور دوم» stays open.
