/// Shared implementation for the transactional ZAR restore routes.
///
/// The normal record APIs remain suitable for incremental writes. A destructive
/// whole-snapshot restore is different: its authorization check, stale-state
/// check, deletes, creates, post-write verification and idempotency receipt must
/// share one database transaction or another device can be silently overwritten.

const ZAR_RESTORE_PROTOCOL_VERSION = 1;
const ZAR_RESTORE_MAX_PER_COLLECTION = 5000;
const ZAR_RESTORE_MAX_TOTAL_RECORDS = 10000;
const ZAR_RESTORE_ID_PATTERN = /^[A-Za-z0-9_-]{2,255}$/;
const ZAR_RESTORE_REQUEST_ID_PATTERN = /^[a-f0-9]{32}$/;
const ZAR_RESTORE_HASH_PATTERN = /^[a-f0-9]{64}$/;
const ZAR_RESTORE_DECIMAL_PATTERN = /^\d+(?:\.\d+)?$/;
const ZAR_RESTORE_MAX_EXACT_INTEGER = 9007199254740991;

const ZAR_RESTORE_COLLECTIONS = [
  { key: 'people', name: 'zar_people', dataId: true },
  { key: 'deals', name: 'zar_deals', dataId: true },
  { key: 'settlements', name: 'zar_settlements', dataId: true },
  { key: 'coinTypes', name: 'zar_coin_types', dataId: true },
  { key: 'currencyTypes', name: 'zar_currency_types', dataId: true },
  { key: 'paymentAllocations', name: 'zar_allocations', dataId: false },
  { key: 'cashEntries', name: 'zar_cash_entries', dataId: true },
];

function zarRestoreIsObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function zarRestoreHas(map, key) {
  return Object.prototype.hasOwnProperty.call(map, key);
}

function zarRestoreRequiredString(value, field) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return value;
}

function zarRestoreNullableString(value, field) {
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return value;
}

function zarRestoreEnum(value, allowed, field) {
  if (typeof value !== 'string' || allowed.indexOf(value) === -1) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return value;
}

