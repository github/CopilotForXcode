import Foundation
import SwiftUI

@ViewBuilder
public func drawFileIcon(_ file: URL?) -> some View {
    let fileExtension = file?.pathExtension.lowercased() ?? ""
    
    switch fileExtension {
    case "swift":
        if let nsImage = NSImage(named: "SwiftIcon") {
            Image(nsImage: nsImage)
                .resizable()
        } else {
            Image(systemName: "doc.text")
                .resizable()
        }
    case "md":
        Text("M↓")
            .scaledFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.indigo)
    case "plist":
        Image(systemName: "table")
            .resizable()
    case "xcconfig":
        Image(systemName: "gearshape.2")
            .resizable()
    case "html":
        Image(systemName: "chevron.left.slash.chevron.right")
            .resizable()
            .foregroundColor(.blue)
    case "entitlements":
        Image(systemName: "checkmark.seal.text.page")
            .resizable()
            .foregroundColor(.yellow)
    case "sh":
        Image(systemName: "terminal")
            .resizable()
    case "txt":
        Image(systemName: "doc.plaintext")
            .resizable()
    case "c", "m", "mm":
        Text("C")
            .scaledFont(size: 12, weight: .bold, design: .monospaced)
            .foregroundColor(.blue)
    case "cpp":
        Text("C++")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.blue)
    case "h":
        Text("h")
            .scaledFont(size: 12, weight: .bold, design: .monospaced)
            .foregroundColor(.blue)
    case "xml":
        Text("XML")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.orange)
    case "yml", "yaml":
        Text("YML")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.pink)
    case "json":
        Text("{}")
            .scaledFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.red)
    case "ts":
        Text("TS")
            .scaledFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.blue)
    case "tsx":
        Text("TSX")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.blue)
    case "js":
        Text("JS")
            .scaledFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.yellow)
    case "jsx":
        Text("JSX")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.yellow)
    case "css":
        Text("CSS")
            .scaledFont(size: 8, weight: .bold, design: .monospaced)
            .foregroundColor(.purple)
    case "py":
        Text("PY")
            .scaledFont(size: 10, weight: .bold, design: .monospaced)
            .foregroundColor(.indigo)
    case "xctestplan":
        ZStack {
            Text("P")
                .scaledFont(size: 8, weight: .bold, design: .monospaced)
                .foregroundColor(.blue)
            RoundedRectangle(cornerRadius: 1.5)
                .stroke(Color.blue, lineWidth: 1.5)
                .scaledFrame(width: 10, height: 10)
                .rotationEffect(.degrees(45))
        }
    default:
        Image(systemName: "doc.text")
            .resizable()
    }
}

@ViewBuilder
public func drawFileIcon(_ file: URL?, isDirectory: Bool = false) -> some View {
    if isDirectory {
        if file?.lastPathComponent == "xcassets" {
            Image(systemName: "photo.on.rectangle.angled")
                .resizable()
                .foregroundColor(.blue)
        } else {
            Image(systemName: "folder")
                .resizable()
        }
    } else {
        drawFileIcon(file)
    }
}
