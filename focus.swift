// Focus-follows-mouse: the window under the cursor gets keyboard focus, no click needed.
// Menu bar app: on/off toggle, start at login, hold Control to pause.
import AppKit
import ServiceManagement

let logURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/FocusFollowsMouse.log")
func log(_ msg: String) {  // tiny append-only log; NSLog isn't readable without admin
    let line = "\(Date()) \(msg)\n"
    if let h = try? FileHandle(forWritingTo: logURL) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
    else { try? line.write(to: logURL, atomically: true, encoding: .utf8) }
}

let systemWide = AXUIElementCreateSystemWide()
let myPid = getpid()
var lastPos = CGPoint(x: -1, y: -1)
var lastUnder: AXUIElement?  // window under the cursor at the previous tick
var pending: AXUIElement?  // candidate window; focused once it has stayed under the cursor for pendingNeed ticks
var pendingTicks = 0, pendingNeed = 1

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func windowUnderCursor(_ p: CGPoint) -> AXUIElement? {
    var el: AXUIElement?
    guard AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &el) == .success, let el else { return nil }
    if (attr(el, kAXRoleAttribute) as? String) == kAXWindowRole { return el }
    guard let w = attr(el, kAXWindowAttribute) else { return nil }  // menu bar, Dock → no window
    let win = w as! AXUIElement
    // Desktop is Finder's AXScrollArea, not a window; focusing it triggers "click wallpaper to show desktop" (Stage Manager hides apps).
    // Only this exact case is skipped: iTerm 3.7.6 windows report odd AX roles too.
    var pid: pid_t = 0
    AXUIElementGetPid(win, &pid)
    let isDesktop = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.finder"
        && (attr(win, kAXRoleAttribute) as? String) != kAXWindowRole
    return isDesktop ? nil : win
}

func tick() {
    guard NSEvent.pressedMouseButtons == 0 else { return }  // don't interfere with drags
    guard !NSEvent.modifierFlags.contains(.control) else { return }  // hold Control to pause
    let p = CGEvent(source: nil)?.location ?? .zero
    let moved = p != lastPos
    lastPos = p
    let under = windowUnderCursor(p)
    let changed = under.map { u in lastUnder.map { !CFEqual(u, $0) } ?? true } ?? (lastUnder != nil)
    lastUnder = under
    // React to cursor movement, or to the window under a still cursor changing (e.g. iTerm's hotkey window sliding away).
    // A front-app change alone (Cmd+Tab) is not reacted to, so focus isn't stolen back.
    if !moved && !changed && pending == nil { return }

    guard let win = under else { pending = nil; return }
    var pid: pid_t = 0
    AXUIElementGetPid(win, &pid)
    guard pid != myPid, NSRunningApplication(processIdentifier: pid)?.activationPolicy == .regular else { pending = nil; return }

    // Leave popups alone (Raycast, Spotlight): don't steal focus from background/accessory apps.
    // Judged by app type, not window subrole: iTerm 3.7.6 reports its normal windows as AXSystemDialog.
    if let front = NSWorkspace.shared.frontmostApplication {
        if front.activationPolicy != .regular { pending = nil; return }
        if front.processIdentifier == pid, let fw = attr(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute),
           CFEqual(fw as! AXUIElement, win) { pending = nil; return }  // already focused
    }

    // Debounce: same window for 1 more tick after a move; 3 after a change under a still cursor (skips slide animations).
    if pending == nil || !CFEqual(pending!, win) { pending = win; pendingTicks = 0; pendingNeed = moved ? 1 : 3; return }
    pendingTicks += 1
    guard pendingTicks >= pendingNeed else { return }
    pending = nil
    log("FFM focus \(NSRunningApplication(processIdentifier: pid)?.localizedName ?? "?")")
    AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    // Not app.activate(): since macOS 14 that is a deferred request and can land late, re-focusing a window the cursor already left.
    AXUIElementSetAttributeValue(AXUIElementCreateApplication(pid), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    let enabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleEnabled), keyEquivalent: "")
    let loginItem = NSMenuItem(title: "Start at Login", action: #selector(toggleLogin), keyEquivalent: "")
    let permItem = NSMenuItem(title: "Grant Permission…", action: #selector(openSettings), keyEquivalent: "")
    var enabled = UserDefaults.standard.object(forKey: "enabled") as? Bool ?? true
    var trusted = false

    func applicationDidFinishLaunching(_ n: Notification) {
        let menu = NSMenu()
        for i in [enabledItem, loginItem, permItem] { i.target = self; menu.addItem(i) }
        menu.addItem(NSMenuItem(title: "Hold Control to pause", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        if !UserDefaults.standard.bool(forKey: "loginSetOnce") {  // start at login by default; user can untick later
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: "loginSetOnce")
        }

        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        trusted = AXIsProcessTrustedWithOptions(opts)
        log("FFM start trusted=\(trusted)")
        refresh()
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [self] _ in
            let t = AXIsProcessTrusted()
            if t != trusted { trusted = t; refresh(); log("FFM trusted=\(t)") }
            if t && enabled { tick() }
        }
    }

    // Menu bar glyph matching the app icon: window frame + pointer. Template image, so it follows light/dark menu bars.
    static func glyph(alpha: CGFloat) -> NSImage {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { _ in
            NSColor.black.withAlphaComponent(alpha).set()
            let win = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 2.5, width: 11.5, height: 9), xRadius: 2, yRadius: 2)
            win.lineWidth = 1.4; win.stroke()
            NSBezierPath.fill(NSRect(x: 1.5, y: 4.6, width: 11.5, height: 1.1))
            let a = NSBezierPath()
            for (i, p) in [(0, 0), (0, 0.74), (0.18, 0.58), (0.31, 0.88), (0.44, 0.82), (0.31, 0.53), (0.54, 0.53)].enumerated() {
                let pt = NSPoint(x: 9 + p.0 * 9, y: 8 + p.1 * 9.5)
                i == 0 ? a.move(to: pt) : a.line(to: pt)
            }
            a.close(); a.fill()
            return true
        }
        img.isTemplate = true
        return img
    }

    func refresh() {
        item.button?.image = !trusted ? NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Focus Follows Mouse: permission needed")
            : Self.glyph(alpha: enabled ? 1 : 0.35)
        enabledItem.state = enabled ? .on : .off
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        permItem.isHidden = trusted
    }

    @objc func toggleEnabled() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "enabled")
        refresh()
    }

    @objc func toggleLogin() {
        let s = SMAppService.mainApp
        do { try s.status == .enabled ? s.unregister() : s.register() } catch { NSSound.beep() }
        refresh()
    }

    @objc func openSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
}

let app = NSApplication.shared
// Menu bar apps get App Nap, which throttles the 100 ms timer to seconds; keep it awake.
let activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiated, .latencyCritical], reason: "Tracking the cursor")
let delegate = AppDelegate()
app.delegate = delegate
app.run()