function zarRestoreDate(value, field) {
  if (typeof value !== 'string') {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  const milliseconds = Date.parse(value);
  const year = Number.isFinite(milliseconds)
    ? new Date(milliseconds).getUTCFullYear()
    : 0;
  if (!Number.isFinite(milliseconds) || year < 2000 || year > 2200) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return milliseconds;
}

function zarRestorePositiveInteger(value, field) {
  if (
    !Number.isSafeInteger(value) || value <= 0 ||
    value > ZAR_RESTORE_MAX_EXACT_INTEGER
  ) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return value;
}

function zarRestoreNormalizeNatural(value) {
  const normalized = value.replace(/^0+(?=\d)/, '');
  return normalized.length === 0 ? '0' : normalized;
}

function zarRestoreCompareNatural(left, right) {
  const a = zarRestoreNormalizeNatural(left);
  const b = zarRestoreNormalizeNatural(right);
  if (a.length !== b.length) return a.length < b.length ? -1 : 1;
  if (a === b) return 0;
  return a < b ? -1 : 1;
}

function zarRestoreAddNatural(left, right) {
  let carry = 0;
  let result = '';
  let a = left.length - 1;
  let b = right.length - 1;
  while (a >= 0 || b >= 0 || carry !== 0) {
    const sum =
      (a >= 0 ? left.charCodeAt(a--) - 48 : 0) +
      (b >= 0 ? right.charCodeAt(b--) - 48 : 0) + carry;
    result = String(sum % 10) + result;
    carry = Math.floor(sum / 10);
  }
  return zarRestoreNormalizeNatural(result);
}

// The caller must ensure left >= right.
function zarRestoreSubtractNatural(left, right) {
  let borrow = 0;
  let result = '';
  let a = left.length - 1;
  let b = right.length - 1;
  while (a >= 0) {
    let digit = left.charCodeAt(a--) - 48 - borrow;
    digit -= b >= 0 ? right.charCodeAt(b--) - 48 : 0;
    if (digit < 0) {
      digit += 10;
      borrow = 1;
    } else {
      borrow = 0;
    }
    result = String(digit) + result;
  }
  return zarRestoreNormalizeNatural(result);
}

function zarRestoreMultiplyNaturalSmall(value, multiplier) {
  let carry = 0;
  let result = '';
  for (let index = value.length - 1; index >= 0; index--) {
    const product = (value.charCodeAt(index) - 48) * multiplier + carry;
    result = String(product % 10) + result;
    carry = Math.floor(product / 10);
  }
  while (carry > 0) {
    result = String(carry % 10) + result;
    carry = Math.floor(carry / 10);
  }
  return zarRestoreNormalizeNatural(result);
}

function zarRestoreDecimalParts(value, signed, field) {
  if (typeof value !== 'string' || value.length === 0 || value.length > 128) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  let negative = false;
  let unsigned = value;
  if (signed && unsigned[0] === '-') {
    negative = true;
    unsigned = unsigned.slice(1);
  }
  if (!ZAR_RESTORE_DECIMAL_PATTERN.test(unsigned)) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  const pieces = unsigned.split('.');
  const integer = zarRestoreNormalizeNatural(pieces[0]);
  const fraction = pieces.length === 2 ? pieces[1].replace(/0+$/, '') : '';
  const digits = zarRestoreNormalizeNatural(integer + fraction);
  return {
    negative: negative && digits !== '0',
    digits,
    scale: fraction.length,
  };
}

function zarRestoreFormatDecimal(parts) {
  if (parts.digits === '0') return '0';
  const padded = parts.digits.padStart(parts.scale + 1, '0');
  const split = padded.length - parts.scale;
  const value = parts.scale === 0
    ? padded
    : padded.slice(0, split) + '.' + padded.slice(split);
  return parts.negative ? '-' + value : value;
}

function zarRestoreAlignDecimals(left, right) {
  const scale = Math.max(left.scale, right.scale);
  return {
    left: left.digits + '0'.repeat(scale - left.scale),
    right: right.digits + '0'.repeat(scale - right.scale),
    scale,
  };
}

function zarRestoreAddDecimal(leftValue, rightValue) {
  const left = zarRestoreDecimalParts(leftValue, true, 'decimal');
  const right = zarRestoreDecimalParts(rightValue, true, 'decimal');
  const aligned = zarRestoreAlignDecimals(left, right);
  if (left.negative === right.negative) {
    return zarRestoreFormatDecimal({
      negative: left.negative,
      digits: zarRestoreAddNatural(aligned.left, aligned.right),
      scale: aligned.scale,
    });
  }
  const comparison = zarRestoreCompareNatural(aligned.left, aligned.right);
  if (comparison === 0) return '0';
  const leftWins = comparison > 0;
  return zarRestoreFormatDecimal({
    negative: leftWins ? left.negative : right.negative,
    digits: leftWins
      ? zarRestoreSubtractNatural(aligned.left, aligned.right)
      : zarRestoreSubtractNatural(aligned.right, aligned.left),
    scale: aligned.scale,
  });
}

function zarRestoreNegateDecimal(value) {
  return value === '0' ? '0' : value[0] === '-' ? value.slice(1) : '-' + value;
}

function zarRestoreCompareDecimal(leftValue, rightValue) {
  const difference = zarRestoreDecimalParts(
    zarRestoreAddDecimal(leftValue, zarRestoreNegateDecimal(rightValue)),
    true,
    'decimal',
  );
  if (difference.digits === '0') return 0;
  return difference.negative ? -1 : 1;
}

function zarRestoreUnsignedDecimal(value, field, allowZero) {
  const parts = zarRestoreDecimalParts(value, false, field);
  if (!allowZero && parts.digits === '0') {
    throw new BadRequestError('Restore ' + field + ' must be positive.');
  }
  return zarRestoreFormatDecimal(parts);
}

function zarRestoreScaledInteger(value, scale) {
  const digits = String(value).padStart(scale + 1, '0');
  const split = digits.length - scale;
  return zarRestoreUnsignedDecimal(
    scale === 0 ? digits : digits.slice(0, split) + '.' + digits.slice(split),
    'currency quantity',
    false,
  );
}

function zarRestoreQuantityAdd(map, key, value) {
  map[key] = zarRestoreAddDecimal(map[key] || '0', value);
}

function zarRestoreCanonicalJson(value, depth) {
  const currentDepth = depth || 0;
  if (currentDepth > 64) {
    throw new BadRequestError('Restore payload nesting is too deep.');
  }
  if (value === null) return 'null';
  if (Array.isArray(value)) {
    return '[' + value.map((item) => (
      zarRestoreCanonicalJson(item, currentDepth + 1)
    )).join(',') + ']';
  }
  switch (typeof value) {
    case 'string':
    case 'number':
    case 'boolean':
      return JSON.stringify(value);
    case 'object': {
      const keys = Object.keys(value).sort();
      return '{' + keys.map((key) => (
        JSON.stringify(key) + ':' +
          zarRestoreCanonicalJson(value[key], currentDepth + 1)
      )).join(',') + '}';
    }
    default:
      throw new BadRequestError('Restore payload contains an unsupported value.');
  }
}

function zarRestoreHash(value) {
  return $security.sha256(zarRestoreCanonicalJson(value));
}

function zarRestoreCompareRows(left, right) {
  if (left.id < right.id) return -1;
  if (left.id > right.id) return 1;
  return 0;
}

function zarRestoreRecordJson(record, field) {
  const value = record.get(field);
  if (zarRestoreIsObject(value)) return value;
  if (typeof value === 'string') {
    const parsed = JSON.parse(value);
    if (zarRestoreIsObject(parsed)) return parsed;
  }
  if (Array.isArray(value)) {
    const parsed = JSON.parse(toString(value));
    if (zarRestoreIsObject(parsed)) return parsed;
  }
  throw new InternalServerError('A cloud record contains invalid JSON data.');
}

function zarRestoreRecordData(record) {
  return zarRestoreRecordJson(record, 'data');
}

function zarRestoreAuthorize(
  app,
  actorId,
  expectedWorkspaceId,
  confirmationPassword,
) {
  const user = app.findRecordById('users', actorId);
  if (
    confirmationPassword !== undefined &&
    !user.validatePassword(confirmationPassword)
  ) {
    throw new ApiError(428, 'Recent password confirmation is required.');
  }
  const workspaceId = user.getString('workspace');
  if (!workspaceId || (expectedWorkspaceId && workspaceId !== expectedWorkspaceId)) {
    throw new ForbiddenError('The authenticated account has no matching workspace.');
  }
  const workspace = app.findRecordById('zar_workspaces', workspaceId);
  const members = workspace.getStringSlice('members');
  if (members.length !== 1 || members[0] !== actorId) {
    throw new ForbiddenError(
      'Transactional restore requires a workspace with exactly one member.',
    );
  }
  return { actorId, workspaceId };
}

function zarRestoreReadState(app, workspaceId) {
  const snapshot = {};
  const counts = {};
  let total = 0;
  for (const definition of ZAR_RESTORE_COLLECTIONS) {
    const records = app.findRecordsByFilter(
      definition.name,
      'workspace = {:workspace}',
      'id',
      ZAR_RESTORE_MAX_PER_COLLECTION + 1,
      0,
      { workspace: workspaceId },
    );
    if (records.length > ZAR_RESTORE_MAX_PER_COLLECTION) {
      throw new ApiError(413, 'Workspace is too large for transactional restore.');
    }
    const rows = records.map((record) => ({
      id: record.id,
      data: zarRestoreRecordData(record),
    }));
    rows.sort(zarRestoreCompareRows);
    snapshot[definition.key] = rows;
    counts[definition.key] = rows.length;
    total += rows.length;
  }
  if (total > ZAR_RESTORE_MAX_TOTAL_RECORDS) {
    throw new ApiError(413, 'Workspace is too large for transactional restore.');
  }
  counts.total = total;
  return { snapshot, counts, stateHash: zarRestoreHash(snapshot) };
}

function zarRestoreValidateSnapshot(rawSnapshot, workspaceId) {
  if (!zarRestoreIsObject(rawSnapshot)) {
    throw new BadRequestError('Restore snapshot is required.');
  }
  const expectedKeys = ZAR_RESTORE_COLLECTIONS.map((item) => item.key).sort();
  const actualKeys = Object.keys(rawSnapshot).sort();
  if (
    actualKeys.length !== expectedKeys.length ||
    actualKeys.some((key, index) => key !== expectedKeys[index])
  ) {
    throw new BadRequestError('Restore snapshot collections do not match the protocol.');
  }
  const snapshot = {};
  const counts = {};
  let total = 0;
  for (const definition of ZAR_RESTORE_COLLECTIONS) {
    const rawRows = rawSnapshot[definition.key];
    if (!Array.isArray(rawRows)) {
      throw new BadRequestError('Restore snapshot is missing ' + definition.key + '.');
    }
    if (rawRows.length > ZAR_RESTORE_MAX_PER_COLLECTION) {
      throw new ApiError(413, 'Restore collection is too large.');
    }
    const ids = Object.create(null);
    const rows = rawRows.map((rawRow) => {
      if (!zarRestoreIsObject(rawRow) || !zarRestoreIsObject(rawRow.data)) {
        throw new BadRequestError('Restore rows require id and data objects.');
      }
      const id = rawRow.id;
      if (typeof id !== 'string' || !ZAR_RESTORE_ID_PATTERN.test(id)) {
        throw new BadRequestError('Restore row id is invalid.');
      }
      const normalizedId = id.toLowerCase();
      if (ids[normalizedId]) {
        throw new BadRequestError('Restore snapshot contains duplicate ids.');
      }
      ids[normalizedId] = true;
      if (definition.dataId && rawRow.data.id !== id) {
        throw new BadRequestError('Restore row id does not match its data id.');
      }
      if (
        Object.prototype.hasOwnProperty.call(rawRow.data, 'businessId') &&
        rawRow.data.businessId !== workspaceId
      ) {
        throw new BadRequestError('Restore row belongs to another business.');
      }
      if (
        definition.key === 'cashEntries' &&
        rawRow.data.businessId !== workspaceId
      ) {
        throw new BadRequestError('Restore cash entry business is missing.');
      }
      return { id, data: rawRow.data };
    });
    rows.sort(zarRestoreCompareRows);
    snapshot[definition.key] = rows;
    counts[definition.key] = rows.length;
    total += rows.length;
  }
  if (total > ZAR_RESTORE_MAX_TOTAL_RECORDS) {
    throw new ApiError(413, 'Restore snapshot is too large.');
  }
  counts.total = total;
  zarRestoreValidateAccounting(snapshot, workspaceId);
  return { snapshot, counts, snapshotHash: zarRestoreHash(snapshot) };
}

function zarRestoreRowsById(rows) {
  const result = Object.create(null);
  for (const row of rows) result[row.id] = row;
  return result;
}

function zarRestoreValidateFineness(value, field) {
  const normalized = zarRestoreUnsignedDecimal(value, field, false);
  if (zarRestoreCompareDecimal(normalized, '1000') > 0) {
    throw new BadRequestError('Restore ' + field + ' is invalid.');
  }
  return normalized;
}

function zarRestoreParseCoinCatalog(rows) {
  const result = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    zarRestoreRequiredString(data.name, 'coin type name');
    zarRestoreEnum(data.category, ['official', 'parsian', 'other'], 'coin category');
    zarRestoreEnum(
      data.defaultPricingMethod,
      ['perPiece', 'perGram'],
      'coin pricing method',
    );
    if (typeof data.archived !== 'boolean') {
      throw new BadRequestError('Restore coin archive flag is invalid.');
    }
    if (data.defaultWeightGrams !== null && data.defaultWeightGrams !== undefined) {
      zarRestoreUnsignedDecimal(data.defaultWeightGrams, 'coin weight', false);
    }
    if (data.defaultFineness !== null && data.defaultFineness !== undefined) {
      zarRestoreValidateFineness(data.defaultFineness, 'coin fineness');
    }
    zarRestoreDate(data.createdAt, 'coin createdAt');
    zarRestoreDate(data.updatedAt, 'coin updatedAt');
    result[row.id] = data;
  }
  return result;
}

