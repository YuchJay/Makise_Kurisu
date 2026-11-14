import AppKit
import Combine

/// Opens the official chat in the default browser. Tab lookup reads URLs only:
/// no page body, account details or conversations are read or persisted.
final class DeepSeekLauncher: ObservableObject {
    @Published private(set) var isOpening = false
    var onFeedback: ((String) -> Void)?
    var onError: ((String) -> Void)?
    private let chatURL = URL(string: "https://chat.deepseek.com/")!
    private let queue = DispatchQueue(label: "local.kurisu.deepseek")

    private enum Browser {
        case safari, chromium

        static func family(for identifier: String) -> Browser? {
            switch identifier {
            case "com.apple.Safari", "com.apple.SafariTechnologyPreview": return .safari
            case "com.google.Chrome", "com.microsoft.edgemac", "com.brave.Browser": return .chromium
            default: return nil
            }
        }
    }

    func open() {
        guard !isOpening else { return }
        isOpening = true
        guard let browserURL = NSWorkspace.shared.urlForApplication(toOpen: chatURL),
              let bundle = Bundle(url: browserURL), let identifier = bundle.bundleIdentifier else {
            fail("没有找到可以打开网页的默认浏览器。请先在系统设置中选择默认浏览器。")
            return
        }
        let browserName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? browserURL.deletingPathExtension().lastPathComponent
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .contains { !$0.isTerminated }
        guard running else {
            openNewPage(in: browserURL)
            return
        }
        guard let family = Browser.family(for: identifier) else {
            offerOrdinaryOpen(
                "当前默认浏览器 \(browserName) 暂不支持查找已有标签页。直接打开可能新建标签页。",
                in: browserURL)
            return
        }
        // Identifiers come exclusively from the allowlist above. No URLs or
        // user strings are interpolated into executable script.
        let script = lookupScript(identifier: identifier, family: family)
        queue.async { [weak self] in
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            let outcome = result?.stringValue
            let code = (error?[NSAppleScript.errorNumber] as? NSNumber)?.intValue
            let failed = error != nil || outcome == nil
            DispatchQueue.main.async {
                guard let self else { return }
                if outcome == "found", !failed {
                    self.isOpening = false
                    self.onFeedback?("已经切过去了。有现成的页面，就别再开一堆。")
                } else if outcome == "missing", !failed {
                    self.openNewPage(in: browserURL)
                } else {
                    let reason = code == -1743 || code == -1744
                        ? "尚未获得 \(browserName) 的自动化授权。可在系统“隐私与安全性 → 自动化”中允许 Kurisu；这与输入监控权限无关。"
                        : "暂时无法在 \(browserName) 中查找已有页面（浏览器可能正在等待对话框或不支持当前脚本）。"
                    self.offerOrdinaryOpen(reason + "\n直接打开可能新建标签页。", in: browserURL)
                }
            }
        }
    }

    private func openNewPage(in browserURL: URL) {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open([chatURL], withApplicationAt: browserURL,
                                configuration: configuration) { [weak self] _, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if error != nil {
                    self.fail("DeepSeek 网页没有打开。请检查默认浏览器是否可以正常启动，再试一次。")
                } else {
                    self.isOpening = false
                    // Dispatching a URL is not proof that the site loaded or
                    // that the user is signed in.
                    self.onFeedback?("入口给你打开了。得到答案以后，也记得自己判断。")
                }
            }
        }
    }

    private func offerOrdinaryOpen(_ reason: String, in browserURL: URL) {
        let alert = NSAlert()
        alert.messageText = "无法直接切换 DeepSeek 标签页"
        alert.informativeText = reason
        alert.addButton(withTitle: "直接打开网页")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openNewPage(in: browserURL)
        } else { isOpening = false }
    }

    private func fail(_ text: String) {
        isOpening = false
        onError?(text)
    }

    private func lookupScript(identifier: String, family: Browser) -> String {
        let select: String
        switch family {
        case .safari:
            select = """
            set current tab of w to t
            try
                set miniaturized of w to false
            end try
            """
        case .chromium:
            select = """
            set active tab index of w to tabIndex
            try
                set minimized of w to false
            end try
            """
        }
        return """
        with timeout of 15 seconds
            tell application id "\(identifier)"
                repeat with w in windows
                    set tabIndex to 0
                    repeat with t in tabs of w
                        set tabIndex to tabIndex + 1
                        set pageURL to URL of t
                        if pageURL is not missing value then
                            ignoring case
                                set isChat to pageURL is "https://chat.deepseek.com" or pageURL starts with "https://chat.deepseek.com/" or pageURL starts with "https://chat.deepseek.com?" or pageURL starts with "https://chat.deepseek.com#"
                            end ignoring
                            if isChat then
                                \(select)
                                set index of w to 1
                                activate
                                return "found"
                            end if
                        end if
                    end repeat
                end repeat
                return "missing"
            end tell
        end timeout
        """
    }
}
