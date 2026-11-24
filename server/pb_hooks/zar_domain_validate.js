/// Shared domain payload checks for ordinary cloud writes (ZAR-DATA-003).
///
/// Mirrors the restore-route structural rules for amounts/pricing without the
/// full restore accounting graph. Write CAS calls this before persist.

const ZAR_DOMAIN_ID_PATTERN = /^[A-Za-z0-9_-]{2,255}$/;
const ZAR_DOMAIN_DECIMAL_PATTERN = /^\d+(?:\.\d+)?$/;
const ZAR_DOMAIN_MAX_EXACT = 9007199254740991;

function zarDomainIsObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value);
}

function zarDomainEnum(value, allowed, field) {
  if (typeof value !== 'string' || allowed.indexOf(value) === -1) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return value;
}

function zarDomainRequiredString(value, field) {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return value;
}

function zarDomainPositiveInteger(value, field) {
  if (
    !Number.isSafeInteger(value) ||
    value <= 0 ||
    value > ZAR_DOMAIN_MAX_EXACT
  ) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return value;
}

function zarDomainUnsignedDecimal(value, field) {
  if (typeof value !== 'string' || !ZAR_DOMAIN_DECIMAL_PATTERN.test(value)) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return value;
}

function zarDomainValidateFineness(value, field) {
  const text = zarDomainRequiredString(String(value), field).trim();
  if (!/^\d{1,4}$/.test(text)) {
    throw new BadRequestError(field + ' is invalid.');
  }
  const number = Number(text);
  if (number < 1 || number > 9999) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return text;
}

function zarDomainToman(raw, field) {
  if (!zarDomainIsObject(raw)) {
    throw new BadRequestError(field + ' is invalid.');
  }
  return zarDomainPositiveInteger(raw.wholeTomans, field);
}

function zarDomainLoadCoinTypeIds(app, workspaceId) {
  const rows = app.findRecordsByFilter(
    'zar_coin_types',
    'workspace = {:workspace}',
    'id',
    5000,
    0,
    { workspace: workspaceId },
  );
  const map = Object.create(null);
  for (let i = 0; i < rows.length; i++) {
    map[rows[i].id] = true;
  }
  return map;
}

function zarDomainParseAssetAmount(rawAmount, coinTypes, field) {
  if (!zarDomainIsObject(rawAmount)) {
    throw new BadRequestError(field + ' amount is invalid.');
  }
  const assetType = zarDomainEnum(
    rawAmount.assetType,
    ['gold', 'currency', 'coin'],
    field + ' asset type',
  );

  if (assetType === 'currency') {
    const value = rawAmount.currency;
    if (!zarDomainIsObject(value)) {
      throw new BadRequestError(field + ' currency is invalid.');
    }
    const code = zarDomainRequiredString(value.code, field + ' currency code');
    if (code !== code.toUpperCase()) {
      throw new BadRequestError(field + ' currency code is invalid.');
    }
    const minorUnits = zarDomainPositiveInteger(
      value.minorUnits,
      field + ' currency minor units',
    );
    const scale = value.minorUnitScale;
    if (!Number.isSafeInteger(scale) || scale < 0 || scale > 6) {
      throw new BadRequestError(field + ' currency scale is invalid.');
    }
    return { assetType: assetType, code: code, minorUnits: minorUnits, scale: scale, lineIds: null };
  }

  if (assetType === 'gold') {
    const value = rawAmount.gold;
    if (!zarDomainIsObject(value)) {
      throw new BadRequestError(field + ' gold is invalid.');
    }
    zarDomainUnsignedDecimal(value.decimal, field + ' gold quantity');
    zarDomainEnum(
      value.unit,
      ['gram', 'mesghal', 'coin', 'item'],
      field + ' gold unit',
    );
    let purity = 'unknown';
    if (value.purity !== null && value.purity !== undefined) {
      purity = zarDomainRequiredString(value.purity, field + ' gold purity').trim();
    }
    return { assetType: assetType, purity: purity, lineIds: null };
  }

  if (!Array.isArray(rawAmount.coinLines) || rawAmount.coinLines.length === 0) {
    throw new BadRequestError(field + ' coin lines are invalid.');
  }
  const lineIds = Object.create(null);
  for (let i = 0; i < rawAmount.coinLines.length; i++) {
    const line = rawAmount.coinLines[i];
    if (!zarDomainIsObject(line)) {
      throw new BadRequestError(field + ' coin line is invalid.');
    }
    const lineId = zarDomainRequiredString(line.id, field + ' coin line id');
    if (lineIds[lineId]) {
      throw new BadRequestError(field + ' has duplicate coin lines.');
    }
    const coinTypeId = zarDomainRequiredString(
      line.coinTypeId,
      field + ' coin type id',
    );
    if (!coinTypes[coinTypeId]) {
      throw new BadRequestError(field + ' references a missing coin type.');
    }
    zarDomainRequiredString(line.coinTypeNameSnapshot, field + ' coin name');
    zarDomainPositiveInteger(line.quantity, field + ' coin quantity');
    if (line.weightPerPieceGrams !== null && line.weightPerPieceGrams !== undefined) {
      zarDomainUnsignedDecimal(line.weightPerPieceGrams, field + ' coin weight');
    }
    if (line.fineness !== null && line.fineness !== undefined) {
      zarDomainValidateFineness(line.fineness, field + ' coin fineness');
    }
    lineIds[lineId] = true;
  }
  return { assetType: assetType, lineIds: lineIds };
}

