const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const coords = [45, 115, 195, 275, 345];

  for (const x of coords) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.mouse.click(x, 810);
    await page.waitForTimeout(1200);
    await page.screenshot({ path: `screenshots/probe_tab_${x}.png`, fullPage: false });
    await context.close();
  }

  await browser.close();
})();
