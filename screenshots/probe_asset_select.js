const { chromium } = require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
 const taps=[120,170,220,270,320,350];
 const wait=(ms)=>page.waitForTimeout(ms);
 const tap=async(x,y,ms=500)=>{await page.mouse.click(x,y); await wait(ms);};
 for(const x of taps){
  await page.goto(base,{waitUntil:'networkidle'}); await wait(2500);
  await tap(345,810,700); // home
  await tap(195,810,900); // plus
  await tap(305,246,500); // sale
  await tap(x,375,700);   // asset row candidate
  await page.screenshot({path:`screenshots/probe_asset_x${x}.png`});
 }
 await browser.close();
})();
