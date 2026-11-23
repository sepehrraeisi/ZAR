/// Consistent workspace snapshot read (ZAR-DATA-006).
///
/// Reads all domain collections under a workspace epoch fence: if a write
/// bumps epoch mid-read, retry until the before/after epochs match.

const ZAR_READ_ID_PATTERN = /^[A-Za-z0-9_-]{2,255}$/;
const ZAR_READ_MAX_PER_COLLECTION = 5000;
const ZAR_READ_MAX_TOTAL_RECORDS = 10000;
const ZAR_READ_MAX_RETRIES = 8;

const ZAR_READ_COLLECTIONS = [
  { key: 'people', name: 'zar_people', hasRevision: true },
  { key: 'deals', name: 'zar_deals', hasRevision: true },
  { key: 'settlements', name: 'zar_settlements', hasRevision: true },
  { key: 'coinTypes', name: 'zar_coin_types', hasRevision: true },
  { key: 'currencyTypes', name: 'zar_currency_types', hasRevision: true },
  { key: 'allocations', name: 'zar_allocations', hasRevision: false },
  { key: 'cashEntries', name: 'zar_cash_entries', hasRevision: false },
];

function zarReadRecordData(record) {
  const raw = record.get('data');
  if (typeof raw === 'string') {
    return JSON.parse(raw);
  }
  return raw;
}

function zarReadPublicRow(record, hasRevision) {
  const row = {
    id: record.getString('id'),
    workspace: record.getString('workspace'),
    data: zarReadRecordData(record),
  };
  if (hasRevision) {
    row.revision = record.getInt('revision') || 1;
  }
  return row;
}

function zarReadAuthorize(app, actorId) {
  if (typeof actorId !== 'string' || actorId.length === 0) {
    throw new UnauthorizedError('Authentication is required.');
  }
  const user = app.findRecordById('users', actorId);
  const workspaceId = user.getString('workspace');
  if (typeof workspaceId !== 'string' || !ZAR_READ_ID_PATTERN.test(workspaceId)) {
    throw new ForbiddenError('The authenticated account has no matching workspace.');
  }
  const workspace = app.findRecordById('zar_workspaces', workspaceId);
  const members = workspace.get('members') || [];
  let allowed = false;
  for (let i = 0; i < members.length; i++) {
    if (String(members[i]) === actorId) {
      allowed = true;
      break;
    }
  }
  if (!allowed) {
    throw new ForbiddenError('Not a workspace member.');
  }
  return { workspaceId: workspaceId, workspace: workspace };
}

function zarReadWorkspaceEpoch(workspace) {
  const raw = workspace.get('epoch');
  if (raw === null || raw === undefined || raw === '') {
    return 0;
  }
  const value = Number(raw);
  if (!Number.isSafeInteger(value) || value < 0) {
    return 0;
  }
  return value;
}

function zarReadLoadCollections(app, workspaceId) {
  const payload = {};
  let total = 0;
  for (let i = 0; i < ZAR_READ_COLLECTIONS.length; i++) {
    const definition = ZAR_READ_COLLECTIONS[i];
    const records = app.findRecordsByFilter(
      definition.name,
      'workspace = {:workspace}',
      'id',
      ZAR_READ_MAX_PER_COLLECTION + 1,
      0,
      { workspace: workspaceId },
    );
    if (records.length > ZAR_READ_MAX_PER_COLLECTION) {
      throw new ApiError(413, 'Workspace is too large for snapshot read.');
    }
    const rows = [];
    for (let j = 0; j < records.length; j++) {
      rows.push(zarReadPublicRow(records[j], definition.hasRevision));
    }
    payload[definition.key] = rows;
    total += rows.length;
  }
  if (total > ZAR_READ_MAX_TOTAL_RECORDS) {
    throw new ApiError(413, 'Workspace is too large for snapshot read.');
  }
  return payload;
}

function zarReadSnapshot(e) {
  const actorId = e.auth.id;
  let response = null;
  for (let attempt = 0; attempt < ZAR_READ_MAX_RETRIES; attempt++) {
    const auth = zarReadAuthorize(e.app, actorId);
    const epochBefore = zarReadWorkspaceEpoch(auth.workspace);
    const collections = zarReadLoadCollections(e.app, auth.workspaceId);
    const workspaceAfter = e.app.findRecordById('zar_workspaces', auth.workspaceId);
    const epochAfter = zarReadWorkspaceEpoch(workspaceAfter);
    if (epochBefore === epochAfter) {
      response = {
        workspaceId: auth.workspaceId,
        epoch: epochAfter,
        people: collections.people,
        deals: collections.deals,
        settlements: collections.settlements,
        coinTypes: collections.coinTypes,
        currencyTypes: collections.currencyTypes,
        allocations: collections.allocations,
        cashEntries: collections.cashEntries,
      };
      break;
    }
  }
  if (!response) {
    throw new ApiError(
      503,
      JSON.stringify({
        code: 'snapshot_epoch_busy',
        message: 'Workspace changed during snapshot read; retry.',
      }),
    );
  }
  return e.json(200, response);
}

module.exports = {
  snapshot: zarReadSnapshot,
};
