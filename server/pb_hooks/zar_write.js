/// Shared implementation for `/api/zar/write/upsert` — CAS + idempotency for
/// ordinary people/deals/settlements writes.

const ZAR_WRITE_COLLECTIONS = {
  zar_people: true,
  zar_deals: true,
  zar_settlements: true,
  zar_coin_types: true,
  zar_currency_types: true,
};

const ZAR_WRITE_ID_PATTERN = /^[A-Za-z0-9_-]{2,255}$/;
const ZAR_WRITE_KEY_PATTERN = /^[A-Za-z0-9_-]{16,128}$/;
const ZAR_WRITE_HASH_PATTERN = /^[a-f0-9]{64}$/;

function zarWriteIsObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function zarWriteCanonicalJson(value) {
  if (value === null || typeof value !== 'object') {
    return JSON.stringify(value);
  }
  if (Array.isArray(value)) {
    return '[' + value.map(zarWriteCanonicalJson).join(',') + ']';
  }
  const keys = Object.keys(value).sort();
  const parts = [];
  for (let i = 0; i < keys.length; i++) {
    const key = keys[i];
    parts.push(JSON.stringify(key) + ':' + zarWriteCanonicalJson(value[key]));
  }
  return '{' + parts.join(',') + '}';
}

function zarWriteRequestHash(collection, id, workspaceId, expectedRevision, data) {
  const payload = {
    collection: collection,
    id: id,
    workspaceId: workspaceId,
    expectedRevision: expectedRevision,
    data: data,
  };
  return $security.sha256(zarWriteCanonicalJson(payload));
}

