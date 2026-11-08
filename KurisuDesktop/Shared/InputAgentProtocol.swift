import Foundation

/// Local memory-only IPC. No raw key events or text cross this boundary.
enum InputAgentProtocol {
    static let version = 1
    static let identifier = "local.kurisu.inputagent"
    static let name = "KurisuInputAgent"
    static let displayName = "Kurisu 输入监听"
}

struct InputAgentRequest: Codable {
    let version: Int
    let token: String
    let enabled: Bool
    let requestPermission: Bool
    let restart: Bool
    let quit: Bool
}

struct InputAgentReply: Codable {
    let version: Int
    let token: String
    let buildID: String
    let permission: Bool
    let listening: Bool
    let secureInput: Bool
    let activeSession: Bool
    let keyboardActivity: Bool
    let typingCount: Int
    let interrupted: Bool
    let mouseEvent: UInt32?
}
