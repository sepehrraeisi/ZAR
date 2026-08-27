const { chromium } = require('playwright');
(async()=>{
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w=(ms)=>page.waitForTimeout(ms);
  const tap=async(x,y,ms=700)=>{await page.mouse.click(x,y); await w(ms);};
  await page.goto(base,{waitUntil:'networkidle'});
  await w(4000);
  await page.screenshot({path:'screenshots/probe_now_01_home.png'});
  await tap(195,810,1000);
  await page.screenshot({path:'screenshots/probe_now_02_quickadd.png'});
  // probe action row y around 330
  for (const x of [80,140,200,260,320]) { await tap(x,332,600); await page.screenshot({path:`screenshots/probe_now_action_${x}.png`}); }
  // reset by reopening quick add if closed
  await page.keyboard.press('Escape'); await w(600);
  await tap(195,810,1000);
  await page.screenshot({path:'screenshots/probe_now_03_quickadd_reset.png'});
  for (const x of [80,140,200,260,320]) { await tap(x,378,600); await page.screenshot({path:`screenshots/probe_now_asset_${x}.png`}); }
  await browser.close();
})();
