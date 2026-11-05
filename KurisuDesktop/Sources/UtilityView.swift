import SwiftUI
import UniformTypeIdentifiers

enum UtilityTheme {
    static let ground = Color(red: 0.91, green: 0.94, blue: 0.96)
    static let ink = Color(red: 0.12, green: 0.19, blue: 0.25)
    static let muted = Color(red: 0.28, green: 0.36, blue: 0.42)
    static let accent = Color(red: 0.58, green: 0.24, blue: 0.13)
}

private final class UtilityDraft: ObservableObject {
    @Published var draft = ""
    @Published var stashText = ""
    @Published var search = ""
    @Published var editing: UUID?
    @Published var editText = ""
    @Published var awakeMinutes = 30
    @Published var dropTarget = false
}

struct UtilityView: View {
    @ObservedObject var store: UtilityStore
    @StateObject private var editor = UtilityDraft()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("交给我吧").font(.system(size: 21, weight: .semibold))
            Text(store.hoverSummary).font(.system(size: 12)).foregroundStyle(UtilityTheme.muted)
            Picker("工具", selection: $store.tab) {
                ForEach(UtilityTab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented)
            if !store.error.isEmpty {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle")
                    Text(store.error).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("收起") { store.error = "" }
                }.font(.system(size: 12)).foregroundStyle(UtilityTheme.accent)
            }
            Group {
                switch store.tab {
                case .notes: notes
                case .shelf: shelf
                case .clipboard: clipboard
                case .focus: focus
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider()
            HStack {
                Text(editor.dropTarget ? "松手，交给我保管。" : "文件、链接和文字都可以拖到小人或这里。")
                    .font(.system(size: 11)).foregroundStyle(UtilityTheme.muted)
                Spacer(minLength: 0)
            }
        }
        .padding(22).frame(width: 440, height: 600)
        .foregroundStyle(UtilityTheme.ink).tint(UtilityTheme.accent)
        .background(editor.dropTarget ? Color(red: 0.79, green: 0.85, blue: 0.89) : UtilityTheme.ground)
        .environment(\.colorScheme, .light)
        .onDrop(of: [UTType.fileURL.identifier, UTType.url.identifier, UTType.utf8PlainText.identifier],
                isTargeted: $editor.dropTarget, perform: drop)
    }

