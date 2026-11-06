/// Add the private receipt store and authenticated rate limits required by the
/// ZAR transactional restore hook.
///
/// Restore payloads are never persisted in this collection. A receipt stores
/// only hashes, counts and the authenticated actor so a lost HTTP response can
/// be retried with the same request id without applying the restore twice.

const memberUpdateRule =
  '@request.auth.id != "" && members.id ?= @request.auth.id';
const lockedMemberUpdateRule =
  memberUpdateRule + ' && @request.body.members:changed = false';

const preRestoreRateRules = [
  { label: '*:auth', audience: '', duration: 60, maxRequests: 5 },
  { label: 'users:create', audience: '', duration: 600, maxRequests: 5 },
  {
    label: '*:requestPasswordReset',
    audience: '',
    duration: 300,
    maxRequests: 3,
  },
  { label: '*:requestOTP', audience: '', duration: 300, maxRequests: 3 },
  {
    label: '*:requestVerification',
    audience: '',
    duration: 300,
    maxRequests: 3,
  },
  {
    label: '*:requestEmailChange',
    audience: '',
    duration: 300,
    maxRequests: 3,
  },
  {
    label: '*:confirmPasswordReset',
    audience: '',
    duration: 300,
    maxRequests: 10,
  },
  {
    label: '*:confirmVerification',
    audience: '',
    duration: 300,
    maxRequests: 10,
  },
  {
    label: '*:confirmEmailChange',
    audience: '',
    duration: 300,
    maxRequests: 10,
  },
  {
    label: '/api/batch',
    audience: '@auth',
    duration: 1,
    maxRequests: 10,
  },
  { label: '/api/', audience: '@guest', duration: 10, maxRequests: 60 },
];

const restoreRateRules = [
  ...preRestoreRateRules,
  {
    label: '/api/zar/restore/state',
    audience: '@auth',
    duration: 60,
    maxRequests: 30,
  },
  {
    label: '/api/zar/restore/commit',
    audience: '@auth',
    duration: 600,
    maxRequests: 10,
  },
];

function sameRules(actual, expected) {
  if (!actual || actual.length !== expected.length) return false;
  for (let i = 0; i < expected.length; i++) {
    const left = actual[i];
    const right = expected[i];
    if (
      left.label !== right.label ||
      left.audience !== right.audience ||
      left.duration !== right.duration ||
      left.maxRequests !== right.maxRequests
    ) {
      return false;
    }
  }
  return true;
}

function rateSettingsMatch(settings, expected) {
  return (
    settings.rateLimits.enabled &&
    settings.rateLimits.excludedIPs &&
    settings.rateLimits.excludedIPs.length === 0 &&
    sameRules(settings.rateLimits.rules, expected)
  );
}

migrate((app) => {
  const settings = app.settings();
  if (!rateSettingsMatch(settings, preRestoreRateRules)) {
    throw new Error(
      'Refusing to add restore rate limits because the reviewed rate policy has drifted.',
    );
  }

  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  const users = app.findCollectionByNameOrId('users');
  const currentMemberUpdateRule = String(workspaces.updateRule);
  if (
    currentMemberUpdateRule !== memberUpdateRule &&
    currentMemberUpdateRule !== lockedMemberUpdateRule
  ) {
    throw new Error(
      'Refusing to lock workspace membership because its update rule has drifted: ' +
        JSON.stringify(currentMemberUpdateRule),
    );
  }
  workspaces.updateRule = lockedMemberUpdateRule;
  app.save(workspaces);
  app.save(new Collection({
    name: 'zar_restore_receipts',
    type: 'base',
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      {
        name: 'id',
        type: 'text',
        required: true,
        primaryKey: true,
        autogeneratePattern: '[a-f0-9]{32}',
        pattern: '^[a-f0-9]{32}$',
        min: 32,
        max: 32,
      },
      {
        name: 'workspace',
        type: 'relation',
        required: true,
        maxSelect: 1,
        collectionId: workspaces.id,
      },
      {
        name: 'actor',
        type: 'relation',
        required: true,
        maxSelect: 1,
        collectionId: users.id,
      },
      {
        name: 'protocolVersion',
        type: 'number',
        required: true,
        onlyInt: true,
        min: 1,
        max: 1,
      },
      {
        name: 'snapshotHash',
        type: 'text',
        required: true,
        pattern: '^[a-f0-9]{64}$',
        min: 64,
        max: 64,
      },
      {
        name: 'beforeHash',
        type: 'text',
        required: true,
        pattern: '^[a-f0-9]{64}$',
        min: 64,
        max: 64,
      },
      {
        name: 'afterHash',
        type: 'text',
        required: true,
        pattern: '^[a-f0-9]{64}$',
        min: 64,
        max: 64,
      },
      { name: 'counts', type: 'json', required: true },
      { name: 'committedAt', type: 'autodate', onCreate: true },
    ],
    indexes: [
      'CREATE INDEX idx_zar_restore_receipts_workspace_committed ON zar_restore_receipts (workspace, committedAt)',
      'CREATE INDEX idx_zar_restore_receipts_actor_committed ON zar_restore_receipts (actor, committedAt)',
    ],
  }));

  settings.rateLimits.rules = restoreRateRules;
  settings.rateLimits.excludedIPs = [];
  settings.rateLimits.enabled = true;
  return app.save(settings);
}, (app) => {
  const settings = app.settings();
  if (!rateSettingsMatch(settings, restoreRateRules)) {
    throw new Error(
      'Refusing to remove restore rate limits because the reviewed rate policy has drifted.',
    );
  }

  if (
    app.findRecordsByFilter('zar_restore_receipts', '', 'id', 1, 0).length > 0
  ) {
    throw new Error(
      'Refusing to remove transactional restore after a restore receipt exists.',
    );
  }

  const workspaces = app.findCollectionByNameOrId('zar_workspaces');
  if (String(workspaces.updateRule) !== lockedMemberUpdateRule) {
    throw new Error(
      'Refusing restore rollback because the workspace membership lock has drifted.',
    );
  }
  // Preserve the membership security boundary even when an unused restore
  // deployment is rolled back. Reopening member edits would let one member
  // evict the others and later satisfy the single-member restore gate.
  workspaces.updateRule = lockedMemberUpdateRule;
  app.save(workspaces);

  const receipts = app.findCollectionByNameOrId('zar_restore_receipts');
  if (receipts) {
    app.delete(receipts);
  }
  settings.rateLimits.rules = preRestoreRateRules;
  settings.rateLimits.excludedIPs = [];
  settings.rateLimits.enabled = true;
  return app.save(settings);
});
