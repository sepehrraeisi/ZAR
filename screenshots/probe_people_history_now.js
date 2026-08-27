const { chromium } = require('playwright');
(async()=>{
  const browser=await chromium.launch({headless:true});
  const page=await browser.newPage({viewport:{width:390,height:844}});
  const base='https://5060-i750bpqnp0a6nrktqm802-0e616f0a.sandbox.novita.ai';
  const w=(ms)=>page.waitForTimeout(ms);
  const tap=async(x,y,ms=1000)=>{await page.mouse.click(x,y); await w(ms);};
  await page.goto(base,{waitUntil:'networkidle'}); await w(4000);
  await tap(345,810,1000); // home
  await page.screenshot({path:'screenshots/probe_home_now.png'});
  await tap(45,810,1200); // likely history
  await page.screenshot({path:'screenshots/probe_history_x45.png'});
  await tap(345,810,1200); // back home
  await tap(115,810,1200); // likely people
  await page.screenshot({path:'screenshots/probe_people_x115.png'});
  await browser.close();
})();
