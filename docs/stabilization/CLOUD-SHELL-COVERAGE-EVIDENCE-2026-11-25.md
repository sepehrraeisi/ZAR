# Cloud shell / workspace bootstrap coverage (P2)

تاریخ: 2026-11-25 — شاخه: `feature/cloud-shell-bootstrap-coverage`

## Suite

`test/zar_cloud_shell_test.dart`:

**ZarPocketBaseWorkspaceBootstrapper**
- returns existing workspace from user record
- POSTs `/api/zar/bootstrap/workspace` when workspace missing/empty/absent
- throws `FormatException` when bootstrap omits `workspaceId`

**ZarCloudShell widget**
- signed-out → no loading / no error scaffold
- bootstrap transport failure → Persian connection message
- pending bootstrap → `CupertinoActivityIndicator`

## Local

```text
flutter test test/zar_cloud_shell_test.dart
→ All tests passed!
```

## Remaining P2 coverage

- backup UI paths beyond restore-guard
- repository edge cases still open beyond existing PocketBase repository suite
