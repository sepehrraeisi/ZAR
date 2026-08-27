const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const base = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';

  const wait = (ms) => page.waitForTimeout(ms);
  const tap = async (x, y, ms = 700) => {
    await page.mouse.click(x, y);
    await wait(ms);
  };
  const shot = async (name) => {
    await wait(350);
    await page.screenshot({ path: `screenshots/${name}.png`, fullPage: false });
  };

  await page.goto(base, { waitUntil: 'networkidle' });
  await wait(4500);

  // Ensure start from Home tab (right-most in RTL layout)
  await tap(345, 810, 900);

  // Open Quick Add
  await tap(195, 810, 900);

  // Select valid action + asset
  await tap(305, 246, 500); // فروش
  await tap(270, 378, 700); // ارز

  // 1) Jalali Date Picker
  await tap(195, 560, 900); // تاریخ row
  await shot('a1_fix_01_jalali_date_picker');

  // Close date picker/dialog (tap outside)
  await tap(24, 84, 700);

  // 2) Time Picker
  await tap(195, 590, 900); // ساعت row
  await shot('a1_fix_02_time_picker');

  // Close time picker (tap outside)
  await tap(24, 84, 700);

  // 3) Reminder Picker
  await tap(195, 650, 900); // یادآوری row
  await shot('a1_fix_03_reminder_picker');

  // Close reminder picker by choosing first option
  await tap(195, 382, 700);

  // 4) Currency Picker
  // Deterministic reset to Quick Add form before currency capture
  await page.goto(base, { waitUntil: 'networkidle' });
  await wait(2500);
  await tap(345, 810, 900); // Home
  await tap(195, 810, 900); // Quick Add
  await tap(260, 332, 500); // فروش (calibrated for currency row)
  await tap(270, 378, 700); // ارز
  await tap(195, 430, 900); // نوع ارز row
  await shot('a1_fix_04_currency_picker');

  // 5) Currency Entry with Selected Currency (USD) + formatted sample amount
  await tap(195, 300, 700); // select first currency row (USD)
  await tap(190, 502, 400); // مبلغ input
  await page.keyboard.press('Control+A');
  await page.keyboard.type('$10,000');
  await wait(400);
  await shot('a1_fix_05_currency_entry_usd');

  // Close quick add
  await page.keyboard.press('Escape');
  await wait(900);

  // Navigate to People tab
  await tap(115, 810, 900);

  // 6) Add Person sheet
  await tap(70, 92, 900); // + افزودن (top-left in people header)
  await shot('a1_fix_06_add_person');

  // Close add person sheet
  await page.keyboard.press('Escape');
  await wait(800);

  // Open first person in list
  await tap(190, 222, 900);

  // 7) Edit Person sheet (capture after opening edit)
  await tap(300, 150, 900); // ویرایش button in person header actions
  await shot('a1_fix_07_edit_person');

  // Close edit sheet and capture person detail actions (order requirement)
  await page.keyboard.press('Escape');
  await wait(700);
  await shot('a1_fix_08_person_detail_actions');

  // 9) History tab (hard reset to Home shell, then History)
  await page.goto(base, { waitUntil: 'networkidle' });
  await wait(2500);
  await tap(345, 810, 900); // Home
  await tap(45, 810, 900);  // History
  await shot('a1_fix_09_history_tab');

  await browser.close();
})();
