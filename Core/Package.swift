000000000.0000000///01intetturupipiacaore a /ativo[ativo]ede des desabilitadado[desativatado]// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)

// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)



// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)



// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)// swift-<h1 align="center">Francium 1.20.4</h1>

**Trillium INC: https://discord.gg/vzXzFpv2gk**

**Francium CF - https://discord.gg/nZ6umnub59**

**Francium CF Backup - https://discord.gg/8rR4qHjPHe**

# Why?
Ablue allowed me to leak so and after like 2 months i decided to drop JAR with a implemented locker so if i decide (or the devs) to make the jar unusable then yk.

# How To Use
1. Download the Fabric installer from here, open it and choose Minecraft 1.20.4 & Fabric Loader 0.15.6
2. Download org_apache-5.2.1.jar (Francium) from this repository page along with [Fabric API](https://modrinth.com/mod/fabric-api/version/0.96.1+1.20.4) and put them into your .minecraft/mods folder
3. Start the game (with Fabric)

# Credits
yaimcool (Ablue) - Developer of the Client.

3000IQPlay - Obfuscating with JNIC to get rid of skids.

??? - Jar provider.

# GUI
![image](https://media.discordapp.net/attachments/1173320950503190688/1206973074931585124/dY77uaA.png?ex=65ddf445&is=65cb7f45&hm=0757f56a6f614773136bbedb883c5f84c5c6f972b6cc01796dc7c90c2e83bdb1&=&format=webp&quality=lossless&width=1662&height=934)
tools-ve    "63000000000000000000000000000$R$......60000000000000 ID:66992635660 ID:66992055757 630000000000000000R$$R$6300000000000000 addbfo4ce0lacamaebpra tranasfereiencia pix banco inter e de internacionacional .editor.unicodeHighlight.invisibleCharacters": false,
00020101021126360014Note that publicsuffixes.gz is compiled from The Public Suffix List:
https://publicsuffix.org/list/public_suffix_list.dat

It is subject to the terms of the Mozilla Public License, v. 2.0:
https://mozilla.org/MPL/2.0/
br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF900020101021126360014br.gov.bcb.pix0114+55669926356605204000053039865412841111111.115802BR5917VINICIUS M JARDIM6009ARAGARCAS62070503***63046BF9ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
<h1 align="center">Francium 1.20.4</h1>
ba�.�R�? >k�z-��V��J�M�mRo��8�,z��wH���`e�,�ރL~^�+d������[[-Y���m�߽�����/att/taddp plqca mar banco inter add /id 66992635660 id: 66992055757 62333333333333333333333 add placa superimentreirtor ativo a qtivo ativo a pix tranferenciwisasres abertas chaves:66992635660 6692055757 valor:R$ 60000⁰00000000000000⁰0000000006000000000000000000.00a���e���C��Y�o٠�3�ߺ��%�o��������} 翊�K�;6��=�/�mm�����li~���iO}
PK  ӐIX               META-INF/MANIFEST.MF�Xْ��}?����d�#�2	2��o��2�_��Nw��7

rsion: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// MARK: - Package

let package = Package(
    name: "Core",
    platforms: [.macOS(.v12)],
    products: [
        .library(
            name: "Service",
            targets: [
                "Service",
                "SuggestionInjector",
                "FileChangeChecker",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
        .library(
            name: "Client",
            targets: [
                "Client",
            ]
        ),
        .library(
            name: "HostApp",
            targets: [
                "HostApp",
                "Client",
                "LaunchAgentManager",
                "UpdateChecker",
            ]
        ),
    ],
    dependencies: [
        .package(path: "../Tool"),
        .package(url: "https://github.com/apple/swift-async-algorithms", from: "1.0.0"),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", from: "2.4.0"),
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-parsing", from: "0.12.1"),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
        .package(
            url: "https://github.com/pointfreeco/swift-composable-architecture",
            from: "1.10.4"
        ),
        // quick hack to support custom UserDefaults
        // https://github.com/sindresorhus/KeyboardShortcuts
            .package(url: "https://github.com/devm33/KeyboardShortcuts", branch: "main"),
        .package(url: "https://github.com/devm33/CGEventOverride", branch: "devm33/fix-stale-AXIsProcessTrusted"),
        .package(url: "https://github.com/devm33/Highlightr", branch: "master"),
    ],
    targets: [
        // MARK: - Main
        
        .target(
            name: "Client",
            dependencies: [
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "GitHubCopilotService", package: "Tool"),
            ]),
        .target(
            name: "Service",
            dependencies: [
                "SuggestionWidget",
                "SuggestionService",
                "ChatService",
                "PromptToCodeService",
                "ConversationTab",
                "KeyBindingManager",
                "XcodeThemeController",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
                .product(name: "Workspace", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Status", package: "Tool"),
                .product(name: "ChatTab", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "ChatAPIService", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                .product(name: "Dependencies", package: "swift-dependencies"),
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ]),
        .testTarget(
            name: "ServiceTests",
            dependencies: [
                "Service",
                "Client",
                "SuggestionInjector",
                .product(name: "XPCShared", package: "Tool"),
                .product(name: "SuggestionProvider", package: "Tool"),
                .product(name: "SuggestionBasic", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        
        // MARK: - Host App
        
            .target(
                name: "HostApp",
                dependencies: [
                    "Client",
                    "LaunchAgentManager",
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                    .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        
        // MARK: - Suggestion Service
        
            .target(
                name: "SuggestionService",
                dependencies: [
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "SuggestionProvider", package: "Tool"),
                    .product(name: "BuiltinExtension", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),
        .target(
            name: "SuggestionInjector",
            dependencies: [.product(name: "SuggestionBasic", package: "Tool")]
        ),
        .testTarget(
            name: "SuggestionInjectorTests",
            dependencies: ["SuggestionInjector"]
        ),
        
        // MARK: - Prompt To Code
        
            .target(
                name: "PromptToCodeService",
                dependencies: [
                    .product(name: "SuggestionBasic", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]),
        
        // MARK: - Chat
        
            .target(
                name: "ChatService",
                dependencies: [
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "Parsing", package: "swift-parsing"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Preferences", package: "Tool"),
                    .product(name: "ConversationServiceProvider", package: "Tool"),
                    .product(name: "GitHubCopilotService", package: "Tool"),
                ]),

            .target(
                name: "ConversationTab",
                dependencies: [
                    "ChatService",
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "ChatAPIService", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Terminal", package: "Tool"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        
        // MARK: - UI
        
            .target(
                name: "SuggestionWidget",
                dependencies: [
                    "PromptToCodeService",
                    "ConversationTab",
                    .product(name: "GitHubCopilotService", package: "Tool"),
                    .product(name: "Toast", package: "Tool"),
                    .product(name: "UserDefaultsObserver", package: "Tool"),
                    .product(name: "SharedUIComponents", package: "Tool"),
                    .product(name: "AppMonitoring", package: "Tool"),
                    .product(name: "ChatTab", package: "Tool"),
                    .product(name: "Logger", package: "Tool"),
                    .product(name: "CustomAsyncAlgorithms", package: "Tool"),
                    .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                    .product(name: "MarkdownUI", package: "swift-markdown-ui"),
                    .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
                ]
            ),
        .testTarget(name: "SuggestionWidgetTests", dependencies: ["SuggestionWidget"]),
        
        // MARK: - Helpers
        
            .target(name: "FileChangeChecker"),
        .target(
            name: "LaunchAgentManager",
            dependencies: [
                .product(name: "Logger", package: "Tool"),
            ]
        ),
        .target(
            name: "UpdateChecker",
            dependencies: [
                "Sparkle",
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
            ]
        ),

        // MARK: Key Binding

        .target(
            name: "KeyBindingManager",
            dependencies: [
                .product(name: "Workspace", package: "Tool"),
                .product(name: "Preferences", package: "Tool"),
                .product(name: "Logger", package: "Tool"),
                .product(name: "CGEventOverride", package: "CGEventOverride"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "UserDefaultsObserver", package: "Tool"),
                .product(name: "ConversationServiceProvider", package: "Tool"),
            ]
        ),
        .testTarget(
            name: "KeyBindingManagerTests",
            dependencies: ["KeyBindingManager"]
        ),

        // MARK: Theming

        .target(
            name: "XcodeThemeController",
            dependencies: [
                .product(name: "Preferences", package: "Tool"),
                .product(name: "AppMonitoring", package: "Tool"),
                .product(name: "Highlightr", package: "Highlightr"),
            ]
        ),

    ]
)