function zarRestoreValidateCurrencyCatalog(rows) {
  const codes = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    zarRestoreRequiredString(data.name, 'currency name');
    const code = zarRestoreRequiredString(data.code, 'currency code');
    if (code !== code.toUpperCase() || codes[code]) {
      throw new BadRequestError('Restore currency code is invalid or duplicated.');
    }
    codes[code] = true;
    if (typeof data.archived !== 'boolean') {
      throw new BadRequestError('Restore currency archive flag is invalid.');
    }
    zarRestoreDate(data.createdAt, 'currency createdAt');
    zarRestoreDate(data.updatedAt, 'currency updatedAt');
  }
}

function zarRestoreParseAssetAmount(rawAmount, coinTypes, field) {
  if (!zarRestoreIsObject(rawAmount)) {
    throw new BadRequestError('Restore ' + field + ' amount is invalid.');
  }
  const assetType = zarRestoreEnum(
    rawAmount.assetType,
    ['gold', 'currency', 'coin'],
    field + ' asset type',
  );
  const quantities = Object.create(null);
  if (assetType === 'currency') {
    const value = rawAmount.currency;
    if (!zarRestoreIsObject(value)) {
      throw new BadRequestError('Restore ' + field + ' currency is invalid.');
    }
    const code = zarRestoreRequiredString(value.code, field + ' currency code');
    if (code !== code.toUpperCase()) {
      throw new BadRequestError('Restore ' + field + ' currency code is invalid.');
    }
    const minorUnits = zarRestorePositiveInteger(
      value.minorUnits,
      field + ' currency minor units',
    );
    const scale = value.minorUnitScale;
    if (!Number.isSafeInteger(scale) || scale < 0 || scale > 6) {
      throw new BadRequestError('Restore ' + field + ' currency scale is invalid.');
    }
    quantities['currency:' + code] = zarRestoreScaledInteger(minorUnits, scale);
    return { assetType, quantities, code, minorUnits, scale };
  }
  if (assetType === 'gold') {
    const value = rawAmount.gold;
    if (!zarRestoreIsObject(value)) {
      throw new BadRequestError('Restore ' + field + ' gold is invalid.');
    }
    const decimal = zarRestoreUnsignedDecimal(
      value.decimal,
      field + ' gold quantity',
      false,
    );
    const unit = zarRestoreEnum(
      value.unit,
      ['gram', 'mesghal', 'coin', 'item'],
      field + ' gold unit',
    );
    let purity = 'unknown';
    if (value.purity !== null && value.purity !== undefined) {
      purity = zarRestoreRequiredString(value.purity, field + ' gold purity').trim();
    }
    let grams = null;
    if (unit === 'gram') {
      grams = decimal;
    } else if (unit === 'mesghal') {
      const parts = zarRestoreDecimalParts(decimal, false, field + ' gold quantity');
      grams = zarRestoreFormatDecimal({
        negative: false,
        digits: zarRestoreMultiplyNaturalSmall(parts.digits, 46083),
        scale: parts.scale + 4,
      });
    }
    if (grams !== null) quantities['gold:' + purity] = grams;
    return { assetType, quantities: grams === null ? null : quantities, purity };
  }

  if (!Array.isArray(rawAmount.coinLines) || rawAmount.coinLines.length === 0) {
    throw new BadRequestError('Restore ' + field + ' coin lines are invalid.');
  }
  const lineIds = Object.create(null);
  for (const line of rawAmount.coinLines) {
    if (!zarRestoreIsObject(line)) {
      throw new BadRequestError('Restore ' + field + ' coin line is invalid.');
    }
    const lineId = zarRestoreRequiredString(line.id, field + ' coin line id');
    if (lineIds[lineId]) {
      throw new BadRequestError('Restore ' + field + ' has duplicate coin lines.');
    }
    const coinTypeId = zarRestoreRequiredString(
      line.coinTypeId,
      field + ' coin type id',
    );
    if (!coinTypes[coinTypeId]) {
      throw new BadRequestError('Restore ' + field + ' references a missing coin type.');
    }
    zarRestoreRequiredString(line.coinTypeNameSnapshot, field + ' coin name');
    const quantity = zarRestorePositiveInteger(line.quantity, field + ' coin quantity');
    let weight = '';
    if (line.weightPerPieceGrams !== null && line.weightPerPieceGrams !== undefined) {
      weight = zarRestoreUnsignedDecimal(
        line.weightPerPieceGrams,
        field + ' coin weight',
        false,
      );
    }
    let fineness = '';
    if (line.fineness !== null && line.fineness !== undefined) {
      fineness = zarRestoreValidateFineness(line.fineness, field + ' coin fineness');
    }
    lineIds[lineId] = { weight, fineness };
    const key = 'coin:' + coinTypeId + '|' + weight + '|' + fineness;
    zarRestoreQuantityAdd(quantities, key, String(quantity));
  }
  return { assetType, quantities, lineIds };
}

