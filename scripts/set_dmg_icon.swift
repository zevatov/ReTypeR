import AppKit

let projectPath = "/Users/stanislav/Desktop/проекты/ReTypeR"
let dmgPath = "\(projectPath)/ReTypeR.dmg"
let iconPath = "\(projectPath)/Sources/App/AppIcon.png"

func log(_ msg: String) {
    print("[SetDmgIcon] \(msg)")
}

if !FileManager.default.fileExists(atPath: dmgPath) {
    log("Error: DMG file does not exist at \(dmgPath)")
    exit(1)
}

guard let image = NSImage(contentsOfFile: iconPath) else {
    log("Error: Failed to load icon image from \(iconPath)")
    exit(1)
}

let success = NSWorkspace.shared.setIcon(image, forFile: dmgPath, options: [])
if success {
    log("Successfully set custom icon for DMG file!")
} else {
    log("Failed to set custom icon for DMG file.")
}
