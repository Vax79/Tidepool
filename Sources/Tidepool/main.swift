import AppKit

let args = CommandLine.arguments
if let i = args.firstIndex(of: "--sheet"), i + 1 < args.count {
    DevTools.writeSheet(args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--icon"), i + 1 < args.count {
    DevTools.writeIcon(args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--variants"), i + 1 < args.count {
    DevTools.writeVariants(args[i + 1])
    exit(0)
}
if let i = args.firstIndex(of: "--picker-shot"), i + 1 < args.count {
    DevTools.snapshotPicker(args[i + 1])
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
AppDelegate.shared = delegate
app.delegate = delegate
app.setActivationPolicy(.accessory)   // menu bar only: no Dock icon, never steals focus
app.run()
