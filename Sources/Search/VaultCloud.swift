import Foundation
import Security

// Passwords in iCloud Keychain, shared with Search on the iPhone.
//
// Not in Office Commun's Search: added for this build. Vault keeps its own
// queries; each call it makes to the keychain comes through here. With the
// keychain group in the entitlements, its items live in the data protection
// keychain under E653G759EN.cat.correal.search, synchronizable, and iCloud
// Keychain carries them to the iPhone app, which reads the same group with
// the same attributes (Victor's SINCRONIZACION.md).
//
// What Search kept before, in the login keychain, is still listed and still
// filled in. The first time one is read — macOS may ask, once — a copy goes
// to the shared group, which is read first from then on. The old one stays
// where it is: taking it away could ask a second time, and it is never
// listed twice. Without the group — a build without Victor's profile, or a test run
// not given SEARCH_SYNC_KEYCHAIN — every call goes to the keychain as before.

enum VaultCloud {
    static let group = "E653G759EN.cat.correal.search"

    /// Whether this build may use the shared group. A test run that may also
    /// starts by clearing its own items when given SEARCH_SYNC_KEYCHAIN_DROP.
    static let available: Bool = {
        if Store.testing, ProcessInfo.processInfo.environment["SEARCH_SYNC_KEYCHAIN"] == nil { return false }
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "keychain-access-groups" as CFString, nil),
              let groups = value as? [String], groups.contains(group)
        else { return false }
        if Store.testing, ProcessInfo.processInfo.environment["SEARCH_SYNC_KEYCHAIN_DROP"] != nil, let world = Store.world {
            SecItemDelete(shared([kSecClass as String: kSecClassInternetPassword,
                                  kSecAttrLabel as String: "Search (\(world))"]) as CFDictionary)
        }
        return true
    }()

    /// The same query, asked of the shared group. Items made there sync
    /// through iCloud Keychain — except a test run's, which stay on this Mac.
    private static func shared(_ query: [String: Any], adding: Bool = false) -> [String: Any] {
        var asked = query
        asked[kSecUseDataProtectionKeychain as String] = true
        asked[kSecAttrAccessGroup as String] = group
        asked[kSecAttrSynchronizable as String] = adding
            ? (Store.testing ? kCFBooleanFalse : kCFBooleanTrue) as Any
            : kSecAttrSynchronizableAny
        return asked
    }

    /// The same query, asked of the login keychain only, where Search kept
    /// passwords before. Said explicitly: an app with a keychain group that
    /// leaves it unsaid reaches the shared group too — a delete meant for an
    /// old item took the new one with it.
    private static func before(_ query: [String: Any]) -> [String: Any] {
        var asked = query
        asked[kSecUseDataProtectionKeychain as String] = false
        return asked
    }

    // MARK: - what Vault calls

    static func copyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard available, let asked = query as? [String: Any] else { return SecItemCopyMatching(query, result) }
        var mine: CFTypeRef?
        let status = SecItemCopyMatching(shared(asked) as CFDictionary, &mine)
        diary("copy \(asked[kSecAttrAccount as String] ?? "*")@\(asked[kSecAttrServer as String] ?? "*") data=\(asked[kSecReturnData as String] != nil) -> \(status) \(rows(mine).count) rows")

        // One secret: the shared group's, or the old one, which then moves.
        if (asked[kSecReturnData as String] as? Bool) == true {
            if status == errSecSuccess {
                result?.pointee = mine
                return status
            }
            var old: CFTypeRef?
            let was = SecItemCopyMatching(before(asked) as CFDictionary, &old)
            if was == errSecSuccess {
                result?.pointee = old
                move(asked, secret: old)
            }
            return was
        }

        // A list: the shared group's, then anything from before not also there.
        var old: CFTypeRef?
        let was = SecItemCopyMatching(before(asked) as CFDictionary, &old)
        let ours = status == errSecSuccess ? rows(mine) : []
        let have = Set(ours.map(key))
        let all = ours + (was == errSecSuccess ? rows(old) : []).filter { !have.contains(key($0)) }
        guard !all.isEmpty else { return errSecItemNotFound }
        result?.pointee = all as CFArray
        return errSecSuccess
    }

    static func update(_ query: CFDictionary, _ fields: CFDictionary) -> OSStatus {
        guard available, let asked = query as? [String: Any] else { return SecItemUpdate(query, fields) }
        return SecItemUpdate(shared(asked) as CFDictionary, fields)
    }

    static func add(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard available, let item = attributes as? [String: Any] else { return SecItemAdd(attributes, result) }
        let status = SecItemAdd(shared(item, adding: true) as CFDictionary, result)
        diary("add \(item[kSecAttrAccount as String] ?? "?") -> \(status)")
        return status
    }

    @discardableResult
    static func delete(_ query: CFDictionary) -> OSStatus {
        guard available, let asked = query as? [String: Any] else { return SecItemDelete(query) }
        let mine = SecItemDelete(shared(asked) as CFDictionary)
        let was = SecItemDelete(before(asked) as CFDictionary)
        return mine == errSecSuccess || was == errSecSuccess ? errSecSuccess : mine
    }

    // MARK: - moving across

    /// An item from before, just read: copied into the shared group with what
    /// it said (its protocol, when it was last used).
    private static func move(_ asked: [String: Any], secret: CFTypeRef?) {
        guard let data = secret as? Data,
              let server = asked[kSecAttrServer as String] as? String,
              let account = asked[kSecAttrAccount as String] as? String,
              let label = asked[kSecAttrLabel as String] as? String
        else { return }
        let name: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: label,
        ]
        var found: CFTypeRef?
        var look = name
        look[kSecReturnAttributes as String] = true
        look[kSecMatchLimit as String] = kSecMatchLimitOne
        SecItemCopyMatching(before(look) as CFDictionary, &found)
        let said = found as? [String: Any] ?? [:]

        var item = name
        item[kSecValueData as String] = data
        item[kSecAttrAuthenticationType as String] = kSecAttrAuthenticationTypeHTMLForm
        item[kSecAttrProtocol as String] = said[kSecAttrProtocol as String] ?? kSecAttrProtocolHTTPS
        if let comment = said[kSecAttrComment as String] { item[kSecAttrComment as String] = comment }
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        let added = SecItemAdd(shared(item, adding: true) as CFDictionary, nil)
        diary("move \(account) -> \(added)")
    }

    /// A test run's diary of keychain calls (no secrets), for Tests/cloud_keychain.py.
    private static func diary(_ line: String) {
        guard Store.testing, let data = (line + "\n").data(using: .utf8) else { return }
        let file = Store.file("keychain-events.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else { try? data.write(to: file) }
    }

    private static func rows(_ found: CFTypeRef?) -> [[String: Any]] {
        if let many = found as? [[String: Any]] { return many }
        if let one = found as? [String: Any] { return [one] }
        return []
    }

    private static func key(_ row: [String: Any]) -> String {
        (row[kSecAttrServer as String] as? String ?? "") + "\u{1}" + (row[kSecAttrAccount as String] as? String ?? "")
    }
}