function zarDomainValidateLinePricing(rawLines, amount, field, requireAllLines) {
  if (!Array.isArray(rawLines) || rawLines.length === 0 || !amount.lineIds) {
    throw new BadRequestError(field + ' coin pricing is invalid.');
  }
  const seen = Object.create(null);
  let total = 0;
  for (let i = 0; i < rawLines.length; i++) {
    const line = rawLines[i];
    if (!zarDomainIsObject(line)) {
      throw new BadRequestError(field + ' coin pricing line is invalid.');
    }
    const lineId = zarDomainRequiredString(line.lineId, field + ' pricing line id');
    if (!amount.lineIds[lineId] || seen[lineId]) {
      throw new BadRequestError(field + ' coin pricing coverage is invalid.');
    }
    seen[lineId] = true;
    zarDomainEnum(line.method, ['perPiece', 'perGram'], field + ' pricing method');
    zarDomainToman(line.unitPriceToman, field + ' unit price');
    total += zarDomainToman(line.rowTotalToman, field + ' row total');
  }
  if (
    requireAllLines &&
    Object.keys(seen).length !== Object.keys(amount.lineIds).length
  ) {
    throw new BadRequestError(field + ' coin pricing coverage is invalid.');
  }
  return total;
}

function zarDomainValidateDealPricing(raw, amount, field) {
  if (raw === null || raw === undefined) {
    if (amount.assetType === 'coin') {
      throw new BadRequestError(field + ' coin pricing is required.');
    }
    return;
  }
  if (!zarDomainIsObject(raw) || raw.kind !== amount.assetType) {
    throw new BadRequestError(field + ' pricing type is invalid.');
  }
  const total = zarDomainToman(raw.totalToman, field + ' total Toman');
  if (raw.kind === 'gold') {
    const fineness = zarDomainValidateFineness(raw.fineness, field + ' fineness');
    zarDomainValidateFineness(
      raw.priceReferenceFineness,
      field + ' reference fineness',
    );
    zarDomainUnsignedDecimal(raw.inputWeight, field + ' input weight');
    zarDomainEnum(raw.inputWeightUnit, ['gram', 'mesghal'], field + ' input unit');
    zarDomainEnum(raw.priceUnit, ['gram', 'mesghal'], field + ' price unit');
    zarDomainToman(raw.pricePerUnitToman, field + ' unit price');
    if (amount.purity !== 'unknown' && amount.purity !== fineness) {
      throw new BadRequestError(field + ' gold purity is inconsistent.');
    }
  } else if (raw.kind === 'currency') {
    zarDomainUnsignedDecimal(raw.tomanPerUnit, field + ' currency rate');
  } else {
    const lineTotal = zarDomainValidateLinePricing(raw.lines, amount, field, true);
    if (lineTotal !== total) {
      throw new BadRequestError(field + ' coin total is inconsistent.');
    }
  }
}