    private func empty(_ title: String, _ detail: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).font(.system(size: 24)).foregroundStyle(UtilityTheme.muted)
            Text(title).font(.headline)
            Text(detail).font(.system(size: 13)).foregroundStyle(UtilityTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 20)
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("先放下脑子里的事").font(.headline)
            TextEditor(text: $editor.draft).font(.system(size: 13))
                .frame(height: 76).overlay(Rectangle().stroke(UtilityTheme.muted.opacity(0.35)))
                .accessibilityLabel("新便签内容")
            HStack {
                Text("便签会在退出后保留。").font(.caption).foregroundStyle(UtilityTheme.muted)
                Spacer()
                Button("记下来") { store.addNote(editor.draft); editor.draft = "" }
                    .buttonStyle(.borderedProminent)
                    .disabled(editor.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: .command)
            }
            if store.notes.isEmpty { empty("还没有便签", "记下下一步、临时想法，或等会儿要处理的事。", icon: "note.text") }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(store.notes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            if editor.editing == note.id {
                                TextEditor(text: $editor.editText).frame(height: 90)
                                    .accessibilityLabel("编辑便签")
                                HStack {
                                    Button("取消") { editor.editing = nil }
                                    Button("保存修改") { store.editNote(note.id, text: editor.editText); editor.editing = nil }
                                        .disabled(editor.editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                                }
                            } else {
                                Text(note.text).font(.system(size: 13)).textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                                HStack {
                                    Text(note.date, style: .date).font(.caption).foregroundStyle(UtilityTheme.muted)
                                    Spacer()
                                    Button("复制") { store.copyText(note.text) }
                                    Button("编辑") { editor.editing = note.id; editor.editText = note.text }
                                    Button("删除") { store.deleteNote(note.id) }
                                }.controlSize(.small)
                            }
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var shelf: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("替你保管一会儿").font(.headline)
                Spacer()
                Button("添加文件…") { store.chooseFiles() }
            }
            HStack {
                TextField("粘贴链接或文字", text: $editor.stashText)
                    .onSubmit { stashTextNow() }
                Button("暂存") { stashTextNow() }
                    .disabled(editor.stashText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text("文件保存独立副本；可复制到 Finder、拖出或显示位置。移除只删除暂存副本。")
                .font(.caption).foregroundStyle(UtilityTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if store.importing { ProgressView("正在保存副本…").controlSize(.small) }
            if store.shelf.isEmpty && !store.importing {
                empty("把东西交给我", "拖入文件、文件夹或网页链接。你回来时，它们还在这里。", icon: "tray")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(store.shelf) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: entry.storedName != nil ? "doc" : "link")
                                Text(entry.title).font(.system(size: 13, weight: .medium))
                                    .lineLimit(3).textSelection(.enabled)
                                Spacer(minLength: 0)
                            }
                            HStack {
                                Button("复制") { store.copyShelf(entry) }
                                if let url = store.fileURL(entry) {
                                    Button("打开") { openFile(url) }
                                    Button("显示位置") { NSWorkspace.shared.activateFileViewerSelecting([url]); store.say("reveal") }
                                    Text("拖出").foregroundStyle(UtilityTheme.muted)
                                        .onDrag { NSItemProvider(object: url as NSURL) }
                                } else if let text = entry.text, let url = webURL(text) {
                                    Button("打开链接") {
                                        NSWorkspace.shared.open(url); store.say("openItem")
                                    }
                                    Text("拖出").foregroundStyle(UtilityTheme.muted)
                                        .onDrag { NSItemProvider(object: url as NSURL) }
                                } else {
                                    Text("拖出").foregroundStyle(UtilityTheme.muted)
                                        .onDrag { NSItemProvider(object: (entry.text ?? "") as NSString) }
                                }
                                Spacer(minLength: 0)
                                Button("移除") { store.deleteShelf(entry) }
                            }.controlSize(.small).font(.system(size: 12))
                            Divider()
                        }
                    }
                }
            }
        }
    }
    private func stashTextNow() { store.addText(editor.stashText); editor.stashText = "" }
    private func webURL(_ text: String) -> URL? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return nil }
        return url
    }
    private func openFile(_ url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            store.error = "暂存副本已不在磁盘上，请移除记录后重新添加。"; store.say("error"); return
        }
        NSWorkspace.shared.open(url); store.say("openItem")
    }

    private var clipboard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Toggle("记录剪贴板历史", isOn: $store.clipboardEnabled).toggleStyle(.switch)
                Spacer()
                Button("清空") { store.clearHistory() }.disabled(store.history.isEmpty)
            }
            Text("最近 40 条文字、文件引用和图片，仅本次运行保留。标记为机密的内容不记录。")
                .font(.caption).foregroundStyle(UtilityTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            TextField("搜索复制过的文字或文件名", text: $editor.search)
            if store.history.isEmpty {
                empty("还没有复制记录", store.clipboardEnabled ? "从现在起复制的内容会出现在这里。点“复制”即可取回。" : "记录已暂停，已有内容可以继续取用。", icon: "doc.on.clipboard")
            }
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(store.history.filter { editor.search.isEmpty || $0.title.localizedCaseInsensitiveContains(editor.search) }) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            if let data = entry.image, let image = NSImage(data: data) {
                                Image(nsImage: image).resizable().scaledToFit()
                                    .frame(maxHeight: 100).accessibilityLabel("复制过的图片")
                            }
                            Text(entry.title).font(.system(size: 13)).lineLimit(3).textSelection(.enabled)
                            HStack {
                                Text(entry.date, style: .time).font(.caption).foregroundStyle(UtilityTheme.muted)
                                Spacer()
                                Button("复制") { store.copyHistory(entry) }
                                Button("加入暂存") { store.stashHistory(entry) }
                                Button("删除") { store.removeHistory(entry.id) }
                            }.controlSize(.small)
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var focus: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("临时保持唤醒").font(.headline)
                if let end = store.awakeUntil {
                    HStack {
                        Text("剩余 \(store.remaining(end))").monospacedDigit()
                        Spacer()
                        Button("立即结束") { store.stopAwake() }
                    }
                    Text("结束后恢复系统原有的休眠安排。").font(.caption).foregroundStyle(UtilityTheme.muted)
                } else {
                    Picker("持续时间", selection: $editor.awakeMinutes) {
                        Text("15 分钟").tag(15); Text("30 分钟").tag(30)
                        Text("1 小时").tag(60); Text("2 小时").tag(120)
                    }
                    Toggle("同时保持屏幕亮着", isOn: $store.keepDisplayAwake)
                    HStack {
                        Button("开始保持唤醒") { store.startAwake(minutes: editor.awakeMinutes) }
                            .buttonStyle(.borderedProminent)
                        Text("本次生效").font(.caption).foregroundStyle(UtilityTheme.muted)
                    }
                }
                Divider()
                Toggle("屏幕使用休息提醒", isOn: $store.restEnabled).font(.headline)
                Text("今日估算使用 \(Int(store.todaySeconds/60)) 分钟 · 本轮 \(Int(store.continuousSeconds/60)) 分钟")
                    .font(.system(size: 13)).monospacedDigit()
                Text("仅在应用运行时估算有操作的使用时长，不是系统“屏幕使用时间”。离开、熄屏或锁屏不累计；静止阅读超过两分钟可能少计。")
                    .font(.caption).foregroundStyle(UtilityTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Stepper("每 \(Int(store.restInterval)) 分钟提醒", value: $store.restInterval, in: 10...120, step: 5)
                Stepper("休息 \(Int(store.restMinutes)) 分钟", value: $store.restMinutes, in: 1...15)
                if let end = store.breakUntil {
                    HStack {
                        Text("正在休息 · \(store.remaining(end))").monospacedDigit()
                        Spacer()
                        Button("提前结束") { store.finishBreak() }
                    }
                } else {
                    HStack {
                        Button(store.reminderDue ? "现在休息" : "提前歇一会儿") { store.beginBreak() }
                        if store.reminderDue { Button("五分钟后提醒") { store.snoozeBreak() } }
                    }
                }
                Text("不操作达到设定休息时长，会自动重置本轮计时。").font(.caption).foregroundStyle(UtilityTheme.muted)
                Divider()
                Toggle("操作后冒出情境气泡", isOn: $store.bubblesEnabled)
                Text("气泡随机选句；连续复制时会减少打扰。休息提醒仍会显示操作按钮。")
                    .font(.caption).foregroundStyle(UtilityTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func drop(_ providers: [NSItemProvider]) -> Bool {
        let accepted = providers.filter {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) ||
            $0.hasItemConformingToTypeIdentifier(UTType.utf8PlainText.identifier)
        }
        for provider in accepted {
            let type = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
                ? UTType.fileURL.identifier : provider.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                ? UTType.url.identifier : UTType.utf8PlainText.identifier
            provider.loadItem(forTypeIdentifier: type, options: nil) { item, error in
                DispatchQueue.main.async {
                    if let error { store.error = "拖入失败：\(error.localizedDescription)"; store.say("error"); return }
                    var url = item as? URL
                    if url == nil, let data = item as? Data, type != UTType.utf8PlainText.identifier {
                        url = URL(dataRepresentation: data, relativeTo: nil)
                    }
                    if let url {
                        if url.isFileURL { store.importFiles([url]) }
                        else { store.addText(url.absoluteString) }
                    } else if let text = item as? String { store.addText(text) }
                    else if let data = item as? Data, let text = String(data: data, encoding: .utf8) { store.addText(text) }
                    else { store.error = "无法读取拖入内容，请试试粘贴文字或“添加文件”。"; store.say("error") }
                }
            }
        }
        return !accepted.isEmpty
    }
}
