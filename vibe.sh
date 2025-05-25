#!/bin/bash

# vibe.sh: Script to send a source file to an LLM, save the response,
# and manage versioning for both output and source files.

# Check for piped content
piped_content=""
if [[ ! -t 0 ]]; then
    piped_content=$(cat)
fi

# --- Configuration ---
DEFAULT_SYSTEM_PROMPT="You are an expert programmer and content writer.
Your task is to process the provided file content and generate new code or content.
The original filename is included in the context to guide your response.
Your entire output will be written directly to a new file. Adhere strictly to the following:
- DO NOT include any conversational fluff, explanations, apologies, or introductory/concluding remarks.
- DO NOT use Markdown code fences (e.g., \`\`\`python ... \`\`\`) unless the target file itself is a Markdown document that *requires* such fences.
- Output ONLY the raw, complete content of the desired file.
- For code files, ensure the syntax is correct and directly usable for the inferred language.
- For configuration files (JSON, YAML, INI, etc.), output in the correct, raw format.
- If the request implies creating a shell script, focus on the script's content."

# --- Helper Functions ---
usage() {
    echo "Usage: $0 <source.vibe> [--prompt 'additional prompt'] [--system 'system prompt'] [--model 'modelname']"
    echo ""
    echo "  <source.vibe>         (Required) A source prompt file (e.g., filename.ext.vibe)"
    echo "  --prompt 'text'      (Optional) An additional prompt to use with 'hey'"
    echo "  --system 'text'      (Optional) A system prompt to use (overrides default)"
    echo "  --model 'modelname'  (Optional) A model name to pass to the 'hey' script"
    echo ""
    echo "Behavior:"
    echo "  - Takes <source.vibe>, pipes its content via 'context' to 'hey'."
    echo "  - Saves LLM response to filename.ext (live version) and filename.N.ext (versioned)."
    echo "  - Creates a versioned copy of the input: filename.ext.N.vibe."
    echo ""
    echo "Example:"
    echo "  $0 index.html.vibe"
    echo "  # Generates/overwrites: index.html"
    echo "  # Generates: index.1.html and index.html.1.vibe (if first run)"
    echo ""
    echo "  $0 index.html.vibe --prompt 'Make it blue'"
    echo "  # If index.1.html exists, generates/overwrites: index.html"
    echo "  # Generates: index.2.html and index.html.2.vibe"
}

# --- Argument Parsing ---
source_file=""
additional_prompt_arg=""
system_prompt_arg=""
model_arg=""

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --prompt)
            if [[ -z "$2" ]]; then echo "Error: --prompt requires an argument." >&2; usage; exit 1; fi
            additional_prompt_arg="$2"
            shift 2
            ;;
        --system)
            if [[ -z "$2" ]]; then echo "Error: --system requires an argument." >&2; usage; exit 1; fi
            system_prompt_arg="$2"
            shift 2
            ;;
        --model)
            if [[ -z "$2" ]]; then echo "Error: --model requires an argument." >&2; usage; exit 1; fi
            model_arg="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            if [[ -n "$source_file" ]]; then
                echo "Error: Unknown argument or too many positional arguments: $1" >&2
                usage
                exit 1
            fi
            if [[ "$1" == -* ]]; then
                echo "Error: Unknown option: $1" >&2
                usage
                exit 1
            fi
            source_file="$1"
            shift
            ;;
    esac
done

if [[ -z "$source_file" ]]; then
    echo "Error: Source file is required." >&2
    usage
    exit 1
fi

if [[ ! -f "$source_file" ]]; then
    echo "Error: Source file '$source_file' not found." >&2
    exit 1
fi

if [[ "$source_file" != *.vibe ]]; then
    echo "Error: Source file must end with .vibe. Got: '$source_file'" >&2
    exit 1
fi

# --- Filename Derivations ---
# Example: source_file = "path/to/index.html.vibe"
source_file_basename=$(basename "$source_file") # "index.html.vibe"
# This is the base for output files and for versioning the source, e.g., "index.html" from "index.html.vibe"
# or "script" from "script.vibe"
base_for_outputs="${source_file_basename%.vibe}" # "index.html" or "script"

# Extract the filename stem and extension for the *target* file
# e.g., from "index.html": stem="index", ext="html"
# e.g., from "script": stem="script", ext=""
target_file_stem=""
target_file_ext=""
if [[ "$base_for_outputs" == *.* ]]; then
    target_file_stem="${base_for_outputs%.*}"
    target_file_ext=".${base_for_outputs##*.}" # Keep the dot for easier concatenation
else
    target_file_stem="$base_for_outputs"
    target_file_ext="" # No extension
fi

# --- Determine Next Version ---
current_version=0
# Look for existing versioned output files, e.g., index.1.html, script.1
# The glob pattern should match stem.N.ext or stem.N
# We use `ls -v` for natural sort if available, then process.
# A more robust way is to iterate and parse.
# Using a simple loop to find max version to avoid `ls -v` dependency if possible.
# Pattern for versioned files: target_file_stem.NUMBER.target_file_ext (or target_file_stem.NUMBER if no ext)
for existing_file in "${target_file_stem}."[0-9]*"${target_file_ext}"; do
    if [[ -f "$existing_file" ]]; then
        # Extract version number from "stem.VERSION.ext" or "stem.VERSION"
        temp_name="${existing_file#${target_file_stem}.}" # Remove "stem." -> "VERSION.ext" or "VERSION"
        version_num_str="${temp_name%${target_file_ext}}" # Remove ".ext" -> "VERSION"

        if [[ "$version_num_str" =~ ^[0-9]+$ ]] && (( version_num_str > current_version )); then
            current_version=$version_num_str
        fi
    fi
done
next_version=$((current_version + 1))

# --- Define Output Filenames ---
live_output_file="${target_file_stem}${target_file_ext}"              # e.g., index.html or script
versioned_output_file="${target_file_stem}.${next_version}${target_file_ext}" # e.g., index.1.html or script.1
versioned_source_file="${base_for_outputs}.${next_version}.vibe"      # e.g., index.html.1.vibe or script.1.vibe

# --- Prepare 'hey' command arguments ---
hey_args=()
if [[ -n "$additional_prompt_arg" ]]; then
    hey_args+=(--prompt "$additional_prompt_arg")
fi

# Use provided system prompt or default
final_system_prompt="${system_prompt_arg:-$DEFAULT_SYSTEM_PROMPT}"
hey_args+=(--system "$final_system_prompt")

if [[ -n "$model_arg" ]]; then
    hey_args+=(--model "$model_arg")
fi

# --- Execute LLM Command ---
echo "Processing '$source_file'..."
echo "Outputting to '$versioned_output_file' (version $next_version)"

# Check for context and hey dependencies
if ! command -v context &> /dev/null; then
    echo "Error: 'context' command not found. Please ensure it's in your PATH." >&2
    exit 1
fi
if ! command -v hey &> /dev/null; then
    echo "Error: 'hey' command not found. Please ensure it's in your PATH." >&2
    exit 1
fi

# The core command
if [[ -n "$piped_content" ]]; then
    if { echo "$piped_content"; context "$source_file"; } | hey "${hey_args[@]}" > "$versioned_output_file"; then
        echo "LLM response saved to '$versioned_output_file'."
    else
        echo "Error: Command failed." >&2
        echo "Partial output might be in '$versioned_output_file'." >&2
        exit 1
    fi
else
    if context "$source_file" | hey "${hey_args[@]}" > "$versioned_output_file"; then
        echo "LLM response saved to '$versioned_output_file'."
    else
        echo "Error: Command 'context \"$source_file\" | hey ${hey_args[*]}' failed." >&2
        echo "Partial output might be in '$versioned_output_file'." >&2
        exit 1
    fi
fi

# --- Create/Overwrite Live File ---
if cp "$versioned_output_file" "$live_output_file"; then
    echo "Live file updated: '$live_output_file'"
else
    echo "Error: Failed to copy '$versioned_output_file' to '$live_output_file'." >&2
    exit 1 # Critical if this fails
fi

# --- Version the Source Prompt File ---
if cp "$source_file" "$versioned_source_file"; then
    echo "Source prompt versioned: '$source_file' -> '$versioned_source_file'"
else
    echo "Error: Failed to copy '$source_file' to '$versioned_source_file'." >&2
    # This is less critical than output failure, but still an error.
    exit 1
fi

echo "Done."
