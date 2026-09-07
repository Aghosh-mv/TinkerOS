export type Task={id:string;title:string;detail:string;project:string;status:'Open'|'Waiting'|'Completed';person:string;due:string;created:string};
export type Project={id:string;name:string;description:string;goal:string;created:string};
export type Memory={id:string;content:string;category:string;source:string;created:string;locked:boolean;private:boolean};
export type AgentAction={id:string;type:string;title:string;payload:Record<string,any>;status:'Awaiting approval'|'Completed'|'Cancelled';created:string;error?:string};
export type Conversation={id:string;title:string;messages:{role:string;content:string;actionIds?:string[]}[];created:string};
export type Action={id:string;title:string;content:string;status:'Awaiting approval'|'Completed'|'Cancelled';created:string};
export type Note={id:string;title:string;content:string;created:string};
export type ModelConfig={provider:string;model:string;endpoint:string};
export type State={version:number;agentActions:AgentAction[];conversations:Conversation[];activeConversation:string;budget:{monthlyLimit:number;currency:string;notes:string};contextEnabled:boolean;onboarded:boolean;theme:string;paused:boolean;memoryPaused:boolean;name:string;style:string;tasks:Task[];projects:Project[];memories:Memory[];actions:Action[];notes:Note[];logs:{id:string;text:string;time:string}[];messages:{role:string;content:string;actionIds?:string[]}[];model:ModelConfig;focusUntil:number;focusTask:string;};
export function initialState():State{return {version:3,agentActions:[],conversations:[],activeConversation:'',budget:{monthlyLimit:0,currency:'USD',notes:''},contextEnabled:false,onboarded:false,theme:'dark',paused:false,memoryPaused:false,name:'',style:'Concise',tasks:[],projects:[],memories:[],actions:[],notes:[],logs:[],messages:[],model:{provider:'Local / Ollama',model:'',endpoint:'http://127.0.0.1:11434/v1'},focusUntil:0,focusTask:''};}
