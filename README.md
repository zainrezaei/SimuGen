<p align="center">
  <h1 align="center">⚡ SimuGen</h1>
  <p align="center"><strong>AI-Powered Simulink Model Generation from Natural Language</strong></p>
  <p align="center">
    <em>Describe your system. Get a working Simulink model. In seconds.</em>
  </p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/MATLAB-R2023b+-orange?style=flat-square&logo=mathworks" />
  <img src="https://img.shields.io/badge/Simulink-Supported-blue?style=flat-square" />
  <img src="https://img.shields.io/badge/AI-Google%20Gemini-purple?style=flat-square" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" />
</p>

---

## 🎯 What is SimuGen?

SimuGen transforms natural language descriptions into fully functional Simulink models. Instead of spending hours dragging blocks and wiring connections, simply describe what you need:

```
>> simugen("Build a PID speed controller for a DC motor with inertia J=0.01 and damping b=0.1")
```

→ **Complete Simulink model generated, validated, and ready to simulate.**

## 🚀 Quick Start

### Prerequisites
- MATLAB R2023b or later (with Simulink)
- Google Gemini API key (Free Tier works great! [Get one here](https://aistudio.google.com/))

### Installation
```matlab
% Clone the repo
% Add to MATLAB path
addpath(genpath('SimuGen/src'));

% Set your API key (defaults to Gemini 2.5 Flash)
setenv('GOOGLE_API_KEY', 'your-api-key-here');
% Also supports: ANTHROPIC_API_KEY, OPENAI_API_KEY, DEEPSEEK_API_KEY
```

### First Model
```matlab
% Generate a Simulink model from natural language
simugen("Create a mass-spring-damper system with m=1, k=10, c=0.5")

% Or use the interactive chat mode
simugen_chat()
```

## 📁 Project Structure

```
SimuGen/
├── src/                    % Core source code
│   ├── simugen.m           % Main entry point
│   ├── simugen_chat.m      % Interactive chat mode
│   ├── llm_api.m           % Universal LLM API wrapper (Gemini default)
│   ├── code_generator.m    % Simulink code generation
│   └── model_validator.m   % Model validation
├── prompts/                % System prompts for Claude
│   └── system_prompt.txt   % Engineering-aware prompt
├── examples/               % Example usage scripts
│   ├── ex_pid_controller.m
│   ├── ex_dc_motor.m
│   └── ex_hybrid_vehicle.m
├── tests/                  % Test suite
│   └── test_basic_models.m
├── docs/                   % Documentation
│   ├── architecture.md
│   └── how_it_works.md     % Detailed workflow & mermaid diagrams
├── .gitignore
├── LICENSE
└── README.md
```

## 🏗️ Architecture

```
User Input (NL)  →  Prompt Engine  →  Gemini/LLM API  →  Extract MATLAB Code  →  Build .slx
                                                               ↓                    |
                                                       Validation & Auto-Fix ←──────┘
```

For a detailed breakdown of how the scripts interact (with Mermaid diagrams), see [how_it_works.md](docs/how_it_works.md).


## 📄 License

MIT License — see [LICENSE](LICENSE) for details.

