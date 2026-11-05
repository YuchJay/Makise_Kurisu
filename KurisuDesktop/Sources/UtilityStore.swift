import AppKit
import Combine
import Carbon
import IOKit.pwr_mgt

struct QuickNote: Codable, Identifiable {
    var id = UUID()
    var text: String
    var date = Date()
}

struct ShelfEntry: Codable, Identifiable {
    var id = UUID()
    var title: String
    var text: String?
    var storedName: String?
    var date = Date()
}

struct ClipboardEntry: Identifiable {
    let id = UUID()
    var text: String?
    var files: [URL] = []
    var image: Data?
    var date = Date()
    var title: String {
        if let text { return String(text.prefix(180)) }
        if !files.isEmpty { return files.map(\.lastPathComponent).joined(separator: "、") }
        return "图片"
    }
}

enum UtilityTab: String, CaseIterable {
    case notes = "便签", shelf = "暂存", clipboard = "剪贴板", focus = "专注"
}

struct SpeechRequest {
    var text: String
    var isReminder = false
}

/// Owns utility data and timers; no dependency on input-monitoring permission.
final class UtilityStore: ObservableObject {
    @Published var notes: [QuickNote] = []
    @Published var shelf: [ShelfEntry] = []
    @Published var history: [ClipboardEntry] = []
    @Published var tab: UtilityTab = .notes
    @Published var error = ""
    @Published var importing = false
    @Published var clipboardEnabled = UserDefaults.standard.object(forKey: "clipboardHistory") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardHistory")
            pasteboardCount = NSPasteboard.general.changeCount
            say(clipboardEnabled ? "historyOn" : "historyOff")
        }
    }
    @Published var bubblesEnabled = UserDefaults.standard.object(forKey: "utilityBubbles") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(bubblesEnabled, forKey: "utilityBubbles")
            if !bubblesEnabled { onSpeech?(SpeechRequest(text: "")) }
        }
    }
    @Published var restEnabled = UserDefaults.standard.object(forKey: "restReminder") as? Bool ?? true {
        didSet {
            UserDefaults.standard.set(restEnabled, forKey: "restReminder")
            continuousSeconds = 0; reminderDue = false; snoozeUntil = nil
            say(restEnabled ? "restOn" : "restOff")
        }
    }
    @Published var restInterval = UserDefaults.standard.object(forKey: "restInterval") as? Double ?? 50 {
        didSet {
            restInterval = min(120, max(10, restInterval))
            UserDefaults.standard.set(restInterval, forKey: "restInterval")
        }
    }
    @Published var restMinutes = UserDefaults.standard.object(forKey: "restMinutes") as? Double ?? 2 {
        didSet {
            restMinutes = min(15, max(1, restMinutes))
            UserDefaults.standard.set(restMinutes, forKey: "restMinutes")
        }
    }
    @Published var continuousSeconds: Double = 0
    @Published var todaySeconds: Double = 0
    @Published var reminderDue = false
    @Published var breakUntil: Date?
    @Published var awakeUntil: Date?
    @Published var keepDisplayAwake = false
    @Published var now = Date()
    var onSpeech: ((SpeechRequest) -> Void)?
    var onStatusChanged: (() -> Void)?
    private let root: URL
    private let filesRoot: URL
    private let dataURL: URL
    private var timer: Timer?
    private var pasteboardCount = NSPasteboard.general.changeCount
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var systemAvailable = true
    private var displayAvailable = true
    private var wasAway = false
    private var day = Calendar.current.startOfDay(for: Date())
    private var snoozeUntil: Date?
    private var assertion: IOPMAssertionID = 0
    private var observers: [NSObjectProtocol] = []
    private var lastLine: [String: String] = [:]
    private var lastClipboardBubble = Date.distantPast
    private var pendingImports = 0
    private var canSave = true

    private struct Saved: Codable {
        var notes: [QuickNote]
        var shelf: [ShelfEntry]
        var day: Date
        var todaySeconds: Double
    }

    init() {
        root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KurisuDesktop", isDirectory: true)
        filesRoot = root.appendingPathComponent("Shelf", isDirectory: true)
        dataURL = root.appendingPathComponent("utilities.json")
        do {
            try FileManager.default.createDirectory(at: filesRoot, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: dataURL.path) {
                let saved = try JSONDecoder().decode(Saved.self, from: Data(contentsOf: dataURL))
                notes = saved.notes; shelf = saved.shelf
                if Calendar.current.isDateInToday(saved.day) { todaySeconds = saved.todaySeconds }
            }
        } catch {
            // Preserve unreadable content before any future successful saves.
            let backup = root.appendingPathComponent("utilities-unreadable-\(UUID().uuidString).json")
            if FileManager.default.fileExists(atPath: dataURL.path) {
                do { try FileManager.default.copyItem(at: dataURL, to: backup) }
                catch { canSave = false }
            }
            self.error = "读取本地数据失败：\(error.localizedDescription)。请在 Application Support/KurisuDesktop 查看原文件或恢复备份。"
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.systemAvailable = false; self?.resetUsage(); self?.save()
            })
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.systemAvailable = true
                self?.lastTick = ProcessInfo.processInfo.systemUptime
                self?.pasteboardCount = NSPasteboard.general.changeCount
            })
        }
        observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            self?.displayAvailable = false; self?.resetUsage()
        })
        observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification,
                                           object: nil, queue: .main) { [weak self] _ in
            self?.displayAvailable = true; self?.lastTick = ProcessInfo.processInfo.systemUptime
        })
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.2
    }

    func say(_ event: String, suffix: String = "", reminder: Bool = false) {
        let lines: [String: [String]] = [
            "open": ["有什么要交给我的？说吧。", "便签、文件……我可不是只会站在这里的。", "需要帮忙就直说，不必客气。"],
            "note": ["记下来了。这下不用一直惦记着了。", "先写下来，脑容量留给重要的事。", "嗯，我记住了。别又自己忘了。"],
            "noteEdit": ["改好了。思路变了就及时记下来。", "记录已更新，这次可别记混。"],
            "shelf": ["那就帮你保管一会儿吧！", "放这儿吧，需要的时候再来拿。", "收好了。才不是特意替你整理的。"],
            "copy": ["给你，已经复制好了。", "找到了。下次不用再翻来翻去。", "复制好了，接着做你的事吧。"],
            "capture": ["刚复制的内容，先替你留着。", "这条先记在剪贴板里，免得找不到。"],
            "remove": ["这一条收掉了，剩下的还在。", "整理好了。清爽一点也不错。"],
            "clear": ["这次的剪贴板记录清空了，重新开始吧。", "旧记录整理掉了。需要的东西记得先暂存。"],
            "openItem": ["已经打开了，你接着用吧。", "找到了，就是这个。"],
            "reveal": ["位置给你找到了，就在这里。", "不用到处翻，我已经帮你定位好了。"],
            "historyOn": ["开始替你留意复制过的内容了。", "剪贴板记录开启，需要时来这里找。"],
            "historyOff": ["好，先不记录新的复制内容。", "记录暂停，之前的还在这里。"],
            "restOn": ["休息时间交给我提醒。可别逞强。", "计时开始。认真工作，也要认真休息。"],
            "restOff": ["好，先不提醒。也别忘了照顾眼睛。", "提醒关掉了。休息可别全忘了。"],
            "awake": ["这段时间我来盯着，你安心做事。", "好，我会守到时间结束。别把自己也熬坏了。"],
            "awakeEnd": ["约定的时间到了，电脑可以正常休息了。", "值守结束。需要的话再叫我。"],
            "awakeStop": ["好，恢复正常休眠。你也别一直硬撑。", "这就结束值守，交还给系统。"],
            "rest": ["先休息一下。一直盯着屏幕，效率也会下降的。", "该让眼睛歇一会儿了。这是合理建议，听到了吗？", "手头的事先放一放。站起来活动一下。"],
            "break": ["去看看远处吧，这里我替你守着。", "休息也算计划的一部分，别偷偷加班。"],
            "back": ["休息结束。现在思路应该清楚些了吧？", "回来了？好，慢慢接着来。"],
            "snooze": ["再给你五分钟。说好了，别一直拖。", "好，收个尾，五分钟后再提醒你。"],
            "error": ["这次没办成，看看面板里的说明吧。", "遇到一点问题，具体原因已经写在面板里了。"]
        ]
        let choices = lines[event] ?? ["处理好了。"]
        let line = choices.filter { $0 != lastLine[event] }.randomElement() ?? choices[0]
        lastLine[event] = line
        if bubblesEnabled || reminder {
            onSpeech?(SpeechRequest(text: line + (suffix.isEmpty ? "" : "\n" + suffix), isReminder: reminder))
        }
    }

    func save() {
        guard canSave else {
            error = "原数据无法读取且无法备份，已停止覆盖保存。请先复制面板内容并检查本地存储权限。"
            return
        }
        do {
            let data = try JSONEncoder().encode(Saved(notes: notes, shelf: shelf, day: day, todaySeconds: todaySeconds))
            try data.write(to: dataURL, options: .atomic)
        } catch { self.error = "保存失败：\(error.localizedDescription)。请保留当前窗口中的内容。" }
    }

    func addNote(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        notes.insert(QuickNote(text: String(clean.prefix(20000))), at: 0); save(); say("note")
    }
    func editNote(_ id: UUID, text: String) {
        guard let index = notes.firstIndex(where: { $0.id == id }),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        notes[index].text = String(text.prefix(20000)); save(); say("noteEdit")
    }
    func deleteNote(_ id: UUID) { notes.removeAll { $0.id == id }; save(); say("remove") }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        pasteboardCount = NSPasteboard.general.changeCount
        say("copy")
    }

    func addText(_ text: String) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        shelf.insert(ShelfEntry(title: String(clean.prefix(100)), text: String(clean.prefix(200000))), at: 0)
        save(); say("shelf"); tab = .shelf
    }

    /// Copy into owned storage, so the shelf survives source renames/deletion.
    func importFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        importing = true
        pendingImports += 1
        let destination = filesRoot
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var entries: [ShelfEntry] = []
            var failures: [String] = []
            for url in urls {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                let folder = destination.appendingPathComponent(UUID().uuidString, isDirectory: true)
                do {
                    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    let copy = folder.appendingPathComponent(url.lastPathComponent)
                    try FileManager.default.copyItem(at: url, to: copy)
                    entries.append(ShelfEntry(title: url.lastPathComponent,
                                              storedName: folder.lastPathComponent + "/" + url.lastPathComponent))
                } catch {
                    try? FileManager.default.removeItem(at: folder)
                    failures.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.shelf.insert(contentsOf: entries, at: 0)
                self.pendingImports -= 1; self.importing = self.pendingImports > 0
                self.tab = .shelf; self.save()
                if !entries.isEmpty { self.say("shelf", suffix: "已暂存 \(entries.count) 个文件。") }
                if !failures.isEmpty { self.error = failures.joined(separator: "\n"); self.say("error") }
            }
        }
    }

    func fileURL(_ entry: ShelfEntry) -> URL? {
        entry.storedName.map { filesRoot.appendingPathComponent($0) }
    }
    func deleteShelf(_ entry: ShelfEntry) {
        if let url = fileURL(entry) {
            do { try FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
            catch { self.error = "无法移除暂存副本：\(error.localizedDescription)"; return }
        }
        shelf.removeAll { $0.id == entry.id }; save(); say("remove")
    }
    func copyShelf(_ entry: ShelfEntry) {
        if let url = fileURL(entry) {
            guard FileManager.default.fileExists(atPath: url.path) else {
                error = "暂存副本已不在磁盘上，请移除这条记录后重新添加。"; say("error"); return
            }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.writeObjects([url as NSURL])
            pasteboardCount = NSPasteboard.general.changeCount; say("copy")
        } else if let text = entry.text { copyText(text) }
    }
    func chooseFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true; panel.canChooseDirectories = true
        if panel.runModal() == .OK { importFiles(panel.urls) }
    }

    @discardableResult
    func acceptPasteboard(_ board: NSPasteboard) -> Bool {
        if let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !files.isEmpty { importFiles(files); return true }
        if let text = board.string(forType: .string) ?? board.string(forType: .URL) {
            addText(text); return true
        }
        return false
    }

    private func sampleClipboard() {
        let board = NSPasteboard.general
        guard board.changeCount != pasteboardCount else { return }
        pasteboardCount = board.changeCount
        guard clipboardEnabled, systemAvailable, !IsSecureEventInputEnabled() else { return }
        let excluded = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType",
                        "org.nspasteboard.AutoGeneratedType", "com.agilebits.onepassword"]
        guard !(board.types ?? []).contains(where: { excluded.contains($0.rawValue) }) else { return }
        var entry = ClipboardEntry()
        if let files = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !files.isEmpty { entry.files = files }
        else if let text = board.string(forType: .string), !text.isEmpty {
            guard text.utf8.count <= 200000 else { return }
            entry.text = text
        } else if let image = NSImage(pasteboard: board),
                  let tiff = image.tiffRepresentation,
                  tiff.count <= 8_000_000 {
            entry.image = tiff
        } else { return }
        history.removeAll { $0.text == entry.text && $0.files == entry.files && $0.image == entry.image }
        history.insert(entry, at: 0)
        history = Array(history.prefix(40))
        while history.reduce(0, { $0 + ($1.image?.count ?? 0) }) > 32_000_000 {
            history.removeLast()
        }
        // Quiet cadence for passive copies; never echo clipboard text in a bubble.
        if now.timeIntervalSince(lastClipboardBubble) >= 45 {
            say("capture"); lastClipboardBubble = now
        }
    }

    func copyHistory(_ entry: ClipboardEntry) {
        let board = NSPasteboard.general
        if !entry.files.isEmpty {
            guard entry.files.allSatisfy({ FileManager.default.fileExists(atPath: $0.path) }) else {
                error = "原文件已移动或删除；剪贴板只保留引用，持久保存请加入暂存。"; say("error"); return
            }
            board.clearContents(); board.writeObjects(entry.files.map { $0 as NSURL })
        } else if let text = entry.text { board.clearContents(); board.setString(text, forType: .string) }
        else if let image = entry.image { board.clearContents(); board.setData(image, forType: .tiff) }
        pasteboardCount = board.changeCount; say("copy")
    }
    func clearHistory() { history.removeAll(); say("clear") }
    func removeHistory(_ id: UUID) { history.removeAll { $0.id == id }; say("remove") }
    func stashHistory(_ entry: ClipboardEntry) {
        if let text = entry.text { addText(text) }
        else if !entry.files.isEmpty { importFiles(entry.files) }
        else if let data = entry.image {
            let folder = filesRoot.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let url = folder.appendingPathComponent("剪贴板图片.tiff")
                try data.write(to: url, options: .atomic)
                shelf.insert(ShelfEntry(title: url.lastPathComponent,
                                       storedName: folder.lastPathComponent + "/" + url.lastPathComponent), at: 0)
                tab = .shelf; save(); say("shelf")
            } catch { self.error = "暂存图片失败：\(error.localizedDescription)"; say("error") }
        }
    }

    func startAwake(minutes: Int) {
        var newID: IOPMAssertionID = 0
        let type = keepDisplayAwake ? "PreventUserIdleDisplaySleep" : "PreventUserIdleSystemSleep"
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                               "Kurisu 临时保持唤醒" as CFString, &newID)
        guard result == kIOReturnSuccess else {
            error = "系统未能开启保持唤醒（\(result)），请重试。"; say("error"); return
        }
        releaseAssertion()
        assertion = newID; awakeUntil = Date().addingTimeInterval(Double(minutes)*60)
        say("awake", suffix: "本次 \(minutes) 分钟。")
    }
    private func releaseAssertion() {
        if assertion != 0 { IOPMAssertionRelease(assertion); assertion = 0 }
    }
    func stopAwake() {
        releaseAssertion(); awakeUntil = nil; say("awakeStop")
    }
    func beginBreak() {
        breakUntil = Date().addingTimeInterval(restMinutes*60)
        reminderDue = false; snoozeUntil = nil; continuousSeconds = 0
        tab = .focus; say("break")
    }
    func snoozeBreak() {
        reminderDue = false; snoozeUntil = Date().addingTimeInterval(5*60); say("snooze")
    }
    func finishBreak() {
        breakUntil = nil; resetUsage(); say("back")
    }
    func resetUsage() {
        continuousSeconds = 0; reminderDue = false; snoozeUntil = nil
    }
    func remaining(_ end: Date?) -> String {
        guard let end else { return "" }
        let seconds = max(0, Int(ceil(end.timeIntervalSince(now))))
        return String(format: "%02d:%02d", seconds/60, seconds%60)
    }
    var hoverSummary: String {
        if reminderDue { return "该休息了 · 点击处理" }
        if let breakUntil { return "休息中 · \(remaining(breakUntil))" }
        if let awakeUntil { return "保持唤醒 · 剩余 \(remaining(awakeUntil))" }
        if !shelf.isEmpty { return "替你保管着 \(shelf.count) 项 · 点击取用" }
        return "便签 · 暂存 · 剪贴板 · 专注"
    }

    private func tick() {
        now = Date()
        let uptime = ProcessInfo.processInfo.systemUptime
        let delta = uptime - lastTick; lastTick = uptime
        if !Calendar.current.isDate(day, inSameDayAs: now) {
            day = Calendar.current.startOfDay(for: now); todaySeconds = 0; save()
        }
        if let end = awakeUntil, now >= end {
            releaseAssertion(); awakeUntil = nil; say("awakeEnd")
        }
        if let end = breakUntil, now >= end { finishBreak() }
        sampleClipboard()
        if systemAvailable && displayAvailable && delta < 5 && breakUntil == nil {
            let idle = [CGEventType.keyDown, .mouseMoved, .leftMouseDown, .rightMouseDown, .scrollWheel]
                .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
            if idle >= restMinutes*60 {
                if !wasAway { resetUsage(); wasAway = true }
            } else if idle < 120 {
                if wasAway { wasAway = false }
                todaySeconds += delta
                if restEnabled {
                    continuousSeconds += delta
                    if continuousSeconds >= restInterval*60 && !reminderDue &&
                        (snoozeUntil == nil || now >= snoozeUntil!) {
                        reminderDue = true
                        say("rest", suffix: "已连续使用约 \(Int(continuousSeconds/60)) 分钟。", reminder: true)
                    }
                }
            }
        }
        if Int(uptime) % 60 == 0 { save() }
        onStatusChanged?()
    }
    func shutdown() {
        timer?.invalidate(); timer = nil; releaseAssertion(); save()
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        observers.removeAll()
    }
}