function zarRestoreTomanAmount(rawAmount, field) {
  if (
    rawAmount.assetType !== 'currency' ||
    rawAmount.code !== 'TOMAN'
  ) return null;
  const divisor = Math.pow(10, rawAmount.scale);
  if (rawAmount.minorUnits % divisor !== 0) return null;
  return String(rawAmount.minorUnits / divisor);
}

function zarRestorePricingTotal(raw, field) {
  if (!zarRestoreIsObject(raw) || !zarRestoreIsObject(raw.totalToman)) {
    throw new BadRequestError('Restore ' + field + ' pricing is invalid.');
  }
  return String(zarRestorePositiveInteger(
    raw.totalToman.wholeTomans,
    field + ' total Toman',
  ));
}

function zarRestoreValidateLinePricing(rawLines, amount, field, requireAllLines) {
  if (!Array.isArray(rawLines) || rawLines.length === 0 || !amount.lineIds) {
    throw new BadRequestError('Restore ' + field + ' coin pricing is invalid.');
  }
  const seen = Object.create(null);
  let total = '0';
  for (const line of rawLines) {
    if (!zarRestoreIsObject(line)) {
      throw new BadRequestError('Restore ' + field + ' coin pricing line is invalid.');
    }
    const lineId = zarRestoreRequiredString(line.lineId, field + ' pricing line id');
    const amountLine = amount.lineIds[lineId];
    if (!amountLine || seen[lineId]) {
      throw new BadRequestError('Restore ' + field + ' coin pricing coverage is invalid.');
    }
    seen[lineId] = true;
    const method = zarRestoreEnum(
      line.method,
      ['perPiece', 'perGram'],
      field + ' pricing method',
    );
    const referenceFineness = line.priceReferenceFineness;
    if (method === 'perGram') {
      if (!amountLine.weight || !amountLine.fineness) {
        throw new BadRequestError(
          'Restore ' + field + ' weighted coin pricing lacks coin metadata.',
        );
      }
      zarRestoreValidateFineness(
        referenceFineness,
        field + ' reference fineness',
      );
    } else if (referenceFineness !== null && referenceFineness !== undefined) {
      zarRestoreValidateFineness(
        referenceFineness,
        field + ' reference fineness',
      );
    }
    if (!zarRestoreIsObject(line.unitPriceToman)) {
      throw new BadRequestError('Restore ' + field + ' unit price is invalid.');
    }
    zarRestorePositiveInteger(
      line.unitPriceToman.wholeTomans,
      field + ' unit price',
    );
    if (!zarRestoreIsObject(line.rowTotalToman)) {
      throw new BadRequestError('Restore ' + field + ' row total is invalid.');
    }
    total = zarRestoreAddNatural(total, String(zarRestorePositiveInteger(
      line.rowTotalToman.wholeTomans,
      field + ' row total',
    )));
  }
  if (
    requireAllLines &&
    Object.keys(seen).length !== Object.keys(amount.lineIds).length
  ) {
    throw new BadRequestError('Restore ' + field + ' coin pricing coverage is invalid.');
  }
  return total;
}

