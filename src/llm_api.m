function response = llm_api(systemPrompt, userPrompt, provider)
%LLM_API Universal LLM API wrapper supporting multiple providers.
%
%   RESPONSE = LLM_API(SYSTEMPROMPT, USERPROMPT) uses the default provider (Claude).
%
%   RESPONSE = LLM_API(SYSTEMPROMPT, USERPROMPT, PROVIDER) uses the specified provider.
%
%   Supported providers (as of February 2026):
%
%   Anthropic:
%     'claude'          - Claude Opus 4.6 (best quality, Feb 2026)
%     'claude-sonnet'   - Claude Sonnet 4 (fast, affordable)
%
%   OpenAI:
%     'gpt5-codex'      - GPT-5.3-Codex (best for code, Feb 2026)
%     'gpt5-codex-spark' - GPT-5.3-Codex-Spark (ultra-fast coding)
%     'gpt5'            - GPT-5.2 (general purpose)
%     'gpt5-instant'    - GPT-5.2 Instant (fast, cheaper)
%
%   Google (Free Tier):
%     'gemini-flash'    - Gemini 2.5 Flash (fast, free tier default)
%     'gemini-pro'      - Gemini 2.5 Pro (high quality, free tier)
%
%   DeepSeek:
%     'deepseek'        - DeepSeek V4 (cheapest, 1M context)
%     'deepseek-coder'  - DeepSeek Coder V3 (code-specialized)
%
%   Environment variables required:
%     ANTHROPIC_API_KEY  - for Claude models
%     OPENAI_API_KEY     - for GPT models
%     GOOGLE_API_KEY     - for Gemini models
%     DEEPSEEK_API_KEY   - for DeepSeek models
%
%   See also SIMUGEN, SIMUGEN_CHAT

    if nargin < 3
        provider = 'gemini-flash';
    end
    
    switch lower(provider)
        % --- Anthropic ---
        case 'claude'
            response = call_anthropic(systemPrompt, userPrompt, 'claude-opus-4-6-20260205');
        case 'claude-sonnet'
            response = call_anthropic(systemPrompt, userPrompt, 'claude-sonnet-4-20250514');
            
        % --- OpenAI ---
        case {'gpt5-codex', 'codex'}
            response = call_openai(systemPrompt, userPrompt, 'gpt-5.3-codex');
        case {'gpt5-codex-spark', 'codex-spark', 'spark'}
            response = call_openai(systemPrompt, userPrompt, 'gpt-5.3-codex-spark');
        case {'gpt5', 'gpt'}
            response = call_openai(systemPrompt, userPrompt, 'gpt-5.2');
        case {'gpt5-instant', 'gpt-instant'}
            response = call_openai(systemPrompt, userPrompt, 'gpt-5.2-instant');
            
        % --- Google (Free Tier) ---
        case {'gemini-flash', 'gemini', 'flash'}
            response = call_gemini(systemPrompt, userPrompt, 'gemini-2.5-flash');
        case {'gemini-pro'}
            response = call_gemini(systemPrompt, userPrompt, 'gemini-2.5-pro');
            
        % --- DeepSeek ---
        case 'deepseek'
            response = call_deepseek(systemPrompt, userPrompt, 'deepseek-v4');
        case {'deepseek-coder', 'ds-coder'}
            response = call_deepseek(systemPrompt, userPrompt, 'deepseek-coder-v3');
            
        otherwise
            error('SimuGen:UnknownProvider', [...
                'Unknown provider: %s\n\n' ...
                'Available providers:\n' ...
                '  Anthropic:  claude, claude-sonnet\n' ...
                '  OpenAI:     gpt5-codex, codex-spark, gpt5, gpt5-instant\n' ...
                '  Google:     gemini-flash (default), gemini-pro\n' ...
                '  DeepSeek:   deepseek, deepseek-coder\n'], provider);
    end
end

