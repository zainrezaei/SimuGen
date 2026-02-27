function simugen_chat()
%SIMUGEN_CHAT Interactive chat mode for SimuGen.
%
%   SIMUGEN_CHAT() starts an interactive session where you can describe
%   systems and iteratively refine the generated Simulink models.
%
%   Commands:
%     Type a description  - Generate a new model
%     'refine: <change>'  - Modify the current model
%     'validate'          - Re-validate the current model
%     'open'              - Open the current model in Simulink
%     'save <name>'       - Save with a specific name
%     'help'              - Show help
%     'quit' / 'exit'     - Exit chat
%
%   See also SIMUGEN

    fprintf('\n');
    fprintf('  ⚡ SimuGen Interactive Mode\n');
    fprintf('  ==========================\n');
    fprintf('  Describe a system to generate a Simulink model.\n');
    fprintf('  Type "help" for commands, "quit" to exit.\n\n');
    
    modelName = '';
    provider = 'gemini-flash';
    history = {};
    modelExists = false;
    modelCounter = 0;
    
    while true
        input_text = input('  SimuGen> ', 's');
        
        if isempty(input_text)
            continue;
        end
        
        % Command handling
        switch lower(strtrim(input_text))
            case {'quit', 'exit', 'q'}
                fprintf('  👋 Goodbye!\n\n');
                return;
                
            case 'help'
                print_help();
                continue;
                
            case 'validate'
                if modelExists
                    [isValid, issues] = model_validator(modelName);
                    if isValid
                        fprintf('  ✅ Model is valid!\n\n');
                    else
                        fprintf('  ⚠️  Issues found:\n');
                        for i = 1:numel(issues)
                            fprintf('      - %s\n', issues{i});
                        end
                        fprintf('\n');
                    end
                else
                    fprintf('  ❌ No model generated yet.\n\n');
                end
                continue;
                
            case 'open'
                if modelExists
                    open_system(modelName);
                    fprintf('  📂 Opened %s\n\n', modelName);
                else
                    fprintf('  ❌ No model generated yet.\n\n');
                end
                continue;
        end
        
        % Check for use command (switch provider)
        if startsWith(lower(input_text), 'use ')
            provider = strtrim(input_text(5:end));
            fprintf('  \x2699  Switched to provider: %s\n\n', upper(provider));
            continue;
        end
        
        % Check for save command
        if startsWith(lower(input_text), 'save ')
            newName = strtrim(input_text(6:end));
            if modelExists
                save_system(modelName, newName);
                fprintf('  💾 Saved as %s.slx\n\n', newName);
            else
                fprintf('  ❌ No model to save.\n\n');
            end
            continue;
        end
        
        % Check for refine command
        if startsWith(lower(input_text), 'refine:')
            refinement = strtrim(input_text(8:end));
            if modelExists
                input_text = sprintf('Modify the existing model "%s": %s', modelName, refinement);
            else
                fprintf('  ❌ No model to refine. Describe a system first.\n\n');
                continue;
            end
        end
        
        % Generate model
        try
            % Generate a unique model name from the description
            modelCounter = modelCounter + 1;
            modelName = generate_model_name(input_text, modelCounter);
            fprintf('  📦 Model name: %s\n', modelName);
            
            simugen(input_text, 'ModelName', modelName, 'Open', true, 'Provider', provider);
            modelExists = true;
            history{end+1} = input_text; %#ok<AGROW>
        catch ME
            fprintf('  ❌ Error: %s\n\n', ME.message);
        end
    end
end

function print_help()
    fprintf('\n');
    fprintf('  SimuGen Commands:\n');
    fprintf('  ─────────────────────────────────────────\n');
    fprintf('  <description>     Generate a new model\n');
    fprintf('  refine: <change>  Modify current model\n');
    fprintf('  validate          Check model validity\n');
    fprintf('  open              Open in Simulink\n');
    fprintf('  save <name>       Save with a name\n');
    fprintf('  help              Show this help\n');
    fprintf('  quit              Exit SimuGen\n');
    fprintf('  ─────────────────────────────────────────\n\n');
end

function name = generate_model_name(description, counter)
%GENERATE_MODEL_NAME Create a valid Simulink model name from description.
    % Extract meaningful words (skip short/common ones)
    words = regexp(lower(description), '[a-z]+', 'match');
    stopWords = {'a','an','the','with','and','or','for','of','to','in','on','at','by','is','it','as','be'};
    keywords = {};
    for i = 1:numel(words)
        w = words{i};
        if numel(w) > 2 && ~ismember(w, stopWords)
            keywords{end+1} = w; %#ok<AGROW>
        end
    end
    
    % Take up to 4 keywords
    if numel(keywords) > 4
        keywords = keywords(1:4);
    end
    
    if isempty(keywords)
        name = sprintf('simugen_model_%d', counter);
    else
        name = strjoin(keywords, '_');
    end
    
    % Ensure valid MATLAB identifier
    name = matlab.lang.makeValidName(name);
    
    % Truncate if too long
    if numel(name) > 40
        name = name(1:40);
    end
end