function zarRestoreValidateDealPricing(raw, amount, field) {
  if (raw === null || raw === undefined) {
    if (amount.assetType === 'coin') {
      throw new BadRequestError('Restore ' + field + ' coin pricing is required.');
    }
    return null;
  }
  if (!zarRestoreIsObject(raw) || raw.kind !== amount.assetType) {
    throw new BadRequestError('Restore ' + field + ' pricing type is invalid.');
  }
  const total = zarRestorePricingTotal(raw, field);
  if (raw.kind === 'gold') {
    const fineness = zarRestoreValidateFineness(raw.fineness, field + ' fineness');
    zarRestoreValidateFineness(
      raw.priceReferenceFineness,
      field + ' reference fineness',
    );
    zarRestoreUnsignedDecimal(raw.inputWeight, field + ' input weight', false);
    zarRestoreEnum(raw.inputWeightUnit, ['gram', 'mesghal'], field + ' input unit');
    zarRestoreEnum(raw.priceUnit, ['gram', 'mesghal'], field + ' price unit');
    if (!zarRestoreIsObject(raw.pricePerUnitToman)) {
      throw new BadRequestError('Restore ' + field + ' unit price is invalid.');
    }
    zarRestorePositiveInteger(
      raw.pricePerUnitToman.wholeTomans,
      field + ' unit price',
    );
    if (amount.purity !== fineness) {
      throw new BadRequestError('Restore ' + field + ' gold purity is inconsistent.');
    }
  } else if (raw.kind === 'currency') {
    zarRestoreUnsignedDecimal(raw.tomanPerUnit, field + ' currency rate', false);
  } else {
    const lineTotal = zarRestoreValidateLinePricing(
      raw.lines,
      amount,
      field,
      true,
    );
    if (zarRestoreCompareNatural(lineTotal, total) !== 0) {
      throw new BadRequestError('Restore ' + field + ' coin total is inconsistent.');
    }
  }
  return total;
}

function zarRestoreValidatePeople(rows) {
  const result = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    zarRestoreRequiredString(data.displayName, 'person display name');
    zarRestoreRequiredString(data.createdBy, 'person creator');
    zarRestoreNullableString(data.phone, 'person phone');
    zarRestoreNullableString(data.note, 'person note');
    if (typeof data.archived !== 'boolean') {
      throw new BadRequestError('Restore person archive flag is invalid.');
    }
    zarRestoreDate(data.createdAt, 'person createdAt');
    zarRestoreDate(data.updatedAt, 'person updatedAt');
    result[row.id] = data;
  }
  return result;
}

function zarRestoreParseDeals(rows, people, coinTypes) {
  const result = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    if (!people[data.personId]) {
      throw new BadRequestError('Restore deal references a missing person.');
    }
    const type = zarRestoreEnum(data.type, ['buy', 'sell'], 'deal type');
    zarRestoreEnum(data.status, ['active', 'completed', 'cancelled'], 'deal status');
    const amount = zarRestoreParseAssetAmount(data.amount, coinTypes, 'deal');
    const pricingTotal = zarRestoreValidateDealPricing(data.pricing, amount, 'deal');
    zarRestoreDate(data.dealAt, 'deal dealAt');
    zarRestoreDate(data.createdAt, 'deal createdAt');
    zarRestoreDate(data.updatedAt, 'deal updatedAt');
    zarRestoreRequiredString(data.createdBy, 'deal creator');
    zarRestoreNullableString(data.note, 'deal note');
    result[row.id] = {
      id: row.id,
      personId: data.personId,
      type,
      amount,
      pricingTotal,
    };
  }
  return result;
}

function zarRestoreValidateReminderPlan(raw, field) {
  if (!zarRestoreIsObject(raw) || !Array.isArray(raw.rules)) {
    throw new BadRequestError('Restore ' + field + ' reminder plan is invalid.');
  }
  if (raw.snoozedUntil !== null && raw.snoozedUntil !== undefined) {
    zarRestoreDate(raw.snoozedUntil, field + ' reminder snooze');
  }
  const ids = Object.create(null);
  for (const rule of raw.rules) {
    if (!zarRestoreIsObject(rule)) {
      throw new BadRequestError('Restore ' + field + ' reminder rule is invalid.');
    }
    const id = zarRestoreRequiredString(rule.id, field + ' reminder id');
    if (ids[id]) {
      throw new BadRequestError('Restore ' + field + ' reminder ids are duplicated.');
    }
    ids[id] = true;
    const type = zarRestoreEnum(
      rule.type,
      ['offset', 'custom'],
      field + ' reminder type',
    );
    if (typeof rule.enabled !== 'boolean') {
      throw new BadRequestError('Restore ' + field + ' reminder enabled flag is invalid.');
    }
    if (type === 'offset') {
      zarRestorePositiveInteger(
        rule.minutesBefore,
        field + ' reminder offset',
      );
      if (rule.customAt !== null && rule.customAt !== undefined) {
        throw new BadRequestError('Restore ' + field + ' offset reminder is invalid.');
      }
    } else {
      zarRestoreDate(rule.customAt, field + ' custom reminder date');
      if (rule.minutesBefore !== null && rule.minutesBefore !== undefined) {
        throw new BadRequestError('Restore ' + field + ' custom reminder is invalid.');
      }
    }
  }
}

function zarRestoreValidateCoinValuation(raw, amount, field) {
  if (raw === null || raw === undefined) return;
  if (!zarRestoreIsObject(raw) || amount.assetType !== 'coin') {
    throw new BadRequestError('Restore ' + field + ' coin valuation is invalid.');
  }
  const lineTotal = zarRestoreValidateLinePricing(
    raw.lines,
    amount,
    field + ' valuation',
    false,
  );
  const total = zarRestorePricingTotal(raw, field + ' valuation');
  if (zarRestoreCompareNatural(lineTotal, total) !== 0) {
    throw new BadRequestError('Restore ' + field + ' valuation total is inconsistent.');
  }
}

