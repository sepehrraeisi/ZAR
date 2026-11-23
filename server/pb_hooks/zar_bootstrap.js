/// Atomic / idempotent workspace bootstrap for a signed-in user.
///
/// Deterministic workspace id (`ws` + userId) makes concurrent first launches
/// converge on one row instead of orphaning duplicates.

const ZAR_BOOTSTRAP_ID_PATTERN = /^[A-Za-z0-9_-]{2,255}$/;

function zarBootstrapIsObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function zarBootstrapWorkspaceId(userId) {
  return 'ws' + userId;
}

function zarBootstrapMemberIds(workspace) {
  const raw = workspace.get('members') || [];
  const out = [];
  for (let i = 0; i < raw.length; i++) {
    out.push(String(raw[i]));
  }
  return out;
}

function zarBootstrapEnsureMember(members, userId) {
  for (let i = 0; i < members.length; i++) {
    if (members[i] === userId) {
      return true;
    }
  }
  return false;
}

function zarBootstrapPinUser(app, user, workspaceId) {
  const current = user.getString('workspace');
  if (current === workspaceId) {
    return false;
  }
  if (current && current !== workspaceId) {
    throw new ApiError(
      409,
      JSON.stringify({
        code: 'workspace_already_pinned',
        recordId: user.getString('id'),
        currentWorkspaceId: current,
        requestedWorkspaceId: workspaceId,
      }),
    );
  }
  user.set('workspace', workspaceId);
  app.save(user);
  return true;
}

function zarBootstrapLoadOrCreate(app, userId, displayName) {
  const workspaceId = zarBootstrapWorkspaceId(userId);
  let workspace = null;
  try {
    workspace = app.findRecordById('zar_workspaces', workspaceId);
  } catch (_) {
    workspace = null;
  }

  if (workspace) {
    const members = zarBootstrapMemberIds(workspace);
    if (!zarBootstrapEnsureMember(members, userId)) {
      throw new ForbiddenError('Workspace id is already claimed.');
    }
    if (members.length !== 1) {
      throw new ApiError(
        409,
        JSON.stringify({
          code: 'workspace_membership_conflict',
          recordId: workspaceId,
        }),
      );
    }
    return { workspace: workspace, created: false };
  }

  const collection = app.findCollectionByNameOrId('zar_workspaces');
  workspace = new Record(collection);
  workspace.set('id', workspaceId);
  workspace.set('displayName', displayName);
  workspace.set('members', [userId]);
  try {
    app.save(workspace);
  } catch (error) {
    // Concurrent bootstrap: the deterministic id insert lost the race.
    try {
      workspace = app.findRecordById('zar_workspaces', workspaceId);
    } catch (_) {
      throw error;
    }
    const members = zarBootstrapMemberIds(workspace);
    if (!zarBootstrapEnsureMember(members, userId) || members.length !== 1) {
      throw new ApiError(
        409,
        JSON.stringify({
          code: 'workspace_membership_conflict',
          recordId: workspaceId,
        }),
      );
    }
    return { workspace: workspace, created: false };
  }
  return { workspace: workspace, created: true };
}

function zarBootstrapWorkspace(e) {
  const actorId = e.auth.id;
  if (typeof actorId !== 'string' || !ZAR_BOOTSTRAP_ID_PATTERN.test(actorId)) {
    throw new UnauthorizedError('Authentication is required.');
  }

  const body = e.requestInfo().body || {};
  if (!zarBootstrapIsObject(body)) {
    throw new BadRequestError('Bootstrap body must be an object.');
  }
  let displayName = body.displayName;
  if (displayName === undefined || displayName === null || displayName === '') {
    displayName = 'ZAR+';
  }
  if (typeof displayName !== 'string' || displayName.length < 1 || displayName.length > 120) {
    throw new BadRequestError('displayName is invalid.');
  }

  let response = null;
  e.app.runInTransaction((txApp) => {
    const user = txApp.findRecordById('users', actorId);
    const pinned = user.getString('workspace');
    if (pinned) {
      let workspace = null;
      try {
        workspace = txApp.findRecordById('zar_workspaces', pinned);
      } catch (_) {
        workspace = null;
      }
      if (!workspace) {
        throw new ApiError(
          409,
          JSON.stringify({
            code: 'pinned_workspace_missing',
            recordId: pinned,
          }),
        );
      }
      const members = zarBootstrapMemberIds(workspace);
      if (!zarBootstrapEnsureMember(members, actorId)) {
        throw new ForbiddenError('Not a workspace member.');
      }
      response = {
        workspaceId: pinned,
        created: false,
        pinned: false,
      };
      return;
    }

    const result = zarBootstrapLoadOrCreate(txApp, actorId, displayName);
    const workspaceId = result.workspace.getString('id');
    const pinnedNow = zarBootstrapPinUser(txApp, user, workspaceId);
    response = {
      workspaceId: workspaceId,
      created: result.created,
      pinned: pinnedNow,
    };
  });

  return e.json(200, response);
}

module.exports = {
  bootstrapWorkspace: zarBootstrapWorkspace,
};
