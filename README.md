# <img align="center" height="70" src="./Docs/AppIcon.png"/> GitHub Copilot for Xcode

<img alt="Demo of GitHub Copilot for Xcode" src="./Docs/demo.gif" width="800" />

[GitHub Copilot](https://github.com/features/copilot) is an AI pair programmer
tool that helps you write code faster and smarter. Copilot for Xcode is an Xcode
extension that provides inline coding suggestions as you type.

## Beta Preview Policy

Use of the GitHub Copilot Xcode Extension is subject to [GitHub's Pre-Release Terms](https://docs.github.com/en/site-policy/github-terms/github-pre-release-license-terms). We want to remind you that:

> Beta Previews may not be supported or may change at any time. You may receive confidential information through those programs that must remain confidential while the program is private. We'd love your feedback to make our Beta Previews better.


## Requirements

- macOS 12+
- Xcode 8+
- A GitHub Copilot subscription. To learn more, visit [https://github.com/features/copilot](https://github.com/features/copilot).

## Getting Started

1. Download the `dmg` from
   [the latest release](https://github.com/github/CopilotForXcode/releases/latest/download/GitHubCopilotForXcode.dmg).
   Updates can be downloaded and installed by the app.

1. Open the `dmg` and drag the `GitHub Copilot for Xcode.app` into the `Applications` folder.
   <p align="center">
     <img alt="Screenshot of opened dmg" src="./Docs/dmg-open.png" width="512" />
   </p>

1. On the first opening the application it will warn that it was downloaded from the internet. Click `Open` to proceed.
   <p align="center">
     <img alt="Screenshot of downloaded from the internet warning" src="./Docs/downloaded-from-internet.png" width="372" />
   </p>

1. A background item will be added for the application to be able to start itself when Xcode starts.
   <p align="center">
     <img alt="Screenshot of background item" src="./Docs/background-item.png" width="370" />
   </p>

1. Two permissions are required: `Accessibility` and `Xcode Source Editor Extension`.

   The first time the application is run the `Accessibility` permission should be requested:

   <p align="center">
     <img alt="Screenshot of accessibility permission request" src="./Docs/accessibility-permission-request.png" width="529" />
   </p>

   The `Xcode Source Editor Extension` permission needs to be enabled manually. Click
   `Extension Permission` from the `Copilot for Xcode` settings to open the
   System Preferences to the `Extensions` panel. Select `Xcode Source Editor`
   and enable `GitHub Copilot`:

   <p align="center">
     <img alt="Screenshot of extension permission" src="./Docs/extension-permission.png" width="582" />
   </p>

1. After granting the extension permission, please restart Xcode so the `Github Copilot` menu is available under the Xcode `Editor` menu.
    <br>
    <p align="center">
      <img alt="Screenshot of Xcode Editor GitHub Copilot menu item" src="./Docs/xcode-menu.png" width="648" />
    </p>

    Keyboard shortcuts can be set for all menu items in the `Key Bindings`
    section of Xcode preferences.

1. To sign into GitHub Copilot, click the `Sign in` button in the settings application. This will open a browser window and copy a code to the clipboard. Paste the code into the GitHub login page and authorize the application.
    <p align="center">
      <img alt="Screenshot of sign-in popup" src="./Docs/device-code.png" width="372" />
    </p>

1. To install updates, click `Check for Updates` from the menu item or in the settings application. After installing a new version, Xcode must be restarted to use the new version correctly. New versions can also be installed from `dmg` files downloaded from the releases page. When installing a new version via `dmg`, the application must be run manually the first time to accept the downloaded from the internet warning.

1. To avoid confusion, we recommend disabling `Predictive code completion` under
   `Xcode` > `Preferences` > `Text Editing` > `Editing`.

1. Press `tab` to accept the first line of a suggestion, hold `option` to view
   the full suggestion, and press `option` + `tab` to accept the full suggestion.

   <p align="center">
     <img alt="Screenshot of welcome screen" src="./Docs/welcome.png" width="672" />
   </p>

## License

This project is licensed under the terms of the MIT open source license. Please
refer to [LICENSE.txt](./LICENSE.txt) for the full terms.

## Privacy

We follow responsible practices in accordance with our
[Privacy Statement](https://docs.github.com/en/site-policy/privacy-policies/github-privacy-statement).

To get the latest security fixes, please use the latest version of the GitHub
Copilot for Xcode.

## Support

We’d love to get your help in making GitHub Copilot better!  If you have
feedback or encounter any problems, please reach out on our [Feedback
forum](https://github.com/orgs/community/discussions/categories/copilot).

## Acknowledgements

Thank you to @intitni for creating the original project that this is based on.

Attributions can be found under About when running the app or in
[Credits.rtf](./Copilot%20for%20Xcode/Credits.rtf).