function zarRestoreParseSettlements(rows, people, deals, coinTypes) {
  const result = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    if (!people[data.personId]) {
      throw new BadRequestError('Restore settlement references a missing person.');
    }
    const dealId = data.dealId === null || data.dealId === undefined
      ? null
      : zarRestoreRequiredString(data.dealId, 'settlement deal id');
    if (dealId !== null && !deals[dealId]) {
      throw new BadRequestError('Restore settlement references a missing deal.');
    }
    const direction = zarRestoreEnum(
      data.direction,
      ['receive', 'deliver'],
      'settlement direction',
    );
    const status = zarRestoreEnum(
      data.status,
      ['open', 'completed', 'cancelled'],
      'settlement status',
    );
    const completedAt = data.completedAt === null || data.completedAt === undefined
      ? null
      : zarRestoreDate(data.completedAt, 'settlement completedAt');
    if ((status === 'completed') !== (completedAt !== null)) {
      throw new BadRequestError('Restore settlement completion is inconsistent.');
    }
    if (typeof data.hasTime !== 'boolean') {
      throw new BadRequestError('Restore settlement time flag is invalid.');
    }
    const amount = zarRestoreParseAssetAmount(data.amount, coinTypes, 'settlement');
    zarRestoreValidateReminderPlan(data.reminderPlan, 'settlement');
    zarRestoreValidateCoinValuation(data.coinValuation, amount, 'settlement');
    zarRestoreDate(data.scheduledAt, 'settlement scheduledAt');
    zarRestoreDate(data.createdAt, 'settlement createdAt');
    zarRestoreDate(data.updatedAt, 'settlement updatedAt');
    zarRestoreRequiredString(data.createdBy, 'settlement creator');
    zarRestoreNullableString(data.completedBy, 'settlement completer');
    zarRestoreNullableString(data.note, 'settlement note');
    result[row.id] = {
      id: row.id,
      dealId,
      personId: data.personId,
      direction,
      status,
      completedAt,
      amount,
    };
  }
  return result;
}

function zarRestoreValidateAllocations(rows, deals, settlements) {
  const sources = Object.create(null);
  for (const row of rows) {
    const sourceId = row.data.settlementId;
    if (typeof sourceId === 'string') sources[sourceId] = true;
  }
  const seen = Object.create(null);
  const sourceTotals = Object.create(null);
  const targetTotals = Object.create(null);
  for (const row of rows) {
    const data = row.data;
    const sourceId = zarRestoreRequiredString(
      data.settlementId,
      'allocation source id',
    );
    const source = settlements[sourceId];
    const sourceAmount = source ? zarRestoreTomanAmount(source.amount, 'source') : null;
    if (!source || sourceAmount === null) {
      throw new BadRequestError('Restore allocation source must be whole Toman.');
    }
    const targetType = zarRestoreEnum(
      data.targetType,
      ['deal', 'settlement'],
      'allocation target type',
    );
    const targetId = zarRestoreRequiredString(data.targetId, 'allocation target id');
    const expectedId = 'alloc-' + sourceId + '-' + targetType + '-' + targetId;
    if (row.id !== expectedId) {
      throw new BadRequestError('Restore allocation id is not canonical.');
    }
    const key = targetType + ':' + targetId;
    if (seen[sourceId + ':' + key]) {
      throw new BadRequestError('Restore contains duplicate allocations.');
    }
    seen[sourceId + ':' + key] = true;
    let target = null;
    let targetAmount = null;
    let targetDirection = null;
    if (targetType === 'deal') {
      target = deals[targetId];
      if (target && target.pricingTotal !== null) {
        targetAmount = target.pricingTotal;
        targetDirection = target.type === 'buy' ? 'deliver' : 'receive';
      }
    } else {
      target = settlements[targetId];
      if (target && !sources[targetId]) {
        targetAmount = zarRestoreTomanAmount(target.amount, 'target');
        targetDirection = target.direction;
      }
    }
    if (!target || targetAmount === null) {
      throw new BadRequestError('Restore allocation target is invalid.');
    }
    if (
      source.personId !== target.personId ||
      source.direction !== targetDirection
    ) {
      throw new BadRequestError('Restore allocation parties or direction mismatch.');
    }
    const assigned = String(zarRestorePositiveInteger(
      data.amountToman,
      'allocation amount',
    ));
    sourceTotals[sourceId] = zarRestoreAddNatural(sourceTotals[sourceId] || '0', assigned);
    if (zarRestoreCompareNatural(sourceTotals[sourceId], sourceAmount) > 0) {
      throw new BadRequestError('Restore allocation exceeds source amount.');
    }
    if (source.status !== 'cancelled') {
      targetTotals[key] = zarRestoreAddNatural(targetTotals[key] || '0', assigned);
      if (zarRestoreCompareNatural(targetTotals[key], targetAmount) > 0) {
        throw new BadRequestError('Restore allocation exceeds target amount.');
      }
    }
  }
}

function zarRestoreQuantityMapsEqual(left, right) {
  const leftKeys = Object.keys(left).sort();
  const rightKeys = Object.keys(right).sort();
  if (leftKeys.length !== rightKeys.length) return false;
  return leftKeys.every((key, index) => (
    key === rightKeys[index] && zarRestoreCompareDecimal(left[key], right[key]) === 0
  ));
}

