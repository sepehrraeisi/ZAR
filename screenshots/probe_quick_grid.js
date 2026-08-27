const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const xs = [60,100,140,180,220,260,300,340];
  const ys = [220,250,280,310,340,370,400];

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
      await page.screenshot({ path: `screenshots/quick_try_${x}_${y}.png`, fullPage: false });
      await context.close();
    }
  }

  await browser.close();
})();
