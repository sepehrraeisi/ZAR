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
  await page.screenshot({path:'screenshots/probe_people_base.png'});

  const pts = [
    [44,92],[70,92],[95,92],[44,120],[70,120],[95,120],[44,150],[70,150],[95,150]
  ];
  for (const [x,y] of pts) {
    await tap(x,y,900);
    await page.screenshot({path:`screenshots/probe_add_btn_${x}_${y}.png`});
    await page.keyboard.press('Escape');
    await w(500);
  }
  await browser.close();
})();