%% ==================== ANTHROPIC (Claude) ====================
function response = call_anthropic(systemPrompt, userPrompt, model)
    apiKey = get_key('ANTHROPIC_API_KEY', 'Anthropic');
    
    body = struct();
    body.model = model;
    body.max_tokens = 16384;
    body.system = systemPrompt;
    body.messages = {struct('role', 'user', 'content', userPrompt)};
    
    options = weboptions(...
        'MediaType', 'application/json', ...
        'HeaderFields', {
            'x-api-key', apiKey;
            'anthropic-version', '2023-06-01';
            'content-type', 'application/json'
        }, ...
        'Timeout', 180, ...
        'RequestMethod', 'post');
    
    result = webwrite('https://api.anthropic.com/v1/messages', ...
        jsonencode(body), options);
    
    if iscell(result.content)
        response = result.content{1}.text;
    else
        response = result.content(1).text;
    end
end

%% ==================== OPENAI (GPT-5.x) ====================
function response = call_openai(systemPrompt, userPrompt, model)
    apiKey = get_key('OPENAI_API_KEY', 'OpenAI');
    
    messages = {
        struct('role', 'system', 'content', systemPrompt);
        struct('role', 'user', 'content', userPrompt)
    };
    
    body = struct();
    body.model = model;
    body.messages = messages;
    body.max_tokens = 16384;
    body.temperature = 0.2;
    
    options = weboptions(...
        'MediaType', 'application/json', ...
        'HeaderFields', {
            'Authorization', ['Bearer ' apiKey];
            'content-type', 'application/json'
        }, ...
        'Timeout', 180, ...
        'RequestMethod', 'post');
    
    result = webwrite('https://api.openai.com/v1/chat/completions', ...
        jsonencode(body), options);
    
    if iscell(result.choices)
        response = result.choices{1}.message.content;
    else
        response = result.choices(1).message.content;
    end
end

%% ==================== GOOGLE (Gemini 3) ====================
function response = call_gemini(systemPrompt, userPrompt, model)
    apiKey = get_key('GOOGLE_API_KEY', 'Google');
    
    url = sprintf('https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=%s', ...
        model, apiKey);
    
    body = struct();
    body.system_instruction = struct('parts', struct('text', systemPrompt));
    body.contents = struct('parts', struct('text', userPrompt));
    body.generationConfig = struct('temperature', 0.2, 'maxOutputTokens', 16384);
    
    options = weboptions(...
        'MediaType', 'application/json', ...
        'Timeout', 180, ...
        'RequestMethod', 'post');
    
    result = webwrite(url, jsonencode(body), options);
    
    if iscell(result.candidates)
        candidate = result.candidates{1};
    else
        candidate = result.candidates(1);
    end
    
    if iscell(candidate.content.parts)
        response = candidate.content.parts{1}.text;
    else
        response = candidate.content.parts(1).text;
    end
end

%% ==================== DEEPSEEK (V4) ====================
function response = call_deepseek(systemPrompt, userPrompt, model)
    apiKey = get_key('DEEPSEEK_API_KEY', 'DeepSeek');
    
    messages = {
        struct('role', 'system', 'content', systemPrompt);
        struct('role', 'user', 'content', userPrompt)
    };
    
    body = struct();
    body.model = model;
    body.messages = messages;
    body.max_tokens = 16384;
    body.temperature = 0.2;
    
    options = weboptions(...
        'MediaType', 'application/json', ...
        'HeaderFields', {
            'Authorization', ['Bearer ' apiKey];
            'content-type', 'application/json'
        }, ...
        'Timeout', 180, ...
        'RequestMethod', 'post');
    
    result = webwrite('https://api.deepseek.com/v1/chat/completions', ...
        jsonencode(body), options);
    
    if iscell(result.choices)
        response = result.choices{1}.message.content;
    else
        response = result.choices(1).message.content;
    end
end

%% ==================== HELPERS ====================
function key = get_key(envVar, providerName)
    key = getenv(envVar);
    if isempty(key)
        error('SimuGen:NoAPIKey', ...
            'Set your %s API key: setenv(''%s'', ''your-key'')', ...
            providerName, envVar);
    end
end
