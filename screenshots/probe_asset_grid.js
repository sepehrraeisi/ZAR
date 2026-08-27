const { chromium } = require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
 const xs=[120,170,220,270,320];
 const ys=[372,388,404];
 for(const y of ys){
  for(const x of xs){
   const context=await browser.newContext({viewport:{width:390,height:844}});
   const page=await context.newPage();
   const wait=(ms)=>page.waitForTimeout(ms);
   await page.goto(base,{waitUntil:'networkidle'}); await wait(3200);
   await page.mouse.click(345,810); await wait(700);
   await page.mouse.click(195,810); await wait(900);
   await page.mouse.click(240,335); await wait(700); // فروش
   await page.mouse.click(x,y); await wait(700);
   await page.screenshot({path:`screenshots/probe_asset_${x}_${y}.png`});
   await context.close();
  }
 }
 await browser.close();
})();
