export const presets:Record<string,{endpoint:string;model:string;hint:string}>={
'Local / Ollama':{endpoint:'http://127.0.0.1:11434/v1',model:'',hint:'Enter a model installed in Ollama, for example llama3.2. No cloud key is needed.'},
'Local / LM Studio':{endpoint:'http://127.0.0.1:1234/v1',model:'',hint:'Start the LM Studio local server and use the exact loaded model ID.'},
'Z.ai':{endpoint:'https://api.z.ai/api/paas/v4',model:'glm-4.7-flash',hint:'General Z.ai API. Enter a GLM model ID, not the company name. Coding Plan subscriptions use a separate endpoint restricted to supported coding tools.'},
'OpenRouter':{endpoint:'https://openrouter.ai/api/v1',model:'',hint:'Use the full provider/model ID from OpenRouter. Use an OpenRouter key.'},
'OpenAI-compatible':{endpoint:'https://api.openai.com/v1',model:'',hint:'Enter the exact model ID available to your account.'},
'Anthropic':{endpoint:'https://api.anthropic.com/v1',model:'',hint:'Enter the exact Claude model ID available to your account.'},
'Google':{endpoint:'https://generativelanguage.googleapis.com/v1beta',model:'',hint:'Enter the Gemini model ID without the models/ prefix.'},
'Custom endpoint':{endpoint:'',model:'',hint:'Paste the API base URL, or the full chat/completions URL. Use only a key issued by this service.'}
};
