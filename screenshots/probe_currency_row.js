const { chromium } = require('playwright');
(async()=>{
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w=(ms)=>page.waitForTimeout(ms);
  const tap=async(x,y,ms=800)=>{await page.mouse.click(x,y); await w(ms);};
  await page.goto(base,{waitUntil:'networkidle'}); await w(4000);
  await tap(345,810,900); // home
  await tap(195,810,900); // quick add
  await tap(260,332,800); // foroosh
  await tap(270,378,900); // arz
  await page.screenshot({path:'screenshots/probe_currencyrow_base.png'});
  for (const y of [430,450,470,490,510,530]) {
    await tap(195,y,900);
    await page.screenshot({path:`screenshots/probe_currencyrow_y${y}.png`});
    await page.keyboard.press('Escape'); await w(600);
    // restore if sheet closed entire panel
    await tap(195,810,500);
    await tap(260,332,500);
    await tap(270,378,700);
  }
  await browser.close();
})();
