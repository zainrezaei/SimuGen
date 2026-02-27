function simugen(description, varargin)
%SIMUGEN Generate a Simulink model from natural language description.
%
%   SIMUGEN(DESCRIPTION) generates a Simulink model based on the natural
%   language description provided.
%
%   SIMUGEN(DESCRIPTION, 'ModelName', NAME) specifies the output model name.
%
%   SIMUGEN(DESCRIPTION, 'Open', true) opens the model after generation.
%
%   Example:
%       simugen("Build a PID controller for a DC motor with J=0.01, b=0.1")
%       simugen("Create a mass-spring-damper system", 'ModelName', 'msd_model')
%
%   See also SIMUGEN_CHAT, CLAUDE_API, MODEL_VALIDATOR

    % Parse inputs
    p = inputParser;
    addRequired(p, 'description', @ischar);
    addParameter(p, 'ModelName', 'generated_model', @ischar);
    addParameter(p, 'Open', true, @islogical);
    addParameter(p, 'Validate', true, @islogical);
    addParameter(p, 'Verbose', true, @islogical);
    addParameter(p, 'Provider', 'gemini-flash', @ischar);
    parse(p, description, varargin{:});
    
    opts = p.Results;
    
    if opts.Verbose
        fprintf('\n');
        fprintf('  ⚡ SimuGen - AI Simulink Generator\n');
        fprintf('  ===================================\n\n');
        fprintf('  📝 Input: "%s"\n\n', description);
    end
    
    %% Step 1: Load system prompt
    promptFile = fullfile(fileparts(mfilename('fullpath')), '..', 'prompts', 'system_prompt.txt');
    if isfile(promptFile)
        systemPrompt = fileread(promptFile);
    else
        systemPrompt = get_default_system_prompt();
    end
    
    %% Step 2: Call Claude API
    if opts.Verbose
        fprintf('  🤖 Generating Simulink code via %s...\n', upper(opts.Provider));
    end
    
    userPrompt = sprintf([...
        'Generate a MATLAB script that programmatically creates a Simulink model.\n' ...
        'Model name: %s\n\n' ...
        'System description: %s\n\n' ...
        'Requirements:\n' ...
        '- Use new_system() to create a blank model\n' ...
        '- Use add_block() with full library paths\n' ...
        '- Use add_line() with autorouting\n' ...
        '- Set all block parameters explicitly\n' ...
        '- Use save_system() at the end\n' ...
        '- Output ONLY the MATLAB code, no explanations\n' ...
        '- Wrap the code in ```matlab ... ``` markers\n'], ...
        opts.ModelName, description);
    
    response = llm_api(systemPrompt, userPrompt, opts.Provider);
    
    %% Step 3: Extract MATLAB code from response
    code = extract_matlab_code(response);
    
    if isempty(code)
        error('SimuGen:NoCode', 'Failed to extract MATLAB code from API response.');
    end
    
    if opts.Verbose
        fprintf('  ✅ Code generated (%d lines)\n', numel(strsplit(code, newline)));
    end
    
    %% Step 4: Execute the generated code
    if opts.Verbose
        fprintf('  🔨 Building Simulink model...\n');
    end
    
    % Close existing model if open
    try close_system(opts.ModelName, 0); catch; end
    if isfile([opts.ModelName '.slx']), delete([opts.ModelName '.slx']); end
    
    try
        eval(code);
        if opts.Verbose
            fprintf('  ✅ Model created: %s.slx\n', opts.ModelName);
        end
    catch ME
        fprintf('  ❌ Build error: %s\n', ME.message);
        fprintf('  🔄 Attempting auto-fix...\n');
        
        % Try to fix common errors via another API call
        code = attempt_fix(systemPrompt, code, ME.message);
        % Clean up the partially-created model before retry
        try close_system(opts.ModelName, 0); catch; end
        if isfile([opts.ModelName '.slx']), delete([opts.ModelName '.slx']); end
        try
            eval(code);
            fprintf('  ✅ Model created after fix: %s.slx\n', opts.ModelName);
        catch ME2
            error('SimuGen:BuildFailed', 'Failed to build model: %s', ME2.message);
        end
    end
    
    %% Step 5: Validate
    if opts.Validate
        if opts.Verbose
            fprintf('  🔍 Validating model...\n');
        end
        [isValid, issues] = model_validator(opts.ModelName);
        if isValid
            fprintf('  ✅ Model validation passed!\n');
        else
            fprintf('  ⚠️  Validation issues:\n');
            for i = 1:numel(issues)
                fprintf('      - %s\n', issues{i});
            end
        end
    end
    
    %% Step 6: Open model
    if opts.Open
        open_system(opts.ModelName);
    end
    
    if opts.Verbose
        fprintf('\n  🎉 Done! Model ready at %s.slx\n\n', opts.ModelName);
    end
end

%% Helper: Extract MATLAB code from API response
function code = extract_matlab_code(response)
    % Strategy 1: Look for ```matlab ... ``` block
    pattern = '```matlab\s*\n(.*?)```';
    tokens = regexp(response, pattern, 'tokens', 'dotall');
    
    if ~isempty(tokens)
        code = strtrim(tokens{1}{1});
        return;
    end
    
    % Strategy 2: Try plain ``` block
    pattern2 = '```\s*\n(.*?)```';
    tokens2 = regexp(response, pattern2, 'tokens', 'dotall');
    if ~isempty(tokens2)
        code = strtrim(tokens2{1}{1});
        return;
    end
    
    % Strategy 3: Try ``` on same line (no newline after opening ```)
    pattern3 = '```[^\n]*(.*?)```';
    tokens3 = regexp(response, pattern3, 'tokens', 'dotall');
    if ~isempty(tokens3)
        code = strtrim(tokens3{1}{1});
        return;
    end
    
    % Strategy 4: Look for raw MATLAB code containing Simulink keywords
    % (when LLM returns code without any markdown fencing)
    if contains(response, 'new_system') || contains(response, 'add_block')
        % Try to extract from first new_system/close/open to last save_system
        startIdx = regexp(response, '(new_system|%\s*Create)', 'start', 'once');
        endIdx = regexp(response, 'save_system[^\n]*', 'end', 'once');
        
        if ~isempty(startIdx)
            if ~isempty(endIdx)
                code = strtrim(response(startIdx:endIdx));
            else
                code = strtrim(response(startIdx:end));
            end
            return;
        end
    end
    
    code = '';
end

%% Helper: Attempt to fix code errors
function fixed_code = attempt_fix(systemPrompt, original_code, error_msg)
    fixPrompt = sprintf([...
        'The following MATLAB/Simulink code produced an error:\n\n' ...
        'Error: %s\n\n' ...
        'Original code:\n```matlab\n%s\n```\n\n' ...
        'Fix the error and return the corrected complete code.\n' ...
        'Output ONLY the fixed MATLAB code in ```matlab ... ``` markers.\n'], ...
        error_msg, original_code);
    
    response = llm_api(systemPrompt, fixPrompt);
    fixed_code = extract_matlab_code(response);
    
    if isempty(fixed_code)
        fixed_code = original_code;
    end
end

%% Helper: Default system prompt
function prompt = get_default_system_prompt()
    prompt = fileread(fullfile(fileparts(mfilename('fullpath')), '..', 'prompts', 'system_prompt.txt'));
end
