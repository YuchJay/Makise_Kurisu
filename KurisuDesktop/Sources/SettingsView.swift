import SwiftUI

private enum Theme {
    static let background = Color(red: 0.91, green: 0.94, blue: 0.96)
    static let sidebar = Color(red: 0.79, green: 0.85, blue: 0.89)
    static let ink = Color(red: 0.12, green: 0.19, blue: 0.25)
    static let muted = Color(red: 0.28, green: 0.36, blue: 0.42)
    static let accent = Color(red: 0.58, green: 0.24, blue: 0.13)
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Kurisu").font(.system(size: 25, weight: .bold, design: .monospaced))
                Text("你的像素桌面搭档").font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer(minLength: 8)
                Image(decorative: model.laptopPreviewFrame.map { model.atlas.laptopImage(frame: $0) }
                      ?? model.atlas.image(.idle, frame: 0), scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 144, height: 156)
                    .frame(maxWidth: .infinity)
                Text(model.activity)
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 8)
                Text("拖动移动 · 点击打开工具\n拖入暂存 · 右键快捷菜单")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(5)
                Button("回到屏幕右下角") { model.resetPosition() }
                    .controlSize(.large)
                Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "") · 本地运行")
                    .font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            .padding(24)
            .frame(width: 224)
            .frame(maxHeight: .infinity)
            .background(Theme.sidebar)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("让她陪你一起工作").font(.system(size: 22, weight: .semibold))
                        Text("开始打字，她会坐到小桌后打开电脑。短暂停顿会等你，停下后合上电脑起身。")
                            .font(.system(size: 13)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("打字响应").font(.headline)
                            Spacer()
                            Text(permissionText)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(model.monitoring ? Theme.ink : Theme.accent)
                        }
                        Text("需要 macOS「输入监控」权限。仅使用按键时机与频率，不读取或保存输入文字。")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack {
                            Button(model.permissionGranted ? "打开权限设置" : "开启打字响应") {
                                if model.permissionGranted { model.openPrivacySettings() }
                                else { model.enableInput() }
                            }
                            .buttonStyle(.borderedProminent)
                            Button("显示当前应用") { model.revealApplication() }
                            if model.permissionGranted {
                                Button("重新连接") { model.reconnectInput() }
                            }
                        }
                        if model.permissionGranted && !model.monitoring && !model.paused {
                            Text("权限已允许但尚未连接。可先重新连接，仍无反应时退出并重新打开应用。")
                                .font(.system(size: 12)).foregroundStyle(Theme.accent)
                        }
                        if !model.permissionGranted {
                            Text("若系统里已勾选却仍未授权，请移除旧条目，重新添加「显示当前应用」中的 Kurisu.app，再退出重开。")
                                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if model.secureInputActive {
                            Text("系统正处于安全输入状态，暂时停止键盘响应。结束密码输入，或关闭终端的「安全键盘输入」后自动恢复。")
                                .font(.system(size: 12)).foregroundStyle(Theme.accent)
                                .fixedSize(horizontal: false, vertical: true)
                        } else if model.monitoring {
                            Text(model.keyboardFeedback)
                                .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        }
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 12) {
                        Text("陪伴方式").font(.headline)
                        Toggle("响应打字节奏", isOn: $model.reactsToTyping)
                        Button("预览坐下打字") { model.previewLaptop() }
                            .disabled(model.paused)
                        Toggle("响应鼠标靠近、点击和滚动", isOn: $model.reactsToMouse)
                        Toggle("减少动画（保留静态状态反馈）", isOn: $model.reducedMotion)
                        Text("闲置 90 秒后坐下休息，保持轻微呼吸，偶尔低头。开始操作后恢复。")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Text("宠物大小").font(.headline)
                        Picker("宠物大小", selection: $model.size) {
                            Text("小").tag(144.0)
                            Text("标准").tag(192.0)
                            Text("大").tag(288.0)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text("所有尺寸均保留清晰像素边缘。")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        Text("随手工具").font(.headline)
                        Text("临时便签、文件与链接暂存、剪贴板历史、保持唤醒和休息提醒。点击小人即可打开。")
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("打开随手工具") { model.utilityWindows?.showTools() }
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("登录时启动", isOn: Binding(
                            get: { model.startupEnabled },
                            set: { model.setStartup($0) }
                        ))
                        Text(model.startupStatus)
                            .font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Button("打开系统登录项设置") { model.openLoginSettings() }
                        if !model.message.isEmpty {
                            Text(model.message).font(.system(size: 12)).foregroundStyle(Theme.accent)
                                .textSelection(.enabled)
                        }
                        HStack {
                            Button(model.paused ? "继续陪伴" : "暂停陪伴") { model.togglePause() }
                            Button(model.hidden ? "显示桌宠" : "隐藏桌宠") { model.toggleHidden() }
                            Spacer()
                            Button("退出应用") { NSApplication.shared.terminate(nil) }
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 460)
            .background(Theme.background)
        }
        .foregroundStyle(Theme.ink)
        .tint(Theme.accent)
        .frame(width: 684, height: 680)
        .environment(\.colorScheme, .light)
    }

    private var permissionText: String {
        if model.paused { return "已暂停监听" }
        if model.secureInputActive { return "安全输入中" }
        if model.monitoring { return "监听已开启" }
        return model.permissionGranted ? "等待连接" : "尚未授权"
    }
}
