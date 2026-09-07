import {_electron as electron,expect} from '@playwright/test';
import {mkdtemp,rm} from 'node:fs/promises';import os from 'node:os';import path from 'node:path';
const dir=await mkdtemp(path.join(os.tmpdir(),'nibra-test-'));
const app=await electron.launch({args:['.',`--user-data-dir=${dir}`],cwd:process.cwd()});
const p=await app.firstWindow();const errors=[];p.on('pageerror',e=>errors.push(e.message));
try{
 await p.getByText('Start with my workspace',{exact:true}).click();
 await expect(p.getByRole('heading',{name:'Make space for what matters most.'})).toBeVisible();
 await p.screenshot({path:'../nibra-today.png',fullPage:true});
 await p.getByRole('button',{name:'Add your first priority'}).click();
 await p.getByLabel('Title',{exact:true}).fill('Ship Nibra desktop');await p.getByLabel('Details',{exact:true}).fill('Verify real local workflows');await p.getByRole('button',{name:'Save task',exact:true}).click();
 await expect(p.getByRole('heading',{name:'Ship Nibra desktop'})).toBeVisible();
 await p.locator('nav button[title="Commitments"]').click();
 await p.getByRole('button',{name:'Complete Ship Nibra desktop',exact:true}).click();
 await p.getByRole('button',{name:'Completed 1',exact:true}).click();
 await expect(p.getByRole('button',{name:'Reopen Ship Nibra desktop'})).toBeVisible();
 await p.reload();await expect(p.getByRole('button',{name:'Reopen Ship Nibra desktop'})).toBeVisible();
 await p.getByRole('button',{name:'Memory',exact:true}).click();await p.getByRole('button',{name:'Add memory',exact:true}).click();await p.getByLabel('What should Nibra remember?').fill('Keep answers concise.');await p.getByLabel('Private — prevent model access').check();await p.getByRole('button',{name:'Save memory',exact:true}).click();await expect(p.getByText('Keep answers concise.',{exact:true})).toBeVisible();
 await p.locator('nav button[title="Actions"]').click();await p.getByRole('button',{name:'Prepare draft',exact:true}).click();await p.getByLabel('Title',{exact:true}).fill('Release checklist');await p.getByLabel('Details',{exact:true}).fill('Review before publishing.');await p.getByRole('button',{name:'Prepare for review',exact:true}).click();await p.getByRole('button',{name:'Approve once',exact:true}).click();
 await p.getByRole('button',{name:'Inbox',exact:true}).click();await expect(p.getByRole('heading',{name:'Release checklist',exact:true})).toBeVisible();
 await p.getByRole('button',{name:'Pause Nibra',exact:true}).click();await expect(p.getByText('Nibra is paused. Model requests are stopped. Local editing remains available.')).toBeVisible();
 await p.getByRole('button',{name:'Settings',exact:true}).click();await p.getByLabel('Appearance').selectOption('light');await expect(p.locator('html')).toHaveAttribute('data-theme','light');
 await p.getByRole('button',{name:'Today',exact:true}).click();await p.screenshot({path:'../nibra-light.png',fullPage:true});
 await p.getByRole('button',{name:'Settings',exact:true}).click();await p.getByLabel('Appearance').selectOption('dark');await p.getByRole('button',{name:'Today',exact:true}).click();
 await p.setViewportSize({width:390,height:844});await p.screenshot({path:'../nibra-mobile.png',fullPage:true});
 const overflow=await p.evaluate(()=>document.documentElement.scrollWidth>innerWidth);if(overflow)throw Error('Narrow layout overflows');
 if(errors.length)throw Error(errors.join('\n'));
 console.log('PASS: desktop launch, empty workspace, task create/complete/persist, private memory, draft approval, inbox save, emergency pause, themes, narrow layout, no runtime errors.');
}finally{await app.close();await rm(dir,{recursive:true,force:true})}
