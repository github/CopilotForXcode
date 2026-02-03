# Use custom instructions in GitHub Copilot for Xcode

Custom instructions enable you to define common guidelines and rules that automatically influence how AI generates code and handles other development tasks. Instead of manually including context in every chat prompt, specify custom instructions in a Markdown file to ensure consistent AI responses that align with your coding practices and project requirements.

You can configure custom instructions to apply automatically to all chat requests or to specific files only. Alternatively, you can manually attach custom instructions to a specific chat prompt.

> [!NOTE]
> Custom instructions are not taken into account for code completions as you type in the editor.

## Type of instructions files

GitHub Copilot for Xcode supports two types of Markdown-based instructions files:

* A single [`.github/copilot-instructions.md`](#use-a-githubcopilotinstructionsmd-file) file
    * Automatically applies to all chat requests in the workspace
    * Stored within the workspace or global

* One or more [`.instructions.md`](#use-instructionsmd-files) files
    * Created for specific tasks or files
    * Use `applyTo` frontmatter to define what files the instructions should be applied to
    * Stored in the workspace

Whitespace between instructions is ignored, so the instructions can be written as a single paragraph, each on a new line, or separated by blank lines for legibility.

Reference specific context, such as files or URLs, in your instructions by using Markdown links.
You need to import `.github/` directory and all referenced files inside your xcode project/workspace if your instructions are pointing to extra files.

## Custom instructions examples

The following examples demonstrate how to use custom instructions. For more community-contributed examples, see the [Awesome Copilot repository](https://github.com/github/awesome-copilot/tree/main).

<details>
<summary>Example: General coding guidelines</summary>

```markdown
---
applyTo: "**"
---
# Project general coding standards

## Naming Conventions
- Use PascalCase for component names, interfaces, and type aliases
- Use camelCase for variables, functions, and methods
- Use ALL_CAPS for constants

## Error Handling
- Use try/catch blocks for async operations
- Always log errors with contextual information
```

</details>

<details>
<summary>Example: Language-specific coding guidelines</summary>

Notice how these instructions reference the general coding guidelines file. You can separate the instructions into multiple files to keep them organized and focused on specific topics.

```markdown
---
applyTo: "**/*.swift"
---
# Project coding standards for Swift

Apply the [general coding guidelines](./general-coding.instructions.md) to all code.

## Swift Guidelines
- Use Swift for all new code
- Follow functional programming principles where possible
- Use interfaces for data structures and type definitions
- Use optional chaining (?.) and nullish coalescing (??) operators
```

</details>

<details>
<summary>Example: Documentation writing guidelines</summary>

You can create instructions files for different types of tasks, including non-development activities like writing documentation.

```markdown
---
applyTo: "docs/**/*.md"
---
# Project documentation writing guidelines

## General Guidelines
- Write clear and concise documentation.
- Use consistent terminology and style.
- Include code examples where applicable.

## Grammar
* Use present tense verbs (is, open) instead of past tense (was, opened).
* Write factual statements and direct commands. Avoid hypotheticals like "could" or "would".
* Use active voice where the subject performs the action.
* Write in second person (you) to speak directly to readers.

## Markdown Guidelines
- Use headings to organize content.
- Use bullet points for lists.
- Include links to related resources.
- Use code blocks for code snippets.
```

</details>

## Use a `.github/copilot-instructions.md` file

Define your custom instructions in a single `.github/copilot-instructions.md` Markdown file in the root of your workspace or globally. Copilot applies the instructions in this file automatically to all chat requests within this workspace.

To create a `.github/copilot-instructions.md` file:

1. **Open Settings > Advanced > Chat Settings**
1. To the right of "Copilot Instructions", click **Current Workspace** or **Global** to choose whether the custom instructions apply to the current workspace or all workspaces.
1. Describe your instructions by using natural language and in Markdown format.

> [!NOTE]
> GitHub Copilot provides cross-platform support for the `.github/copilot-instructions.md` configuration file. This file is automatically detected and applied in VSCode, Visual Studio, 3rd-party IDEs, and GitHub.com.

* **Workspace instructions files**: are only available within the workspace.
* **Global**: is available across multiple workspaces and is stored in the preferences.

For more information, you can read the [How-to docs](https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions?tool=xcode). 

## Use `.instructions.md` files

Instead of using a single instructions file that applies to all chat requests, you can create multiple `.instructions.md` files that apply to specific file types or tasks. For example, you can create instructions files for different programming languages, frameworks, or project types.

By using the `applyTo` frontmatter property in the instructions file header, you can specify a glob pattern to define which files the instructions should be applied to automatically. Instructions files are used when creating or modifying files and are typically not applied for read operations.

Alternatively, you can manually attach an instructions file to a specific chat prompt by using the file picker.

### Instructions file format

Instructions files use the `.instructions.md` extension and have this structure:

* **Header** (optional): YAML frontmatter
    * `description`: Description shown on hover in Chat view
    * `applyTo`: Glob pattern for automatic application (use `**` for all files)

* **Body**: Instructions in Markdown format

Example:

```markdown
---
applyTo: "**/*.swift"
---
# Project coding standards for Swift
- Follow the Swift official guide for Swift.
- Always prioritize readability and clarity.
- Write clear and concise comments for each function.
- Ensure functions have descriptive names and include type hints.
- Maintain proper indentation (use 4 spaces for each level of indentation).
```

### Create an instructions file

1. **Open Settings > Advanced > Chat Settings**

1. To the right of "Custom Instructions", click **Create** to create a new `*.instructions.md` file.

1. Enter a name for your instructions file.

1. Author the custom instructions by using Markdown formatting.

    Specify the `applyTo` metadata property in the header to configure when the instructions should be applied automatically. For example, you can specify `applyTo: "**/*.swift"` to apply the instructions only to Swift files.

    To reference additional workspace files, use Markdown links (`[App](../App.swift)`).

To modify or view an existing instructions file, click **Open Instructions Folder** to open the instructions file directory.

## Tips for defining custom instructions

* Keep your instructions short and self-contained. Each instruction should be a single, simple statement. If you need to provide multiple pieces of information, use multiple instructions.

* For task or language-specific instructions, use multiple `*.instructions.md` files per topic and apply them selectively by using the `applyTo` property.

* Store project-specific instructions in your workspace to share them with other team members and include them in your version control.

* Reuse and reference instructions files in your [prompt files](PromptFiles.md) to keep them clean and focused, and to avoid duplicating instructions.

## Related content

* [Community contributed instructions, prompts, and chat modes](https://github.com/github/awesome-copilot)
