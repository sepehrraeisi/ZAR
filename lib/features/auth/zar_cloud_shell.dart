import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../data/pocketbase/zar_pocketbase_client.dart';
import '../../data/pocketbase/zar_pocketbase_repository.dart';
import '../../repository_phase_a2_app_v2.dart';
import 'zar_auth_service.dart';

/// Cloud-mode shell: after sign-in it resolves (or bootstraps) the user's
/// workspace and mounts the repository-backed app against the PocketBase
/// server. Remounts when the workspace changes; the auth gate above it
/// decides between this and the login screen.
class ZarCloudShell extends StatefulWidget {
  const ZarCloudShell({
    super.key,
    required this.auth,
    required this.client,
  });

  final ZarAuthService auth;
  final ZarPocketBaseClient client;

  @override
  State<ZarCloudShell> createState() => _ZarCloudShellState();
}

class _ZarCloudShellState extends State<ZarCloudShell> {
  final ZarPocketBaseWorkspaceBootstrapper _bootstrapper =
      ZarPocketBaseWorkspaceBootstrapper();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ZarAuthUser?>(
      stream: widget.auth.authStateChanges,
      builder: (context, snapshot) {
        final user = widget.auth.currentUser ?? snapshot.data;
        if (user == null) {
          // The gate above shows the login screen; nothing to mount yet.
          return const SizedBox.shrink();
        }
        return FutureBuilder<String>(
          key: ValueKey('cloud-user-${user.uid}'),
          future: _bootstrapper.resolveFor(user, widget.client),
          builder: (context, workspaceSnapshot) {
            if (workspaceSnapshot.hasError) {
              return const Scaffold(
                body: Center(
                  child: Text(
                    'اتصال به سرور برقرار نشد. اتصال اینترنت را بررسی کنید.',
                  ),
                ),
              );
            }
            if (!workspaceSnapshot.hasData) {
              return const Scaffold(
                body: Center(child: CupertinoActivityIndicator()),
              );
            }
            final workspaceId = workspaceSnapshot.data!;
            return RepositoryZarPlusAppV2(
              key: ValueKey('cloud-shell-$workspaceId'),
              repository: ZarPocketBaseRepository(
                client: widget.client,
                workspaceId: workspaceId,
                businessId: workspaceId,
              ),
            );
          },
        );
      },
    );
  }
}

/// Ensures a signed-in user owns (or belongs to) exactly one workspace and
/// pins it on the user record, so the repository knows where data lives.
class ZarPocketBaseWorkspaceBootstrapper {
  Future<String> resolveFor(
    ZarAuthUser user,
    ZarPocketBaseClient client,
  ) async {
    final record = await client.getRecord('users', id: user.uid);
    final existing = record['workspace'];
    if (existing is String && existing.isNotEmpty) return existing;
    // First run for this account: create the workspace and claim it.
    final workspace = await client.createRecord('zar_workspaces', {
      'displayName': 'ZAR+',
      'members': [user.uid],
    });
    final workspaceId = workspace['id']! as String;
    await client.updateRecord('users', id: user.uid, body: {
      'workspace': workspaceId,
    });
    return workspaceId;
  }
}
