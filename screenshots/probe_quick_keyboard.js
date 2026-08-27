const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });

  for (let tabs=0; tabs<=15; tabs++) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForTimeout(4500);
    await page.mouse.click(195, 810);
    await page.waitForTimeout(900);
    for (let i=0; i<tabs; i++) {
      await page.keyboard.press('Tab');
      await page.waitForTimeout(80);
    }
    await page.keyboard.press('Space');
    await page.waitForTimeout(250);
    await page.screenshot({ path: `screenshots/quick_key_tabs_${tabs}.png`, fullPage: false });
    await context.close();
  }

  await browser.close();
})();
