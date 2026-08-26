const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();
  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForTimeout(9000);
  await page.mouse.click(115, 810);
  await page.waitForTimeout(1200);
  await page.screenshot({
    path: 'screenshots/05_calendar_agenda.png',
    clip: { x: 0, y: 390, width: 390, height: 454 }
  });
  await browser.close();
})();
