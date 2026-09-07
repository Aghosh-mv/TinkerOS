import {mkdir,copyFile} from 'node:fs/promises';await mkdir('dist/server',{recursive:true});await copyFile('server/worker.mjs','dist/server/index.js');
