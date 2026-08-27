const { chromium } = require('playwright');
(async()=>{
  const browser = await chromium.launch({headless:true});
  const page = await browser.newPage({viewport:{width:390,height:844}});
  const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w=(ms)=>page.waitForTimeout(ms);
  const tap=async(x,y,ms=900)=>{await page.mouse.click(x,y); await w(ms);};
  await page.goto(base,{waitUntil:'networkidle'}); await w(4000);
  await tap(345,810,800);
  for (const x of [345,275,195,115,45]) {
    await tap(x,810,1000);
    await page.screenshot({path:`screenshots/probe_bottom_now_${x}.png`});
  }
  await browser.close();
})();
