const { chromium } = require('playwright');
(async()=>{
 const browser=await chromium.launch({headless:true});
 const page=await browser.newPage({viewport:{width:390,height:844}});
 const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
 const wait=(ms)=>page.waitForTimeout(ms);
 const tap=async(x,y,ms=700)=>{await page.mouse.click(x,y); await wait(ms);} 
 await page.goto(base,{waitUntil:'networkidle'}); await wait(3500);
 await tap(345,810,800); //home
 await tap(195,810,900); //quick add
 await tap(240,335,700); //op chip approx
 await tap(195,375,900); //asset ارز approx
 await page.screenshot({path:'screenshots/probe_currency_presence.png'});
 await browser.close();
})();
