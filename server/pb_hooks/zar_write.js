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

module.exports = {
  upsert: zarWriteUpsert,
};
