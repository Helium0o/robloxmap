import {chromium} from 'playwright-core';
const [car,out,extra]=process.argv.slice(2);
// CHROME_PATH: any local Chrome/Chromium (e.g. C:/Program Files/Google/Chrome/Application/chrome.exe)
const b=await chromium.launch({executablePath:process.env.CHROME_PATH||undefined,args:['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader']});
const p=await b.newPage({viewport:{width:1600,height:1000}});
p.on('console',m=>console.log(m.text())); p.on('pageerror',e=>console.log('ERR',e.message));
await p.goto(`http://localhost:8765/tools/preview.html?car=${car}${extra||''}`);
await p.waitForFunction(()=>document.title==='done',null,{timeout:120000});
await p.screenshot({path:out}); await b.close();
