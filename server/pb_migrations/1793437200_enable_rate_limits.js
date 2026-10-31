/// Enable a ZAR-specific PocketBase 0.40.4 rate-limit policy.
///
/// The stock disabled rules are not safe for this application: `*:create`
/// and a low all-audience `/api/` fallback are also evaluated for internal
/// `/api/batch` subrequests and would break the supported 500-operation
/// atomic restore. This policy therefore limits sensitive public actions,
/// authenticated outer batch calls and unauthenticated API traffic without a
/// generic cap on authenticated domain CRUD.

const baselineRules = [
  { label: '*:auth', audience: '', duration: 3, maxRequests: 2 },
  { label: '*:create', audience: '', duration: 5, maxRequests: 20 },
  { label: '/api/batch', audience: '', duration: 1, maxRequests: 3 },
  { label: '/api/', audience: '', duration: 10, maxRequests: 300 },
];

const deployedRules = [
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

function hasNoExcludedIPs(settings) {
  return (
    settings.rateLimits.excludedIPs &&
    settings.rateLimits.excludedIPs.length === 0
  );
}

migrate((app) => {
  const settings = app.settings();
  if (
    settings.rateLimits.enabled ||
    !hasNoExcludedIPs(settings) ||
    !sameRules(settings.rateLimits.rules, baselineRules)
  ) {
    throw new Error(
      'Refusing to replace a rate-limit configuration that differs from the reviewed baseline.',
    );
  }

  settings.rateLimits.rules = deployedRules;
  settings.rateLimits.excludedIPs = [];
  settings.rateLimits.enabled = true;
  return app.save(settings);
}, (app) => {
  const settings = app.settings();
  if (
    !settings.rateLimits.enabled ||
    !hasNoExcludedIPs(settings) ||
    !sameRules(settings.rateLimits.rules, deployedRules)
  ) {
    throw new Error(
      'Refusing to roll back a rate-limit configuration that has drifted since deployment.',
    );
  }

  settings.rateLimits.rules = baselineRules;
  settings.rateLimits.excludedIPs = [];
  settings.rateLimits.enabled = false;
  return app.save(settings);
});
