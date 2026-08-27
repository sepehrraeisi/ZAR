const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const xs = [60,110,160,210,260,310,350];
  const ys = [430,470,510,550,590,630,670,710,750];

  for (const y of ys) {
    for (const x of xs) {
      const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
      const page = await context.newPage();
      await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await page.waitForTimeout(4500);
      await page.mouse.click(195, 810);
      await page.waitForTimeout(700);
      await page.mouse.click(x, y);
      await page.waitForTimeout(350);
      await page.screenshot({ path: `screenshots/quick2_try_${x}_${y}.png`, fullPage: false });
      await context.close();
    }
  }

  await browser.close();
})();
