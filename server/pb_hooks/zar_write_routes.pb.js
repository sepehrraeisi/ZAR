/// CAS + idempotency upsert route and Record API revision guards.

routerAdd(
  'POST',
  '/api/zar/write/upsert',
  (e) => {
    const write = require(`${__hooks}/zar_write.js`);
    return write.upsert(e);
  },
  $apis.requireAuth('users'),
  $apis.bodyLimit(2 * 1024 * 1024),
);

function zarWriteOnCreate(e) {
  // Legacy Record API creates (tests / older clients) get revision 1.
  // Prefer `/api/zar/write/upsert` for idempotent CAS writes.
  const current = e.record.get('revision');
  if (
    current === null ||
    current === undefined ||
    current === 0 ||
    current === ''
  ) {
    e.record.set('revision', 1);
  }
}

function zarWriteOnUpdate(e) {
  const info = e.requestInfo();
  const body = info.body || {};
  let existing;
  try {
    existing = e.app.findRecordById(e.record.collection().name, e.record.id);
  } catch (_) {
    throw new NotFoundError('Record not found.');
  }
  const current = existing.getInt('revision') || 1;
  const expected = body.revision;
  if (!Number.isSafeInteger(expected)) {
    throw new BadRequestError(
      'Updating this record requires revision (expected current revision).',
    );
  }
  if (expected !== current) {
    throw new ApiError(
      409,
      JSON.stringify({
        code: 'stale_revision',
        collection: e.record.collection().name,
        recordId: e.record.id,
        expectedRevision: expected,
        currentRevision: current,
      }),
    );
  }
  e.record.set('revision', current + 1);
}

onRecordCreateRequest(zarWriteOnCreate, 'zar_people');
onRecordCreateRequest(zarWriteOnCreate, 'zar_deals');
onRecordCreateRequest(zarWriteOnCreate, 'zar_settlements');

onRecordUpdateRequest(zarWriteOnUpdate, 'zar_people');
onRecordUpdateRequest(zarWriteOnUpdate, 'zar_deals');
onRecordUpdateRequest(zarWriteOnUpdate, 'zar_settlements');