function zarRestoreParseCash(rows, workspaceId, deals, settlements, coinTypes) {
  const result = Object.create(null);
  const settlementIds = Object.create(null);
  for (const settlementId of Object.keys(settlements)) {
    settlementIds[settlementId.toLowerCase()] = true;
  }
  for (const row of rows) {
    if (settlementIds[row.id.toLowerCase()]) {
      throw new BadRequestError('Restore cash and settlement ids must be distinct.');
    }
    const data = row.data;
    if (data.businessId !== workspaceId) {
      throw new BadRequestError('Restore cash entry business is invalid.');
    }
    const kind = zarRestoreEnum(
      data.kind,
      ['opening', 'adjustment', 'contribution', 'withdrawal', 'expense', 'delivery', 'reversal'],
      'cash kind',
    );
    const direction = zarRestoreEnum(
      data.direction,
      ['receive', 'deliver'],
      'cash direction',
    );
    const dealId = data.dealId === null || data.dealId === undefined
      ? null
      : zarRestoreRequiredString(data.dealId, 'cash deal id');
    const reversesId = data.reversesId === null || data.reversesId === undefined
      ? null
      : zarRestoreRequiredString(data.reversesId, 'cash reversal id');
    if ((kind === 'delivery') !== (dealId !== null) ||
        (kind === 'reversal') !== (reversesId !== null)) {
      throw new BadRequestError('Restore cash reference is invalid.');
    }
    if ((kind === 'opening' || kind === 'contribution') && direction !== 'receive') {
      throw new BadRequestError('Restore incoming cash direction is invalid.');
    }
    if ((kind === 'withdrawal' || kind === 'expense') && direction !== 'deliver') {
      throw new BadRequestError('Restore outgoing cash direction is invalid.');
    }
    const amount = zarRestoreParseAssetAmount(data.amount, coinTypes, 'cash');
    if (amount.quantities === null) {
      throw new BadRequestError('Restore cash amount unit is unsupported.');
    }
    const counted = data.countedQuantity;
    const expected = data.expectedQuantity;
    if ((counted === null || counted === undefined) !==
        (expected === null || expected === undefined)) {
      throw new BadRequestError('Restore cash count pair is incomplete.');
    }
    let countedValue = null;
    let expectedValue = null;
    if (counted !== null && counted !== undefined) {
      if (kind !== 'adjustment') {
        throw new BadRequestError('Restore cash count requires an adjustment.');
      }
      countedValue = zarRestoreUnsignedDecimal(counted, 'cash counted quantity', true);
      expectedValue = zarRestoreFormatDecimal(
        zarRestoreDecimalParts(expected, true, 'cash expected quantity'),
      );
    }
    result[row.id] = {
      id: row.id,
      kind,
      direction,
      dealId,
      reversesId,
      amount,
      occurredAt: zarRestoreDate(data.occurredAt, 'cash occurredAt'),
      note: zarRestoreRequiredString(data.note, 'cash note'),
      countedValue,
      expectedValue,
    };
  }

  const reversed = Object.create(null);
  const openings = Object.create(null);
  for (const id of Object.keys(result)) {
    const entry = result[id];
    if (entry.kind === 'opening') {
      for (const key of Object.keys(entry.amount.quantities)) {
        if (openings[key]) {
          throw new BadRequestError('Restore has duplicate opening cash entries.');
        }
        openings[key] = true;
      }
    }
    if (entry.reversesId !== null) {
      const original = result[entry.reversesId];
      if (
        !original || original.kind === 'reversal' || original.kind === 'opening' ||
        reversed[original.id] || entry.direction === original.direction ||
        entry.occurredAt < original.occurredAt ||
        !zarRestoreQuantityMapsEqual(entry.amount.quantities, original.amount.quantities)
      ) {
        throw new BadRequestError('Restore cash reversal is invalid.');
      }
      reversed[original.id] = true;
    }
    if (entry.dealId !== null) {
      const deal = deals[entry.dealId];
      const expectedDirection = deal && deal.type === 'buy' ? 'receive' : 'deliver';
      if (!deal || entry.direction !== expectedDirection || deal.amount.quantities === null) {
        throw new BadRequestError('Restore cash delivery does not match a deal.');
      }
      for (const key of Object.keys(entry.amount.quantities)) {
        if (!zarRestoreHas(deal.amount.quantities, key)) {
          throw new BadRequestError('Restore cash delivery asset does not match a deal.');
        }
      }
    }
    if (entry.countedValue !== null) {
      const keys = Object.keys(entry.amount.quantities);
      if (keys.length !== 1) {
        throw new BadRequestError('Restore cash count requires one asset.');
      }
      const difference = zarRestoreAddDecimal(
        entry.countedValue,
        zarRestoreNegateDecimal(entry.expectedValue),
      );
      const quantity = entry.amount.quantities[keys[0]];
      const signedQuantity = entry.direction === 'receive'
        ? quantity
        : zarRestoreNegateDecimal(quantity);
      if (zarRestoreCompareDecimal(difference, signedQuantity) !== 0) {
        throw new BadRequestError('Restore cash count difference is invalid.');
      }
    }
  }

  const deliveredByDeal = Object.create(null);
  for (const cashId of Object.keys(result)) {
    const entry = result[cashId];
    if (entry.dealId === null || reversed[entry.id]) continue;
    const delivered = deliveredByDeal[entry.dealId] || Object.create(null);
    deliveredByDeal[entry.dealId] = delivered;
    for (const key of Object.keys(entry.amount.quantities)) {
      zarRestoreQuantityAdd(delivered, key, entry.amount.quantities[key]);
    }
  }
  for (const settlementId of Object.keys(settlements)) {
    const settlement = settlements[settlementId];
    const deal = settlement.dealId === null ? null : deals[settlement.dealId];
    const delivered = deal ? deliveredByDeal[deal.id] : null;
    const settlementDirection = deal && deal.type === 'buy' ? 'receive' : 'deliver';
    if (
      delivered &&
      settlement.personId === deal.personId &&
      settlement.direction === settlementDirection &&
      settlement.status === 'completed'
    ) {
      if (settlement.amount.quantities === null) {
        throw new BadRequestError('Restore completed delivery unit is unsupported.');
      }
      for (const key of Object.keys(settlement.amount.quantities)) {
        if (zarRestoreHas(deal.amount.quantities, key)) {
          zarRestoreQuantityAdd(delivered, key, settlement.amount.quantities[key]);
        }
      }
    }
  }
  for (const dealId of Object.keys(deliveredByDeal)) {
    const deal = deals[dealId];
    const delivered = deliveredByDeal[dealId];
    for (const key of Object.keys(delivered)) {
      if (
        !zarRestoreHas(deal.amount.quantities, key) ||
        zarRestoreCompareDecimal(delivered[key], deal.amount.quantities[key]) > 0
      ) {
        throw new BadRequestError('Restore cash delivery exceeds deal quantity.');
      }
    }
  }
}

