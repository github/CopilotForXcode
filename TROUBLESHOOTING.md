# Troubleshooting for Copilot for Xcode

If you are having trouble with Copilot for Xcode, follow these steps to resolve
common issues:

1. Check for updates and restart Xcode. Ensure that Copilot for Xcode has the
   [latest release](https://github.com/github/CopilotForXcode/releases/latest)
   by clicking `Check for Updates` in the settings or under the status menu. After
   updating, restart Xcode.

2. Ensure that the Copilot for Xcode extension is enabled. Open Xcode and go to
   the top menu bar and open the `Editor` menu. If there is no `GitHub Copilot`
   menu under `Editor` then [extension permission](#extension-permission)
   needs to be enabled. If the `GitHub Copilot` menu is shown but grayed out,
   then Xcode needs to be restarted to enable the extension.

3. Need more help? If these steps don't resolve the issue, please [open an
   issue](https://github.com/github/CopilotForXcode/issues/new/choose). Make
   sure to [include logs](#logs) and any other relevant information.

## Extension Permission

GitHub Copilot for Xcode is an Xcode Source Editor extension and requires the
extension to be enabled. In the Copilot for Xcode settings, clicking `Extension
Permission` will open the System Settings to the Extensions page where `GitHub
Copilot` can be enabled under `Xcode Source Editor`.

Or you can navigate to the permission manually depending on your OS version:

| macOS | Location |
| :--- | :--- |
| 15 | System Settings > General > Login Items > Extensions > Xcode Source Editor |
| 13 & 14 | System Settings > Privacy & Security  > Extensions > Xcode Source Editor |
| 12 | System Preferences > Extensions |

## Accessibility Permission

GitHub Copilot for Xcode requires the accessibility permission to receive
real-time updates from the active Xcode editor. [The XcodeKit
API](https://developer.apple.com/documentation/xcodekit)
enabled by the Xcode Source Editor extension permission only provides
information when manually triggered by the user. In order to generate
suggestions as you type, the accessibility permission is used to read the
Xcode editor content in real-time.

The accessibility permission is also used to accept suggestions when `tab` is
pressed.

The accessibility permission is __not__ used to read from or write to any
applications besides Xcode. There are no granular options for the permission,
but you can audit the usage in this repository: search for `CGEvent` and `AX`*.

Enable in System Settings under `Privacy & Security` > `Accessibility` > 
`GitHub Copilot for Xcode Extension` and turn on the toggle.

## Logs

Logs can be found in `~/Library/Logs/GitHubCopilot/` 
The most recent log file
is:

```
~/Library/Logs/GitHubCopilot/github-copilot-for-xcode.log
```

To enable verbose logging, open the GitHub Copilot for Xcode settings and enable
`Verbose Logging` in the `Advanced` tab. After enabling verbose logging, restart
Copilot for Xcode for the change to take effect.
