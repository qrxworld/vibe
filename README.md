# vibe.sh - LLM-Powered Iterative File Generation

`vibe.sh` is a shell script designed to streamline the process of using Large Language Models (LLMs) for code and content generation directly from your terminal. It automates file handling, versioning, and the LLM interaction pipeline, enabling a "pure vibe coding" experience where you can rapidly iterate on ideas with AI assistance.

## Why `vibe.sh`?

When working with LLMs to generate files, the typical workflow involves:
1.  Crafting a prompt.
2.  Sending it to the LLM.
3.  Saving the response.
4.  Reviewing and testing.
5.  Tweaking the prompt or the generated content.
6.  Repeating the process.

`vibe.sh` simplifies this by:
-   **Automating File Management:** Creates and overwrites a "live" version of your target file.
-   **Built-in Version Control:** Automatically saves versioned copies of both the LLM's output and the input prompt file (`.vibe`). This allows you to:
    -   Easily compare changes between versions.
    -   Roll back to previous states.
    -   Provide the LLM with a history of how the project is evolving, helping it better align with your vision over time.
-   **Seamless LLM Interaction:** Leverages helper scripts (`context` and `hey`) to prepare input and communicate with the LLM.

The goal is to make iterative development with LLMs faster, more organized, and more intuitive from the command line.

## Features

-   Takes a `.vibe` source prompt file as input.
-   Uses `context` to wrap the source file with metadata for the LLM.
-   Pipes the contextualized prompt to `hey` for LLM processing.
-   Saves the LLM's response to a "live" file (e.g., `filename.ext`).
-   Saves a versioned copy of the LLM's response (e.g., `filename.1.ext`, `filename.2.ext`, ...).
-   Saves a versioned copy of the input `.vibe` file (e.g., `filename.ext.1.vibe`, `filename.ext.2.vibe`, ...), preserving the prompt that generated each version.
-   Supports custom additional prompts, system prompts, and LLM model selection via command-line arguments.
-   Includes a default system prompt optimized for direct file output (no conversational fluff from the LLM).

## Prerequisites

1.  **Bash:** The script is written for Bash.
2.  **`context` script:** You need a `context` script in your `PATH`. This script is responsible for wrapping a source file with metadata that can help the LLM.
3.  **`hey` script:** You need a `hey` script in your `PATH`. This script is responsible for sending the prompt to your configured LLM and outputting its raw response. It should accept `--prompt`, `--system`, and `--model` arguments.

## Installation

1.  Save the `vibe.sh` script to a file (e.g., `vibe.sh`).
2.  Make it executable: `chmod +x vibe.sh`
3.  Place it in a directory included in your system's `PATH` (e.g., `~/.local/bin` or `/usr/local/bin`), or call it with its full path.

## Usage

```bash
vibe.sh <source.vibe> [--prompt 'additional prompt'] [--system 'system prompt'] [--model 'modelname']
```

**Arguments:**

-   `<source.vibe>` (Required): The path to your source prompt file. This file contains the primary instructions or content for the LLM. It *must* end with the `.vibe` extension.
    -   Example: `index.html.vibe`, `myscript.py.vibe`, `README.md.vibe`, `utility.vibe` (if the target has no extension).
-   `--prompt 'text'` (Optional): An additional prompt to append to the content of the `.vibe` file.
-   `--system 'text'` (Optional): A system prompt to guide the LLM's behavior. Overrides the default system prompt.
-   `--model 'modelname'` (Optional): The specific LLM model name to pass to the `hey` script.

## File Naming and Versioning

Given an input `source.vibe` like `project/filename.ext.vibe`:

1.  **LLM Output (Live File):** `project/filename.ext`
    -   This file is created or overwritten on each run and represents the latest generated version.
    -   If `source.vibe` was `project/script.vibe` (no inner extension), this would be `project/script`.

2.  **LLM Output (Versioned File):** `project/filename.N.ext`
    -   `N` is an integer, starting at `1` and incrementing for each subsequent run.
    -   If `filename.1.ext` exists, the next run creates `filename.2.ext`, and so on.
    -   If `source.vibe` was `project/script.vibe`, this would be `project/script.N`.

3.  **Source Prompt (Versioned File):** `project/filename.ext.N.vibe`
    -   A copy of the input `source.vibe` file used for that specific generation.
    -   `N` matches the version number of the output file.
    -   This allows you to track which prompt generated which version of the output.
    -   If `source.vibe` was `project/script.vibe`, this would be `project/script.N.vibe`.

The original `<source.vibe>` file (e.g., `project/filename.ext.vibe`) is **not modified** by `vibe.sh`; it is only copied to its versioned name. You are expected to edit this original file for subsequent iterations.

## Examples

**First run for a new HTML file:**

```bash
# Create index.html.vibe with your initial prompt, e.g.:
# "Create a basic HTML5 boilerplate for a personal portfolio page. Include a header, nav, main, and footer section."
vibe.sh index.html.vibe
```
This will generate:
-   `index.html` (live version)
-   `index.1.html` (version 1 output)
-   `index.html.1.vibe` (copy of `index.html.vibe` used for version 1)

**Second run, after editing `index.html.vibe` (e.g., to add more details or with an additional prompt):**

```bash
# You've edited index.html.vibe or want to add a quick modification
vibe.sh index.html.vibe --prompt "Add a contact form to the main section."
```
This will:
-   Overwrite `index.html` (new live version)
-   Generate `index.2.html` (version 2 output)
-   Generate `index.html.2.vibe` (copy of `index.html.vibe` used for version 2)

**Working on a script without a traditional extension in its name:**

```bash
# Create myutility.vibe with: "Write a bash script that lists all files in the current directory modified in the last 24 hours."
vibe.sh myutility.vibe
```
This will generate:
-   `myutility` (live version)
-   `myutility.1` (version 1 output)
-   `myutility.1.vibe` (copy of `myutility.vibe` used for version 1)

## Default System Prompt

The default system prompt is designed to encourage the LLM to produce raw, usable file content without conversational wrappers or markdown code fences (unless the target file is markdown). It's roughly:

```
You are an expert programmer and content writer.
Your task is to process the provided file content and generate new code or content.
The original filename is included in the context to guide your response.
Your entire output will be written directly to a new file. Adhere strictly to the following:
- DO NOT include any conversational fluff, explanations, apologies, or introductory/concluding remarks.
- DO NOT use Markdown code fences (e.g., ```python ... ```) unless the target file itself is a Markdown document that *requires* such fences.
- Output ONLY the raw, complete content of the desired file.
- For code files, ensure the syntax is correct and directly usable for the inferred language.
- For configuration files (JSON, YAML, INI, etc.), output in the correct, raw format.
- If the request implies creating a shell script, focus on the script's content.
```
You can override this using the `--system` option.

## Contributing

This is a personal utility script, but feel free to fork, adapt, and improve it for your own needs! Suggestions are welcome.
