import SwiftUI

/// Read-only until an explicit button click opens the corresponding tool tab.
/// Clipboard contents are never exposed merely by hovering over the character.
struct HoverSummaryView: View {
    @ObservedObject var store: UtilityStore
    let open: (UtilityTab) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("有什么需要我帮忙的？").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 0)
            }
            Button { open(.notes) } label: {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Label("最近便签", systemImage: "note.text").font(.system(size: 11, weight: .medium))
                        Spacer()
                        Text(store.notes.isEmpty ? "记一条" : "\(store.notes.count) 条")
                            .font(.system(size: 11))
                    }.foregroundStyle(UtilityTheme.muted)
                    Text(store.notes.first?.text ?? "把临时想法记在这里，回来就能接着做。")
                        .font(.system(size: 13)).lineLimit(2)
                        .frame(maxWidth: .infinity, minHeight: 34, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("打开便签")
            Divider()
            HStack(spacing: 16) {
                summaryButton("暂存", count: store.shelf.count, icon: "tray", tab: .shelf)
                Spacer(minLength: 0)
                summaryButton("剪贴板", count: store.history.count, icon: "doc.on.clipboard", tab: .clipboard)
            }
            VStack(alignment: .leading, spacing: 6) {
                Label(restStatus, systemImage: store.reminderDue ? "cup.and.saucer" : "leaf")
                Label(awakeStatus, systemImage: "sun.max")
            }
            .font(.system(size: 12)).foregroundStyle(UtilityTheme.muted)
            .monospacedDigit()
            HStack {
                Button("新建便签") { open(.notes) }
                Spacer()
                Button(store.reminderDue ? "处理休息提醒" : "专注与休息") { open(.focus) }
            }.controlSize(.small)
        }
        .padding(16).frame(width: 304, height: 270, alignment: .topLeading)
        .foregroundStyle(UtilityTheme.ink).tint(UtilityTheme.accent)
        .background(UtilityTheme.ground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .environment(\.colorScheme, .light)
    }

    private func summaryButton(_ title: String, count: Int, icon: String, tab: UtilityTab) -> some View {
        Button { open(tab) } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text("\(title) \(count) 项")
            }.font(.system(size: 12, weight: .medium))
        }.buttonStyle(.plain).help("打开\(title)")
    }

    private var restStatus: String {
        if store.reminderDue { return "该让眼睛歇一会儿了" }
        if let end = store.breakUntil { return "正在休息 · 剩余 \(store.remaining(end))" }
        if !store.restEnabled { return "休息提醒已关闭" }
        let minutes = max(1, Int(ceil((store.restInterval*60-store.continuousSeconds)/60)))
        return "本轮约 \(Int(store.continuousSeconds/60)) 分钟 · 约 \(minutes) 分钟后休息"
    }
    private var awakeStatus: String {
        if let end = store.awakeUntil { return "保持唤醒 · 剩余 \(store.remaining(end))" }
        return "保持唤醒未开启"
    }
}