function zarDomainValidateReminderPlan(raw, field) {
  if (raw === null || raw === undefined) return;
  if (!zarDomainIsObject(raw) || !Array.isArray(raw.rules)) {
    throw new BadRequestError(field + ' reminder plan is invalid.');
  }
  const ids = Object.create(null);
  for (let i = 0; i < raw.rules.length; i++) {
    const rule = raw.rules[i];
    if (!zarDomainIsObject(rule)) {
      throw new BadRequestError(field + ' reminder rule is invalid.');
    }
    const id = zarDomainRequiredString(rule.id, field + ' reminder id');
    if (ids[id]) {
      throw new BadRequestError(field + ' reminder ids are duplicated.');
    }
    ids[id] = true;
    const type = zarDomainEnum(rule.type, ['offset', 'custom'], field + ' reminder type');
    if (typeof rule.enabled !== 'boolean') {
      throw new BadRequestError(field + ' reminder enabled flag is invalid.');
    }
    if (type === 'offset') {
      zarDomainPositiveInteger(rule.minutesBefore, field + ' reminder offset');
    }
  }
}

function zarDomainRequireDeal(app, workspaceId, dealId, field) {
  if (!ZAR_DOMAIN_ID_PATTERN.test(dealId)) {
    throw new BadRequestError(field + ' is invalid.');
  }
  let deal = null;
  try {
    deal = app.findRecordById('zar_deals', dealId);
  } catch (_) {
    deal = null;
  }
  if (!deal || deal.getString('workspace') !== workspaceId) {
    throw new BadRequestError(field + ' references a missing deal.');
  }
}

/// createdBy must stay non-empty. The shipping client still stamps
/// "local-user" on create, so auth-id matching is deferred. On update the
/// original author stamp is immutable.
function zarDomainEnforceActor(data, existingCreatedBy, _actorId, fieldPrefix) {
  zarDomainRequiredString(data.createdBy, fieldPrefix + ' createdBy');
  if (
    typeof existingCreatedBy === 'string' &&
    existingCreatedBy.length > 0 &&
    data.createdBy !== existingCreatedBy
  ) {
    throw new BadRequestError(fieldPrefix + ' createdBy is immutable.');
  }
}

function zarDomainValidateDealPayload(app, workspaceId, data, actorId, existingCreatedBy) {
  const coinTypes = zarDomainLoadCoinTypeIds(app, workspaceId);
  const amount = zarDomainParseAssetAmount(data.amount, coinTypes, 'deal');
  zarDomainValidateDealPricing(data.pricing, amount, 'deal');
  zarDomainEnforceActor(data, existingCreatedBy, actorId, 'deal');
}

function zarDomainValidateSettlementPayload(
  app,
  workspaceId,
  data,
  actorId,
  existingCreatedBy,
) {
  const coinTypes = zarDomainLoadCoinTypeIds(app, workspaceId);
  zarDomainParseAssetAmount(data.amount, coinTypes, 'settlement');
  if (data.dealId !== null && data.dealId !== undefined) {
    zarDomainRequireDeal(app, workspaceId, data.dealId, 'settlement dealId');
  }
  zarDomainValidateReminderPlan(data.reminderPlan, 'settlement');
  if (data.coinValuation !== null && data.coinValuation !== undefined) {
    if (!zarDomainIsObject(data.coinValuation)) {
      throw new BadRequestError('settlement coin valuation is invalid.');
    }
  }
  zarDomainEnforceActor(data, existingCreatedBy, actorId, 'settlement');
}

function zarDomainValidatePersonPayload(data, actorId, existingCreatedBy) {
  zarDomainEnforceActor(data, existingCreatedBy, actorId, 'person');
}

module.exports = {
  validateDealPayload: zarDomainValidateDealPayload,
  validateSettlementPayload: zarDomainValidateSettlementPayload,
  validatePersonPayload: zarDomainValidatePersonPayload,
  parseAssetAmount: zarDomainParseAssetAmount,
};