function zarRestoreValidateAccounting(snapshot, workspaceId) {
  const people = zarRestoreValidatePeople(snapshot.people);
  const coinTypes = zarRestoreParseCoinCatalog(snapshot.coinTypes);
  zarRestoreValidateCurrencyCatalog(snapshot.currencyTypes);
  const deals = zarRestoreParseDeals(snapshot.deals, people, coinTypes);
  const settlements = zarRestoreParseSettlements(
    snapshot.settlements,
    people,
    deals,
    coinTypes,
  );
  zarRestoreValidateAllocations(snapshot.paymentAllocations, deals, settlements);
  zarRestoreParseCash(
    snapshot.cashEntries,
    workspaceId,
    deals,
    settlements,
    coinTypes,
  );
}

function zarRestoreFindReceipt(app, requestId) {
  const matches = app.findRecordsByIds('zar_restore_receipts', [requestId]);
  return matches.length === 0 ? null : matches[0];
}

function zarRestoreReceiptResponse(receipt, replayed) {
  return {
    protocolVersion: receipt.getInt('protocolVersion'),
    requestId: receipt.id,
    workspaceId: receipt.getString('workspace'),
    snapshotHash: receipt.getString('snapshotHash'),
    beforeHash: receipt.getString('beforeHash'),
    afterHash: receipt.getString('afterHash'),
    counts: zarRestoreRecordJson(receipt, 'counts'),
    committedAt: receipt.getString('committedAt'),
    replayed,
  };
}

function zarRestoreReplaceState(app, workspaceId, snapshot) {
  for (let index = ZAR_RESTORE_COLLECTIONS.length - 1; index >= 0; index--) {
    const definition = ZAR_RESTORE_COLLECTIONS[index];
    const records = app.findRecordsByFilter(
      definition.name,
      'workspace = {:workspace}',
      'id',
      0,
      0,
      { workspace: workspaceId },
    );
    for (const record of records) app.delete(record);
  }
  for (const definition of ZAR_RESTORE_COLLECTIONS) {
    const collection = app.findCollectionByNameOrId(definition.name);
    for (const row of snapshot[definition.key]) {
      const record = new Record(collection);
      record.set('id', row.id);
      record.set('workspace', workspaceId);
      record.set('data', row.data);
      app.save(record);
    }
  }
}

function zarRestoreStateRoute(e) {
  const actorId = e.auth.id;
  let response = null;
  e.app.runInTransaction((txApp) => {
    const auth = zarRestoreAuthorize(txApp, actorId, '');
    const state = zarRestoreReadState(txApp, auth.workspaceId);
    response = {
      protocolVersion: ZAR_RESTORE_PROTOCOL_VERSION,
      workspaceId: auth.workspaceId,
      stateHash: state.stateHash,
      counts: state.counts,
    };
  });
  return e.json(200, response);
}

function zarRestoreCommitRoute(e) {
  const actorId = e.auth.id;
  const body = e.requestInfo().body;
  if (!zarRestoreIsObject(body)) {
    throw new BadRequestError('Restore request body is required.');
  }
  if (body.protocolVersion !== ZAR_RESTORE_PROTOCOL_VERSION) {
    throw new BadRequestError('Unsupported restore protocol version.');
  }
  if (
    typeof body.confirmationPassword !== 'string' ||
    body.confirmationPassword.length === 0 ||
    body.confirmationPassword.length > 256
  ) {
    throw new ApiError(428, 'Recent password confirmation is required.');
  }
  if (
    typeof body.requestId !== 'string' ||
    !ZAR_RESTORE_REQUEST_ID_PATTERN.test(body.requestId)
  ) {
    throw new BadRequestError('Restore request id is invalid.');
  }
  if (
    typeof body.expectedStateHash !== 'string' ||
    !ZAR_RESTORE_HASH_PATTERN.test(body.expectedStateHash)
  ) {
    throw new BadRequestError('Restore expected-state hash is invalid.');
  }
  const initialAuth = zarRestoreAuthorize(
    e.app,
    actorId,
    '',
    body.confirmationPassword,
  );
  if (body.businessId !== initialAuth.workspaceId) {
    throw new ForbiddenError('Restore belongs to another business.');
  }
  const validated = zarRestoreValidateSnapshot(
    body.snapshot,
    initialAuth.workspaceId,
  );

  let response = null;
  e.app.runInTransaction((txApp) => {
    const auth = zarRestoreAuthorize(
      txApp,
      actorId,
      initialAuth.workspaceId,
      body.confirmationPassword,
    );
    const existing = zarRestoreFindReceipt(txApp, body.requestId);
    if (existing) {
      if (
        existing.getString('workspace') !== auth.workspaceId ||
        existing.getString('actor') !== actorId ||
        existing.getString('snapshotHash') !== validated.snapshotHash ||
        existing.getString('beforeHash') !== body.expectedStateHash ||
        existing.getInt('protocolVersion') !== ZAR_RESTORE_PROTOCOL_VERSION
      ) {
        throw new ApiError(409, 'Restore request id was already used differently.');
      }
      response = zarRestoreReceiptResponse(existing, true);
      return;
    }

    const before = zarRestoreReadState(txApp, auth.workspaceId);
    if (before.stateHash !== body.expectedStateHash) {
      throw new ApiError(409, 'Cloud data changed after restore preview.');
    }

    zarRestoreReplaceState(txApp, auth.workspaceId, validated.snapshot);
    const after = zarRestoreReadState(txApp, auth.workspaceId);
    if (after.stateHash !== validated.snapshotHash) {
      throw new InternalServerError('Restore verification failed.');
    }

    const receipts = txApp.findCollectionByNameOrId('zar_restore_receipts');
    const receipt = new Record(receipts);
    receipt.set('id', body.requestId);
    receipt.set('workspace', auth.workspaceId);
    receipt.set('actor', actorId);
    receipt.set('protocolVersion', ZAR_RESTORE_PROTOCOL_VERSION);
    receipt.set('snapshotHash', validated.snapshotHash);
    receipt.set('beforeHash', before.stateHash);
    receipt.set('afterHash', after.stateHash);
    receipt.set('counts', validated.counts);
    txApp.save(receipt);
    response = zarRestoreReceiptResponse(receipt, false);
  });
  return e.json(200, response);
}

module.exports = Object.freeze({
  state: zarRestoreStateRoute,
  commit: zarRestoreCommitRoute,
});
