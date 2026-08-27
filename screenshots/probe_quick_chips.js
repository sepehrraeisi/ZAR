const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });

  const opXs = [70, 140, 220, 300, 340];
  for (const x of opXs) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.mouse.click(195, 810); // open quick add
    await page.waitForTimeout(700);
    await page.mouse.click(x, 244); // operation row
    await page.waitForTimeout(500);
    await page.screenshot({ path: `screenshots/probe_quick_op_${x}.png`, fullPage: false });
    await context.close();
  }

  const assetXs = [90, 170, 250, 320];
  for (const x of assetXs) {
    const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
    const page = await context.newPage();
    await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
    await page.waitForTimeout(5000);
    await page.mouse.click(195, 810); // open
    await page.waitForTimeout(700);
    await page.mouse.click(300, 244); // select operation first
    await page.waitForTimeout(300);
    await page.mouse.click(x, 314); // asset row
    await page.waitForTimeout(500);
    await page.screenshot({ path: `screenshots/probe_quick_asset_${x}.png`, fullPage: false });
    await context.close();
  }

  await browser.close();
})();
