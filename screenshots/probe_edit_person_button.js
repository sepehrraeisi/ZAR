const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 390, height: 844 } });
  const base = 'https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w = (ms) => page.waitForTimeout(ms);
  const tap = async (x,y,ms=900)=>{ await page.mouse.click(x,y); await w(ms); };

  await page.goto(base, { waitUntil: 'networkidle' });
  await w(3500);
  await tap(345,810,900); // home
  await tap(115,810,1100); // people
  await tap(190,222,1200); // first person
  await page.screenshot({path:'screenshots/probe_detail_base.png'});

  const pts = [
    [300,150],[260,150],[220,150],[180,150],[140,150],
    [300,170],[260,170],[220,170],[180,170],[140,170],
    [300,200],[260,200],[220,200],[180,200],[140,200],
    [300,230],[260,230],[220,230],[180,230],[140,230],
    [298,273]
  ];
  for (const [x,y] of pts) {
    await tap(x,y,900);
    await page.screenshot({path:`screenshots/probe_edit_btn_${x}_${y}.png`});
    await page.keyboard.press('Escape');
    await w(550);
  }
  await browser.close();
})();