function zarWriteAuthorize(app, actorId, workspaceId) {
  if (typeof actorId !== 'string' || actorId.length === 0) {
    throw new UnauthorizedError('Authentication is required.');
  }
  if (typeof workspaceId !== 'string' || !ZAR_WRITE_ID_PATTERN.test(workspaceId)) {
    throw new BadRequestError('Workspace id is invalid.');
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
  return workspace;
}

function zarWriteFindReceipt(app, workspaceId, idempotencyKey) {
  const matches = app.findRecordsByFilter(
    'zar_write_receipts',
    'workspace = {:workspace} && idempotencyKey = {:key}',
    'id',
    1,
    0,
    { workspace: workspaceId, key: idempotencyKey },
  );
  return matches.length === 0 ? null : matches[0];
}

function zarWriteReceiptResponse(receipt, replayed) {
  return {
    replayed: replayed,
    collection: receipt.getString('collection'),
    record: zarWriteRecordJson(receipt, 'responseRecord'),
    revision: receipt.getInt('responseRevision'),
  };
}

function zarWriteRecordJson(record, field) {
  const raw = record.get(field);
  if (typeof raw === 'string') {
    return JSON.parse(raw);
  }
  return raw;
}

function zarWritePublicRecord(record) {
  return {
    id: record.getString('id'),
    workspace: record.getString('workspace'),
    revision: record.getInt('revision'),
    data: zarWriteRecordJson(record, 'data'),
  };
}

function zarWriteUpsert(e) {
  const actorId = e.auth.id;
  const body = e.requestInfo().body;
  if (!zarWriteIsObject(body)) {
    throw new BadRequestError('Write body is required.');
  }

  const collection = body.collection;
  if (typeof collection !== 'string' || !ZAR_WRITE_COLLECTIONS[collection]) {
    throw new BadRequestError('Unsupported write collection.');
  }
  const id = body.id;
  if (typeof id !== 'string' || !ZAR_WRITE_ID_PATTERN.test(id)) {
    throw new BadRequestError('Record id is invalid.');
  }
  const workspaceId = body.workspaceId;
  const idempotencyKey = body.idempotencyKey;
  if (
    typeof idempotencyKey !== 'string' ||
    !ZAR_WRITE_KEY_PATTERN.test(idempotencyKey)
  ) {
    throw new BadRequestError('Idempotency key is invalid.');
  }
  if (!zarWriteIsObject(body.data)) {
    throw new BadRequestError('Record data is required.');
  }
  const expectedRevision = body.expectedRevision;
  if (
    expectedRevision !== 0 &&
    (!Number.isSafeInteger(expectedRevision) || expectedRevision < 0)
  ) {
    throw new BadRequestError('expectedRevision must be a non-negative integer.');
  }

  const requestHash = zarWriteRequestHash(
    collection,
    id,
    workspaceId,
    expectedRevision,
    body.data,
  );
  if (!ZAR_WRITE_HASH_PATTERN.test(requestHash)) {
    throw new BadRequestError('Request hash is invalid.');
  }

  let response = null;
  e.app.runInTransaction((txApp) => {
    zarWriteAuthorize(txApp, actorId, workspaceId);

    const existingReceipt = zarWriteFindReceipt(
      txApp,
      workspaceId,
      idempotencyKey,
    );
    if (existingReceipt) {
      if (existingReceipt.getString('requestHash') !== requestHash) {
        // PocketBase serializes ApiError.data as field-validation maps; put
        // machine-readable conflict details in the message instead.
        throw new ApiError(
          409,
          JSON.stringify({
            code: 'idempotency_payload_mismatch',
            collection: collection,
            recordId: id,
          }),
        );
      }
      response = zarWriteReceiptResponse(existingReceipt, true);
      return;
    }

    let existing = null;
    try {
      existing = txApp.findRecordById(collection, id);
    } catch (_) {
      existing = null;
    }

    if (existing && existing.getString('workspace') !== workspaceId) {
      throw new ForbiddenError('Record belongs to another workspace.');
    }

    const currentRevision = existing ? existing.getInt('revision') : 0;
    if (currentRevision !== expectedRevision) {
      throw new ApiError(
        409,
        JSON.stringify({
          code: 'stale_revision',
          collection: collection,
          recordId: id,
          expectedRevision: expectedRevision,
          currentRevision: currentRevision,
        }),
      );
    }

    const nextRevision = currentRevision + 1;
    const collectionModel = txApp.findCollectionByNameOrId(collection);
    const record = existing || new Record(collectionModel);
    if (!existing) {
      record.set('id', id);
      record.set('workspace', workspaceId);
    }
    record.set('data', body.data);
    record.set('revision', nextRevision);
    txApp.save(record);

    const publicRecord = zarWritePublicRecord(record);
    const receipts = txApp.findCollectionByNameOrId('zar_write_receipts');
    const receipt = new Record(receipts);
    receipt.set('workspace', workspaceId);
    receipt.set('actor', actorId);
    receipt.set('idempotencyKey', idempotencyKey);
    receipt.set('collection', collection);
    receipt.set('recordId', id);
    receipt.set('requestHash', requestHash);
    receipt.set('responseRevision', nextRevision);
    receipt.set('responseRecord', publicRecord);
    txApp.save(receipt);

    response = {
      replayed: false,
      collection: collection,
      record: publicRecord,
      revision: nextRevision,
    };
  });

  return e.json(200, response);
}

function zarWriteAllocationId(settlementId, targetType, targetId) {
  return 'alloc-' + settlementId + '-' + targetType + '-' + targetId;
}

function zarWriteAllocationData(record) {
  return zarWriteRecordJson(record, 'data');
}

function zarWritePlainData(value) {
  // PocketBase JSON fields can arrive as plain objects, JSON strings, or
  // raw byte arrays (types.JSONRaw). Match zar_restore.js decoding so
  // settlementId filtering does not silently drop live rows.
  if (value === null || value === undefined) {
    return null;
  }
  if (zarWriteIsObject(value)) {
    try {
      return JSON.parse(JSON.stringify(value));
    } catch (_) {
      return value;
    }
  }
  if (typeof value === 'string') {
    return JSON.parse(value);
  }
  if (Array.isArray(value)) {
    return JSON.parse(toString(value));
  }
  return JSON.parse(toString(value));
}

function zarWriteAllocationSnapshot(app, workspaceId, settlementId) {
  const matches = app.findRecordsByFilter(
    'zar_allocations',
    'workspace = {:workspace}',
    'id',
    5000,
    0,
    { workspace: workspaceId },
  );
  const rows = [];
  for (let i = 0; i < matches.length; i++) {
    const record = matches[i];
    const data = zarWritePlainData(record.get('data'));
    if (!data || String(data.settlementId) !== String(settlementId)) {
      continue;
    }
    rows.push({
      id: record.getString('id'),
      data: data,
    });
  }
  rows.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return rows;
}

function zarWriteAllocationSetHash(rows) {
  return $security.sha256(zarWriteCanonicalJson(rows));
}

function zarWriteNormalizeAllocationRows(settlementId, rawRows) {
  if (!Array.isArray(rawRows)) {
    throw new BadRequestError('allocations must be an array.');
  }
  if (rawRows.length > 500) {
    throw new BadRequestError('Too many allocations in one replace.');
  }
  const seen = {};
  const rows = [];
  for (let i = 0; i < rawRows.length; i++) {
    const item = rawRows[i];
    if (!zarWriteIsObject(item)) {
      throw new BadRequestError('Each allocation must be an object.');
    }
    if (item.settlementId !== settlementId) {
      throw new BadRequestError('Allocation source mismatch.');
    }
    const targetType = item.targetType;
    if (targetType !== 'deal' && targetType !== 'settlement') {
      throw new BadRequestError('Allocation targetType is invalid.');
    }
    const targetId = item.targetId;
    if (typeof targetId !== 'string' || !ZAR_WRITE_ID_PATTERN.test(targetId)) {
      throw new BadRequestError('Allocation targetId is invalid.');
    }
    if (targetType === 'settlement' && targetId === settlementId) {
      throw new BadRequestError('A payment cannot allocate to itself.');
    }
    const amountToman = item.amountToman;
    if (!Number.isSafeInteger(amountToman) || amountToman <= 0) {
      throw new BadRequestError('Allocation amountToman must be a positive integer.');
    }
    const key = targetType + ':' + targetId;
    if (seen[key]) {
      throw new BadRequestError('Duplicate allocation.');
    }
    seen[key] = true;
    const data = {
      settlementId: settlementId,
      targetType: targetType,
      targetId: targetId,
      amountToman: amountToman,
    };
    rows.push({
      id: zarWriteAllocationId(settlementId, targetType, targetId),
      data: data,
    });
  }
  rows.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return rows;
}

function zarWriteNormalizeExpectedBefore(settlementId, rawRows) {
  if (rawRows === undefined || rawRows === null) {
    return [];
  }
  if (!Array.isArray(rawRows)) {
    throw new BadRequestError('expectedBefore must be an array.');
  }
  if (rawRows.length > 500) {
    throw new BadRequestError('expectedBefore is too large.');
  }
  const rows = [];
  for (let i = 0; i < rawRows.length; i++) {
    const item = rawRows[i];
    if (!zarWriteIsObject(item) || typeof item.id !== 'string') {
      throw new BadRequestError('expectedBefore rows are invalid.');
    }
    if (!zarWriteIsObject(item.data) || item.data.settlementId !== settlementId) {
      throw new BadRequestError('expectedBefore settlement mismatch.');
    }
    rows.push({ id: item.id, data: item.data });
  }
  rows.sort((a, b) => (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));
  return rows;
}

function zarWriteAllocationRequestHash(
  workspaceId,
  settlementId,
  expectedBefore,
  rows,
) {
  return $security.sha256(
    zarWriteCanonicalJson({
      workspaceId: workspaceId,
      settlementId: settlementId,
      expectedBefore: expectedBefore,
      allocations: rows,
    }),
  );
}

function zarWriteReplaceAllocations(e) {
  const actorId = e.auth.id;
  const body = e.requestInfo().body;
  if (!zarWriteIsObject(body)) {
    throw new BadRequestError('Write body is required.');
  }

  const workspaceId = body.workspaceId;
  const settlementId = body.settlementId;
  if (typeof settlementId !== 'string' || !ZAR_WRITE_ID_PATTERN.test(settlementId)) {
    throw new BadRequestError('Settlement id is invalid.');
  }
  const idempotencyKey = body.idempotencyKey;
  if (
    typeof idempotencyKey !== 'string' ||
    !ZAR_WRITE_KEY_PATTERN.test(idempotencyKey)
  ) {
    throw new BadRequestError('Idempotency key is invalid.');
  }

  const expectedBefore = zarWriteNormalizeExpectedBefore(
    settlementId,
    body.expectedBefore,
  );
  const nextRows = zarWriteNormalizeAllocationRows(settlementId, body.allocations);
  const requestHash = zarWriteAllocationRequestHash(
    workspaceId,
    settlementId,
    expectedBefore,
    nextRows,
  );
  if (!ZAR_WRITE_HASH_PATTERN.test(requestHash)) {
    throw new BadRequestError('Request hash is invalid.');
  }

  let response = null;
  e.app.runInTransaction((txApp) => {
    zarWriteAuthorize(txApp, actorId, workspaceId);

    const existingReceipt = zarWriteFindReceipt(
      txApp,
      workspaceId,
      idempotencyKey,
    );
    if (existingReceipt) {
      if (existingReceipt.getString('requestHash') !== requestHash) {
        throw new ApiError(
          409,
          JSON.stringify({
            code: 'idempotency_payload_mismatch',
            collection: 'zar_allocations',
            recordId: settlementId,
          }),
        );
      }
      response = zarWriteReceiptResponse(existingReceipt, true);
      return;
    }

    let settlement = null;
    try {
      settlement = txApp.findRecordById('zar_settlements', settlementId);
    } catch (_) {
      settlement = null;
    }
    if (!settlement || settlement.getString('workspace') !== workspaceId) {
      throw new BadRequestError('Allocation source settlement was not found.');
    }

    const beforeRows = zarWriteAllocationSnapshot(
      txApp,
      workspaceId,
      settlementId,
    );
    const beforeHash = zarWriteAllocationSetHash(beforeRows);
    const expectedHash = zarWriteAllocationSetHash(expectedBefore);
    if (beforeHash !== expectedHash) {
      throw new ApiError(
        409,
        JSON.stringify({
          code: 'stale_allocation_set',
          collection: 'zar_allocations',
          recordId: settlementId,
          expectedBeforeHash: expectedHash,
          currentBeforeHash: beforeHash,
        }),
      );
    }

    for (let i = 0; i < beforeRows.length; i++) {
      txApp.delete(txApp.findRecordById('zar_allocations', beforeRows[i].id));
    }

    const collectionModel = txApp.findCollectionByNameOrId('zar_allocations');
    const afterRows = [];
    for (let i = 0; i < nextRows.length; i++) {
      const row = nextRows[i];
      const record = new Record(collectionModel);
      record.set('id', row.id);
      record.set('workspace', workspaceId);
      record.set('data', row.data);
      txApp.save(record);
      afterRows.push({ id: row.id, data: row.data });
    }
    const afterHash = zarWriteAllocationSetHash(afterRows);

    const audit = {
      settlementId: settlementId,
      beforeHash: beforeHash,
      afterHash: afterHash,
      before: beforeRows,
      after: afterRows,
    };
    const receipts = txApp.findCollectionByNameOrId('zar_write_receipts');
    const receipt = new Record(receipts);
    receipt.set('workspace', workspaceId);
    receipt.set('actor', actorId);
    receipt.set('idempotencyKey', idempotencyKey);
    receipt.set('collection', 'zar_allocations');
    receipt.set('recordId', settlementId);
    receipt.set('requestHash', requestHash);
    receipt.set('responseRevision', 1);
    receipt.set('responseRecord', audit);
    txApp.save(receipt);

    response = {
      replayed: false,
      collection: 'zar_allocations',
      record: audit,
      revision: 1,
      beforeHash: beforeHash,
      afterHash: afterHash,
    };
  });

  return e.json(200, response);
}

const ZAR_CASH_KINDS = {
  opening: true,
  adjustment: true,
  contribution: true,
  withdrawal: true,
  expense: true,
  delivery: true,
  reversal: true,
};

function zarWriteNormalizeCashData(workspaceId, id, raw) {
  if (!zarWriteIsObject(raw)) {
    throw new BadRequestError('Cash entry data is required.');
  }
  if (raw.id !== id) {
    throw new BadRequestError('Cash entry id mismatch.');
  }
  if (raw.businessId !== workspaceId) {
    throw new BadRequestError('Cash entry businessId mismatch.');
  }
  const kind = raw.kind;
  if (typeof kind !== 'string' || !ZAR_CASH_KINDS[kind]) {
    throw new BadRequestError('Cash entry kind is invalid.');
  }
  const direction = raw.direction;
  if (direction !== 'receive' && direction !== 'deliver') {
    throw new BadRequestError('Cash entry direction is invalid.');
  }
  if (
    (kind === 'opening' || kind === 'contribution') &&
    direction !== 'receive'
  ) {
    throw new BadRequestError('Opening and contribution must be incoming.');
  }
  if (
    (kind === 'withdrawal' || kind === 'expense') &&
    direction !== 'deliver'
  ) {
    throw new BadRequestError('Withdrawal and expense must be outgoing.');
  }
  if ((kind === 'delivery') !== (typeof raw.dealId === 'string' && raw.dealId.length > 0)) {
    throw new BadRequestError('Delivery entries require dealId.');
  }
  if (
    (kind === 'reversal') !==
    (typeof raw.reversesId === 'string' && raw.reversesId.length > 0)
  ) {
    throw new BadRequestError('Reversal entries require reversesId.');
  }
  if (typeof raw.note !== 'string' || raw.note.trim().length === 0) {
    throw new BadRequestError('Cash entry note is required.');
  }
  if (typeof raw.occurredAt !== 'string' || raw.occurredAt.length < 10) {
    throw new BadRequestError('Cash entry occurredAt is invalid.');
  }
  if (!zarWriteIsObject(raw.amount)) {
    throw new BadRequestError('Cash entry amount is required.');
  }
  return raw;
}

function zarWriteCashRequestHash(workspaceId, id, data) {
  return $security.sha256(
    zarWriteCanonicalJson({
      workspaceId: workspaceId,
      id: id,
      data: data,
    }),
  );
}

function zarWriteAppendCash(e) {
  const actorId = e.auth.id;
  const body = e.requestInfo().body;
  if (!zarWriteIsObject(body)) {
    throw new BadRequestError('Write body is required.');
  }

  const id = body.id;
  if (typeof id !== 'string' || !ZAR_WRITE_ID_PATTERN.test(id)) {
    throw new BadRequestError('Cash entry id is invalid.');
  }
  const workspaceId = body.workspaceId;
  const idempotencyKey = body.idempotencyKey;
  if (
    typeof idempotencyKey !== 'string' ||
    !ZAR_WRITE_KEY_PATTERN.test(idempotencyKey)
  ) {
    throw new BadRequestError('Idempotency key is invalid.');
  }

  const data = zarWriteNormalizeCashData(workspaceId, id, body.data);
  const requestHash = zarWriteCashRequestHash(workspaceId, id, data);
  if (!ZAR_WRITE_HASH_PATTERN.test(requestHash)) {
    throw new BadRequestError('Request hash is invalid.');
  }

  let response = null;
  e.app.runInTransaction((txApp) => {
    zarWriteAuthorize(txApp, actorId, workspaceId);

    const existingReceipt = zarWriteFindReceipt(
      txApp,
      workspaceId,
      idempotencyKey,
    );
    if (existingReceipt) {
      if (existingReceipt.getString('requestHash') !== requestHash) {
        throw new ApiError(
          409,
          JSON.stringify({
            code: 'idempotency_payload_mismatch',
            collection: 'zar_cash_entries',
            recordId: id,
          }),
        );
      }
      response = zarWriteReceiptResponse(existingReceipt, true);
      return;
    }

    let existing = null;
    try {
      existing = txApp.findRecordById('zar_cash_entries', id);
    } catch (_) {
      existing = null;
    }

    if (existing) {
      if (existing.getString('workspace') !== workspaceId) {
        throw new ForbiddenError('Record belongs to another workspace.');
      }
      const existingData = zarWritePlainData(existing.get('data'));
      const existingHash = zarWriteCashRequestHash(
        workspaceId,
        id,
        existingData,
      );
      if (existingHash !== requestHash) {
        throw new ApiError(
          409,
          JSON.stringify({
            code: 'cash_entry_immutable',
            collection: 'zar_cash_entries',
            recordId: id,
          }),
        );
      }
      // Same payload already present: issue a receipt so later replays are cheap.
      const publicRecord = {
        id: id,
        workspace: workspaceId,
        data: existingData,
      };
      const receipts = txApp.findCollectionByNameOrId('zar_write_receipts');
      const receipt = new Record(receipts);
      receipt.set('workspace', workspaceId);
      receipt.set('actor', actorId);
      receipt.set('idempotencyKey', idempotencyKey);
      receipt.set('collection', 'zar_cash_entries');
      receipt.set('recordId', id);
      receipt.set('requestHash', requestHash);
      receipt.set('responseRevision', 1);
      receipt.set('responseRecord', publicRecord);
      txApp.save(receipt);
      response = {
        replayed: true,
        collection: 'zar_cash_entries',
        record: publicRecord,
        revision: 1,
      };
      return;
    }

    const collectionModel = txApp.findCollectionByNameOrId('zar_cash_entries');
    const record = new Record(collectionModel);
    record.set('id', id);
    record.set('workspace', workspaceId);
    record.set('data', data);
    txApp.save(record);

    const publicRecord = {
      id: id,
      workspace: workspaceId,
      data: data,
    };
    const receipts = txApp.findCollectionByNameOrId('zar_write_receipts');
    const receipt = new Record(receipts);
    receipt.set('workspace', workspaceId);
    receipt.set('actor', actorId);
    receipt.set('idempotencyKey', idempotencyKey);
    receipt.set('collection', 'zar_cash_entries');
    receipt.set('recordId', id);
    receipt.set('requestHash', requestHash);
    receipt.set('responseRevision', 1);
    receipt.set('responseRecord', publicRecord);
    txApp.save(receipt);

    response = {
      replayed: false,
      collection: 'zar_cash_entries',
      record: publicRecord,
      revision: 1,
    };
  });

  return e.json(200, response);
}

module.exports = {
  upsert: zarWriteUpsert,
  replaceAllocations: zarWriteReplaceAllocations,
  appendCash: zarWriteAppendCash,
  allocationSetHash: zarWriteAllocationSetHash,
};
