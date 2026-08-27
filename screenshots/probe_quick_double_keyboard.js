const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });

  for (let t1=1; t1<=4; t1++) {
    for (let t2=1; t2<=8; t2++) {
      const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
      const page = await context.newPage();
      await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
      await page.waitForTimeout(4500);
      await page.mouse.click(195, 810);
      await page.waitForTimeout(900);
      for (let i=0; i<t1; i++) { await page.keyboard.press('Tab'); await page.waitForTimeout(60);} 
      await page.keyboard.press('Space');
      await page.waitForTimeout(250);
      for (let i=0; i<t2; i++) { await page.keyboard.press('Tab'); await page.waitForTimeout(60);} 
      await page.keyboard.press('Space');
      await page.waitForTimeout(300);
      await page.screenshot({ path: `screenshots/quick_key_double_${t1}_${t2}.png`, fullPage: false });
      await context.close();
    }
  }
  await browser.close();
})();
