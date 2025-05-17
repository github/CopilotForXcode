# <img align="center" height="70" src="./Docs/AppIcon.png"/> GitHub Copilot for Xcode

[GitHub Copilot](https://github.com/features/copilot) is an AI pair programmer that helps you write code faster and smarter. Copilot for Xcode is an Xcode extension that provides inline coding suggestions as you type and a chat assistant to answer your coding questions.

---

## Table of Contents

- [Features](#features)
- [Requirements](#requirements)
- [Quick Start](#quick-start)
- [Getting Started](#getting-started)
- [How to Use Chat](#how-to-use-chat)
- [How to Use Code Completion](#how-to-use-code-completion)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Troubleshooting](#troubleshooting)
- [License](#license)
- [Privacy](#privacy)
- [Support](#support)
- [Acknowledgements](#acknowledgements)

---

## Features

### Chat
GitHub Copilot Chat provides suggestions for your specific coding tasks via a conversational interface.

![Animated screenshot showing Copilot Chat in Xcode](./Docs/chat_dark.gif)

### Code Completion
Receive AI-powered auto-complete suggestions from GitHub Copilot by starting to write code or by describing your intent in a natural language comment.

![Animated screenshot showing code completion suggestions](./Docs/demo.gif)

---

## Requirements

- macOS 12 or higher
- Xcode 8 or higher
- A [GitHub Copilot subscription](https://github.com/features/copilot)

---

## Quick Start

1. **Install via Homebrew:**
    ```sh
    brew install --cask github-copilot-for-xcode
    ```
    *Or* download the `.dmg` from the [latest release](https://github.com/github/CopilotForXcode/releases/latest/download/GitHubCopilotForXcode.dmg) and drag **GitHub Copilot for Xcode** into your **Applications** folder.

2. **Open the app** and accept any security warnings.

3. **Grant permissions** (Background, Accessibility, and Xcode Source Editor Extension) when prompted.

4. **Enable the extension** in System Preferences > Extensions > Xcode Source Editor.

5. **Open Xcode** and verify the **GitHub Copilot** menu under the Xcode **Editor** menu.

6. **Sign in to GitHub Copilot** via the app settings.

---

## Getting Started

### 1. Installation

- Install via [Homebrew](https://brew.sh/), or
- Download the `.dmg` from [the latest release](https://github.com/github/CopilotForXcode/releases/latest/download/GitHubCopilotForXcode.dmg) and drag it into your Applications folder.

    ![Screenshot: Opened dmg](./Docs/dmg-open.png)

- Updates can be downloaded and installed by the app.

### 2. Running the Application

- Open **GitHub Copilot for Xcode** from Applications.
- Accept the security warning.
    ![Screenshot: macOS download permission request](./Docs/macos-download-open-confirm.png)

- A background item will be added automatically.
    ![Screenshot: Background item](./Docs/background-item.png)

### 3. Permissions

- **Three permissions** are required: Background, Accessibility, and Xcode Source Editor Extension.
- The first time the app runs, you will be prompted for Accessibility permission:
    ![Screenshot: Accessibility permission request](./Docs/accessibility-permission-request.png)

- Enable the Xcode Source Editor Extension manually:
    - Click **Extension Permission** from the app settings.
    - Go to System Preferences > Extensions > Xcode Source Editor, and enable **GitHub Copilot**.
    ![Screenshot: Extension permission](./Docs/extension-permission.png)

### 4. Enabling in Xcode

- Open Xcode and make sure the **GitHub Copilot** menu is available and enabled under the Xcode **Editor** menu.
    ![Screenshot: Xcode Editor GitHub Copilot menu item](./Docs/xcode-menu.png)

- Keyboard shortcuts can be set for all menu items in Xcode preferences under **Key Bindings**.

### 5. Signing In

- Click **Sign in** in the app settings.
- A browser window will open and a code will be copied to your clipboard. Paste the code into the GitHub login page.
    ![Screenshot: Sign-in popup](./Docs/device-code.png)

### 6. Updating

- To install updates, click **Check for Updates** in the menu or app settings.
- After updating, restart Xcode for the changes to take effect.
- New versions can also be installed via `.dmg` from the releases page.

### 7. Xcode Preferences

> **Note:** To avoid conflicts, disable **Predictive code completion**:
> Xcode > Preferences > Text Editing > Editing

### 8. Using Suggestions

- Press `Tab` to accept the first line of a suggestion.
- Hold `Option` to view the full suggestion.
- Press `Option + Tab` to accept the full suggestion.
    ![Screenshot: Welcome screen](./Docs/welcome.png)

---

## How to Use Chat

- Open Copilot Chat in Xcode via:
    - **Xcode → Editor → GitHub Copilot → Open Chat**
      ![Screenshot: Xcode Editor GitHub Copilot menu item](./Docs/xcode-menu_dark.png)
    - Or via the **GitHub Copilot app menu → Open Chat**
      ![Screenshot: GitHub Copilot menu item](./Docs/copilot-menu_dark.png)

---

## How to Use Code Completion

- Press `Tab` to accept the first line of a suggestion.
- Hold `Option` to view the full suggestion.
- Press `Option + Tab` to accept the full suggestion.

---

## Keyboard Shortcuts

| Action                               | Shortcut           |
|-------------------------------------- |--------------------|
| Accept first line of suggestion       | `Tab`              |
| View full suggestion                  | `Option`           |
| Accept full suggestion                | `Option + Tab`     |
| Open Copilot Chat                     | Customize in Xcode |

Set your own shortcuts in **Xcode > Preferences > Key Bindings**.

---

## Troubleshooting

- **Copilot menu not showing in Xcode?**
    - Make sure the Source Editor Extension is enabled in System Preferences > Extensions.
    - Restart Xcode after enabling the extension.

- **Permission issues?**
    - Confirm that Accessibility and Background permissions are enabled in System Preferences.

- **Problems signing in?**
    - Ensure you’re using the latest version of the app.
    - Try re-signing in via the app settings.

For more help, visit our [Feedback forum](https://github.com/orgs/community/discussions/categories/copilot).

---

## License

This project is licensed under the MIT open source license. See [LICENSE.txt](./LICENSE.txt) for details.

---

## Privacy

We follow responsible practices in accordance with our [Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

To get the latest security fixes, please use the latest version of GitHub Copilot for Xcode.

---

## Support

We welcome your feedback to make GitHub Copilot better! If you have feedback or encounter problems, please reach out on our [Feedback forum](https://github.com/orgs/community/discussions/categories/copilot).

---

## Acknowledgements

Thank you to @intitni for creating the original project this is based on.

Attributions can be found under "About" in the app or in [Credits.rtf](./Copilot%20for%20Xcode/Credits.rtf).
