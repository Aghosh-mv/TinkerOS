const {app,safeStorage,shell}=require('electron');const fs=require('node:fs');const path=require('node:path');const crypto=require('node:crypto');
const ORIGIN=require('../server/config.json').origin;let current=null,pending=null,localReady=false;
const filename=()=>path.join(app.getPath('userData'),'account.enc');
function readSession(){try{return JSON.parse(safeStorage.decryptString(fs.readFileSync(filename())))}catch{return null}}
function saveSession(session){if(!safeStorage.isEncryptionAvailable()||safeStorage.getSelectedStorageBackend?.()==='basic_text')throw Error('Secure OS credential storage is unavailable.');fs.writeFileSync(filename(),safeStorage.encryptString(JSON.stringify(session)),{mode:0o600});}
async function api(route,body,method='POST',accessToken){const r=await fetch(ORIGIN+route,{method,headers:{'Content-Type':'application/json',...(accessToken?{Authorization:'Bearer '+accessToken}:{})},...(body?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(20000),redirect:'error'});let data;try{data=await r.json()}catch{throw Error('The account service is not available yet. Please try again shortly.')}if(!r.ok)throw Error(data.error||'Sign-in is unavailable.');return data}
module.exports={
 async status(){const session=readSession();if(!session){current=null;return {user:null,local:localReady}}try{const r=await api('/api/session',null,'GET',session.accessToken);current=r.user;return {user:r.user}}catch{current=null;return {user:null,error:'Sign in to reconnect your account.'}}},
 user(){return current},owner(){return current?crypto.createHash('sha256').update(current.id).digest('hex'):'local'},
 async begin(){pending=await api('/api/device/start',{});await shell.openExternal(pending.verificationUrl);return {userCode:pending.userCode,expiresAt:pending.expiresAt}},
 async poll(){if(!pending)throw Error('Start sign-in first.');const r=await api('/api/device/poll',{deviceCode:pending.deviceCode});if(r.pending)return r;saveSession(r);current=r.user;pending=null;return {user:r.user}},
 async signout(){const session=readSession();if(session){try{await api('/api/session',null,'DELETE',session.accessToken)}catch{throw Error('Unable to revoke this session. Reconnect and try signing out again.')}}fs.rmSync(filename(),{force:true});current=null;pending=null;localReady=false;return {ok:true}},
 local(){localReady=true;if(readSession())throw Error('Sign out before opening local mode.');current=null;return {user:null}},
 root(){const root=path.join(app.getPath('userData'),'profiles',this.owner());fs.mkdirSync(root,{recursive:true,mode:0o700});return root},
 read(){const p=path.join(this.root(),'workspace.enc');try{return JSON.parse(safeStorage.decryptString(fs.readFileSync(p)))}catch(e){if(fs.existsSync(p))throw Error('Your workspace could not be decrypted. It has not been overwritten.');return null}},
 write(state){if(!safeStorage.isEncryptionAvailable()||safeStorage.getSelectedStorageBackend?.()==='basic_text')throw Error('Secure local storage is unavailable. Export your workspace before closing.');const data=JSON.stringify(state);if(Buffer.byteLength(data)>10*1024*1024)throw Error('Workspace exceeds the 10 MB local limit. Export older notes.');const p=path.join(this.root(),'workspace.enc');fs.writeFileSync(p+'.tmp',safeStorage.encryptString(data),{mode:0o600});fs.renameSync(p+'.tmp',p);return {ok:true}}
};
