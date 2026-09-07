import {initialState,type State,type ModelConfig} from './data';
export interface ModelProvider {complete(prompt:string,context:string):Promise<string>}
export interface IntegrationProvider {id:string;connect():Promise<void>;disconnect():Promise<void>}
export interface PermissionManager {canRead(source:string):boolean;revoke(source:string):void}
export interface MemoryStore {search(query:string):State['memories'];forget(id:string):void}
export interface ActionRunner {approve(id:string):void;cancel(id:string):void}
export interface ActivityLogger {record(text:string):void}
export interface NotificationManager {notify(text:string):void}
export interface SearchIndex {search(query:string):{title:string;page:string}[]}
export interface WorkspaceStore {load():State;save(state:State):void}
let cached:State|null=null;let owner='local';
export async function initializeWorkspace(){if(window.nibra){const id=await window.nibra.accountOwner();owner=id.owner;const r=await window.nibra.workspaceRead();if(r.error)throw Error(r.error);cached=r.state?{...initialState(),...r.state}:initialState();const model=await window.nibra.modelInfo();if(model.provider!=='Unconfigured')cached.model={provider:model.provider,model:model.model,endpoint:model.endpoint};}else{try{cached={...initialState(),...JSON.parse(localStorage.getItem('nibra.workspace.v3.local')||'{}')}}catch{cached=initialState()}}}
export const workspace:WorkspaceStore={load(){return cached||initialState()},save(state){cached=state;if(window.nibra){void window.nibra.workspaceWrite(state,owner).then(r=>{if(r.error)window.dispatchEvent(new CustomEvent('nibra-storage-error',{detail:r.error}))})}else localStorage.setItem('nibra.workspace.v3.local',JSON.stringify(state))}};
declare global {interface Window {nibra?:{
modelInfo:()=>Promise<ModelConfig&{hasSavedKey:boolean}>;configure:(c:ModelConfig&{key?:string})=>Promise<{ok:boolean;error?:string}>;
complete:(prompt:string,context:string,history?:{role:string;content:string}[])=>Promise<{text?:string;error?:string}>;
test:()=>Promise<{ok:boolean;error?:string}>;pause:(value:boolean)=>Promise<void>;sidecar:()=>void;closeSidecar:()=>void;
accountStatus:()=>Promise<{user:any;local?:boolean;error?:string}>;accountBegin:()=>Promise<{userCode:string;expiresAt:number;error?:string}>;accountPoll:()=>Promise<{user?:any;pending?:boolean;error?:string}>;accountLocal:()=>Promise<any>;accountSignout:()=>Promise<{ok:boolean;error?:string}>;accountOwner:()=>Promise<{owner:string}>;workspaceRead:()=>Promise<{state:State|null;error?:string}>;workspaceWrite:(state:State,owner:string)=>Promise<{ok:boolean;error?:string}>;selectFiles:()=>Promise<{files?:{id:string;name:string;content:string}[];error?:string}>;prepareFile:(data:{filename:string;content:string})=>Promise<any>;approveFile:(id:string)=>Promise<{ok:boolean;path?:string;error?:string}>;downloads:()=>Promise<void>;onWorkspace:(cb:(s:State)=>void)=>()=>void;
}}}
export function exportFile(name:string,value:unknown){const blob=new Blob([typeof value==='string'?value:JSON.stringify(value,null,2)],{type:typeof value==='string'?'text/plain':'application/json'});const url=URL.createObjectURL(blob);const a=document.createElement('a');a.href=url;a.download=name;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
