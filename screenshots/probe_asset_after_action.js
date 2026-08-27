const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true});
  const page=await browser.newPage({viewport:{width:390,height:844}});
  const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w=(ms)=>page.waitForTimeout(ms);
  const tap=async(x,y,ms=700)=>{await page.mouse.click(x,y);await w(ms);};
  await page.goto(base,{waitUntil:'networkidle'}); await w(4000);
  await tap(195,810,1000); // quick add
  await tap(260,332,900); // فروش
  await page.screenshot({path:'screenshots/probe_asset_base_after_foroosh.png'});
  for (const x of [120,170,220,270,320]) {
    await tap(x,378,800);
    await page.screenshot({path:`screenshots/probe_asset_after_foroosh_${x}.png`});
    // reset to base by reopening quick add
    await page.keyboard.press('Escape'); await w(600);
    await tap(195,810,1000);
    await tap(260,332,900);
  }
  await browser.close();
})();
