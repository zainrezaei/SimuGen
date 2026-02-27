# SimuGen: How It Works & Architecture

SimuGen is an AI-powered tool that translates natural language descriptions into fully functional Simulink models. It achieves this by acting as an intelligent bridge between large language models (LLMs) and the MATLAB/Simulink environment.

Instead of directly generating the `.slx` binary file (which is complex and proprietary), SimuGen asks the AI to write a **MATLAB script that programmatically constructs the Simulink model** using standard APIs like `new_system()`, `add_block()`, and `add_line()`. SimuGen then executes this code, handles any errors with an auto-fix loop, and validates the resulting model.

## Architecture & File Interactions

The system is modular, consisting of several core files in the `src/` directory that work together harmoniously.

```mermaid
graph TD
    User([User]) -->|Natural Language Input| Chat(simugen_chat.m)
    User -->|API Call| Main(simugen.m)
    
    Chat -->|Commands & Prompts| Main
    
    subgraph Core Engine ["src/ Core Engine"]
        Main -->|1. Load Prompt| Prompt[prompts/system_prompt.txt]
        Main -->|2. Send Request| API(llm_api.m)
        API -->|3. HTTP Request| ExternalAPI((LLM Providers:<br>Claude, OpenAI,<br>Gemini, DeepSeek))
        ExternalAPI -.->|4. Generated Code| API
        API -.->|Return Code| Main
        
        Main -->|5. Evaluate & Build| MATLAB_Eval[MATLAB eval()]
        MATLAB_Eval -.->|Error| AutoFix[Auto-Fix Loop]
        AutoFix -->|Request Fix| API
        
        MATLAB_Eval -->|Success| Validator(model_validator.m)
    end
    
    subgraph Simulink Environment
        Validator -->|Check Ports & Build| SLX[(Simulink .slx)]
    end
```

## Step-by-Step Workflow

1.  **Input Parsing:** 
    The user provides a system description either via the `simugen("description")` function or the interactive `simugen_chat()` wrapper. 
2.  **Prompt Construction:** 
    `simugen.m` combines the user's input with a sophisticated `system_prompt.txt`. This system prompt instructs the LLM on exactly how to write the MATLAB code required to build the Simulink model (e.g., using specific block paths, setting parameters, and auto-routing lines).
3.  **LLM Generation:** 
    The combined prompt is sent to `llm_api.m`. This is a universal wrapper that formats the REST API request for the chosen provider (Anthropic, OpenAI, Google, or DeepSeek) and returns the AI's response.
4.  **Code Extraction:** 
    `simugen.m` parses the LLM's text response, hunting for standard Markdown code blocks (` ```matlab ... ``` `) to extract the executable MATLAB code.
5.  **Execution & Model Building:** 
    SimuGen clears any existing model with the target name and attempts to run the generated code via MATLAB's `eval()` function.
6.  **Auto-Fix Loop (Error Handling):** 
    If MATLAB throws an error while trying to build the blocks or lines (e.g., a block path is wrong or a port doesn't exist), SimuGen captures the exact error message. It sends the broken code and the error message *back* to the LLM via `llm_api.m`, asking it to correct its mistake. The loop then retries building the model.
7.  **Validation:** 
    Once the model is successfully built, `model_validator.m` is called. It programmatically inspects the `.slx` file to ensure:
    *   There are no unconnected ports.
    *   All blocks used are valid and exist in the Simulink library.
    *   The diagram can compile and update without simulation errors.
8.  **Output:** 
    The user is notified of the validation results, and the finished Simulink model is opened on the screen.

## Core File Descriptions

| File | Purpose | Key Responsibilities |
| :--- | :--- | :--- |
| **`simugen_chat.m`** | Interactive CLI | Wraps `simugen.m` in a REPL loop. Handles chat history, user commands (`refine:`, `validate`, `open`, `save`, `use <provider>`), and maintains the current model state. |
| **`simugen.m`** | Main Orchestrator | The primary function. Handles the 6-step workflow: prompt loading, API invocation, code extraction, MATLAB evaluation, error auto-fixing, and triggering model validation. |
| **`llm_api.m`** | Universal API Client | Formats HTTP headers/bodies for external APIs. Supports Anthropic (Claude), OpenAI (GPT/Codex), Google (Gemini), and DeepSeek. Handles network timeouts and extracts text from JSON payloads. |
| **`model_validator.m`** | Quality Assurance | Uses `find_system` and `set_param` to poke at the generated model. Checks for unconnected lines, invalid block types, and compilation faults, returning a list of discrete issues. |

*(Note: While `claude_api.m` exists in the codebase, `llm_api.m` serves as the actively used universal hub for all model inferences.)*
