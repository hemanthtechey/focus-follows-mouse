// Focus-follows-mouse: the window under the cursor gets keyboard focus, no click needed.
import AppKit

let systemWide = AXUIElementCreateSystemWide()
let myPid = getpid()
var lastPos = CGPoint(x: -1, y: -1)
var pending: AXUIElement?  // candidate window; focused only if still under cursor on the next tick

func attr(_ el: AXUIElement, _ name: String) -> AnyObject? {
    var v: AnyObject?
    return AXUIElementCopyAttributeValue(el, name as CFString, &v) == .success ? v : nil
}

func windowUnderCursor(_ p: CGPoint) -> AXUIElement? {
    var el: AXUIElement?
    guard AXUIElementCopyElementAtPosition(systemWide, Float(p.x), Float(p.y), &el) == .success, let el else { return nil }
    if (attr(el, kAXRoleAttribute) as? String) == kAXWindowRole { return el }
    guard let w = attr(el, kAXWindowAttribute) else { return nil }  // menu bar, Dock, desktop → no window
    return (w as! AXUIElement)
}

func tick() {
    guard NSEvent.pressedMouseButtons == 0 else { return }  // don't interfere with drags
    let p = CGEvent(source: nil)?.location ?? .zero
    if p == lastPos { pending = nil; return }
    lastPos = p

    guard let win = windowUnderCursor(p) else { pending = nil; return }
    var pid: pid_t = 0
    AXUIElementGetPid(win, &pid)
    guard pid != myPid, let app = NSRunningApplication(processIdentifier: pid), app.activationPolicy == .regular else { return }

    // Leave popups alone (Raycast, Spotlight): don't steal focus from background/accessory apps.
    // Judged by app type, not window subrole: iTerm 3.7.6 reports its normal windows as AXSystemDialog.
    if let front = NSWorkspace.shared.frontmostApplication {
        if front.activationPolicy != .regular { return }
        if front.processIdentifier == pid, let fw = attr(AXUIElementCreateApplication(pid), kAXFocusedWindowAttribute),
           CFEqual(fw as! AXUIElement, win) { pending = nil; return }  // already focused
    }

    // Debounce: act only when the cursor stays over the same window for two ticks.
    guard let prev = pending, CFEqual(prev, win) else { pending = win; lastPos = .init(x: -1, y: -1); return }
    pending = nil
    AXUIElementSetAttributeValue(win, kAXMainAttribute as CFString, kCFBooleanTrue)
    AXUIElementPerformAction(win, kAXRaiseAction as CFString)
    app.activate()
}

// Ask for Accessibility permission once; macOS shows the prompt.
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(opts) {
    print("Grant Accessibility access to this binary in System Settings → Privacy & Security → Device Control and Data Access")
}

Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
    if AXIsProcessTrusted() { tick() }
}
RunLoop.main.run()
