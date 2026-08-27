const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 393, height: 852 } });
  const page = await context.newPage();

  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForTimeout(4500);

  // 1) Home
  await page.screenshot({ path: 'screenshots/01_home.png', fullPage: false });

  // 2) Quick Add initial
  await page.mouse.click(195, 810);
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'screenshots/02_quick_add_initial.png', fullPage: false });

  // 3) Quick Add selected (operation + asset)
  for (let i = 0; i < 2; i++) {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(60);
  }
  await page.keyboard.press('Space');
  await page.waitForTimeout(250);
  for (let i = 0; i < 4; i++) {
    await page.keyboard.press('Tab');
    await page.waitForTimeout(60);
  }
  await page.keyboard.press('Space');
  await page.waitForTimeout(350);
  await page.screenshot({ path: 'screenshots/03_quick_add_selected.png', fullPage: false });

  // Close sheet
  await page.keyboard.press('Escape');
  await page.waitForTimeout(700);

  // 4) Calendar month
  await page.mouse.click(275, 810);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'screenshots/04_calendar_month.png', fullPage: false });

  // 5) Calendar selected day / agenda
  await page.mouse.click(248, 285);
  await page.waitForTimeout(500);
  await page.mouse.click(304, 345);
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'screenshots/05_calendar_agenda.png', fullPage: false });

  // 6) People
  await page.mouse.click(45, 810);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'screenshots/06_people.png', fullPage: false });

  // 7) Person detail
  await page.mouse.click(200, 204);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: 'screenshots/07_person_detail.png', fullPage: false });

  await context.close();
  await browser.close();
})();
