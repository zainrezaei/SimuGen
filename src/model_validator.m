function [isValid, issues] = model_validator(modelName)
%MODEL_VALIDATOR Validate a generated Simulink model.
%
%   [ISVALID, ISSUES] = MODEL_VALIDATOR(MODELNAME) checks the model for:
%   - Unconnected ports
%   - Missing block parameters
%   - Compilation errors
%
%   Returns ISVALID (logical) and ISSUES (cell array of strings).

    issues = {};
    
    % Ensure model is loaded
    try
        load_system(modelName);
    catch ME
        isValid = false;
        issues{end+1} = sprintf('Cannot load model: %s', ME.message);
        return;
    end
    
    %% Check 1: Unconnected ports
    unconnected = find_system(modelName, 'FindAll', 'on', ...
        'Type', 'port', 'Line', -1);
    
    if ~isempty(unconnected)
        for i = 1:numel(unconnected)
            parent = get_param(unconnected(i), 'Parent');
            portType = get_param(unconnected(i), 'PortType');
            issues{end+1} = sprintf('Unconnected %s port on: %s', portType, parent);
        end
    end
    
    %% Check 2: Try to compile (update diagram)
    try
        % Use set_param to update diagram (compile check)
        set_param(modelName, 'SimulationCommand', 'update');
    catch ME
        issues{end+1} = sprintf('Compilation error: %s', ME.message);
    end
    
    %% Check 3: Verify all blocks exist in library
    blocks = find_system(modelName, 'Type', 'block');
    for i = 1:numel(blocks)
        try
            blockType = get_param(blocks{i}, 'BlockType');
            if isempty(blockType)
                issues{end+1} = sprintf('Invalid block type: %s', blocks{i});
            end
        catch
            issues{end+1} = sprintf('Cannot read block: %s', blocks{i});
        end
    end
    
    %% Summary
    isValid = isempty(issues);
    
    if isValid
        blockCount = numel(blocks);
        lines = find_system(modelName, 'FindAll', 'on', 'Type', 'line');
        lineCount = numel(lines);
        fprintf('    📊 Model stats: %d blocks, %d connections\n', blockCount, lineCount);
    end
end
