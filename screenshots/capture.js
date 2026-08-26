const { chromium } = require('playwright');

(async () => {
  const baseUrl = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const page = await context.newPage();

  await page.goto(baseUrl, { waitUntil: 'domcontentloaded', timeout: 120000 });
  await page.waitForTimeout(9000);

  // 1) Home
  await page.screenshot({ path: 'screenshots/01_home.png', fullPage: false });

  // Open Quick Add by tapping center nav (+)
  await page.mouse.click(195, 810);
  await page.waitForTimeout(900);
  await page.screenshot({ path: 'screenshots/02_quick_add_initial.png', fullPage: false });

  // Select operation + asset chips
  await page.mouse.click(300, 244); // دریافت chip area
  await page.waitForTimeout(250);
  await page.mouse.click(300, 315); // طلا chip area
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'screenshots/03_quick_add_selected.png', fullPage: false });

  // Close sheet by tapping top area
  await page.mouse.click(20, 80);
  await page.waitForTimeout(800);

  // Calendar tab
  await page.mouse.click(115, 810);
  await page.waitForTimeout(1300);
  await page.screenshot({ path: 'screenshots/04_calendar_month.png', fullPage: false });

  // Tap a date in month grid and capture agenda state
  await page.mouse.click(245, 350);
  await page.waitForTimeout(700);
  await page.screenshot({ path: 'screenshots/05_calendar_agenda.png', fullPage: false });

  // People tab
  await page.mouse.click(275, 810);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'screenshots/06_people.png', fullPage: false });

  // Person detail (first row)
  await page.mouse.click(180, 198);
  await page.waitForTimeout(1200);
  await page.screenshot({ path: 'screenshots/07_person_detail.png', fullPage: false });

  await browser.close();
})();
