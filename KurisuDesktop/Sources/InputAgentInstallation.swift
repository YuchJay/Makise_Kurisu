import AppKit
import CryptoKit
import Security

enum InputAgentInstallation {
    struct Result {
        let url: URL
        let buildID: String
        let replaced: Bool
    }

    static var installedURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("KurisuDesktop/InputAgent/KurisuInputAgent.app", isDirectory: true)
    }

    private static func info(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
        guard let values = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              values["CFBundleIdentifier"] as? String == InputAgentProtocol.identifier,
              values["CFBundleExecutable"] as? String == InputAgentProtocol.name,
              let buildID = values["InputAgentBuildID"] as? String, !buildID.isEmpty else {
            throw failure("输入监听组件信息不完整，请重新构建应用。")
        }
        return values
    }

    private static func validSignature(_ url: URL) -> Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess,
              let code else { return false }
        return SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: kSecCSStrictValidate), nil) == errSecSuccess
    }

    private static func executableHash(_ url: URL) throws -> Data {
        let binary = url.appendingPathComponent("Contents/MacOS/\(InputAgentProtocol.name)")
        return Data(SHA256.hash(data: try Data(contentsOf: binary)))
    }

    /// Runs off the UI thread. Matching copies are never rewritten or re-signed.
    static func prepare() throws -> Result {
        let manager = FileManager.default
        let bundled = Bundle.main.bundleURL.appendingPathComponent(
            "Contents/Helpers/KurisuInputAgent.app", isDirectory: true)
        let metadata = try info(bundled)
        guard validSignature(bundled) else { throw failure("应用内的输入监听组件签名无效，请重新构建应用。") }
        let buildID = metadata["InputAgentBuildID"] as! String
        let target = installedURL
        if let old = try? info(target), old["InputAgentBuildID"] as? String == buildID,
           validSignature(target), try executableHash(target) == executableHash(bundled) {
            return Result(url: target, buildID: buildID, replaced: false)
        }
        let folder = target.deletingLastPathComponent()
        try manager.createDirectory(at: folder, withIntermediateDirectories: true,
                                    attributes: [.posixPermissions: 0o700])
        let staging = folder.appendingPathComponent(".install-\(UUID().uuidString).app")
        let backup = folder.appendingPathComponent(".previous-\(UUID().uuidString).app")
        defer { try? manager.removeItem(at: staging) }
        try manager.copyItem(at: bundled, to: staging)
        guard validSignature(staging) else { throw failure("输入监听组件复制校验失败，原组件已保留。") }
        let existing = NSRunningApplication.runningApplications(withBundleIdentifier: InputAgentProtocol.identifier)
            .filter { $0.bundleURL?.standardizedFileURL == target.standardizedFileURL }
        for app in existing { _ = app.terminate() }
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        while existing.contains(where: { !$0.isTerminated }) && ProcessInfo.processInfo.systemUptime < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard existing.allSatisfy(\.isTerminated) else {
            throw failure("旧的输入监听组件仍在退出，请稍后点“重新连接”。")
        }
        let hadExisting = manager.fileExists(atPath: target.path)
        if hadExisting { try manager.moveItem(at: target, to: backup) }
        do {
            try manager.moveItem(at: staging, to: target)
        } catch {
            if hadExisting { try? manager.moveItem(at: backup, to: target) }
            throw error
        }
        if hadExisting { try? manager.removeItem(at: backup) }
        return Result(url: target, buildID: buildID, replaced: hadExisting)
    }

    private static func failure(_ text: String) -> NSError {
        NSError(domain: "KurisuInputAgent", code: 1, userInfo: [NSLocalizedDescriptionKey: text])
    }
}
