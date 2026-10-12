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
// listed twice. It goes only when you remove it, or the copy that hides it
// (see `delete`). Without the group — a build without Victor's profile, or a
// test run not given SEARCH_SYNC_KEYCHAIN — every call goes to the keychain
// as before.
//
// Each item listed comes with the keychain's reference to it, and Vault
// reads, notes and removes an item by that reference: two items can share a
// site and an account. A row from the login keychain is marked `old`, and a
// query by its reference carries the mark back, so each reference goes only
// to the keychain it came from. The login keychain goes by a reference alone
// and ignores the rest of the query; handed one from the shared group, it
// could name a different item.

enum VaultCloud {
    static let group = "E653G759EN.cat.correal.search"

    /// The mark on a row from the login keychain, and on a query by that
    /// row's reference. Never handed to the keychain itself.
    static let old = "search.old"

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
        guard available, var asked = query as? [String: Any] else { return SecItemCopyMatching(query, result) }
        let isOld = asked.removeValue(forKey: old) != nil
        if asked[kSecValuePersistentRef as String] != nil { return copy(one: asked, isOld: isOld, result) }
        var mine: CFTypeRef?
        let status = SecItemCopyMatching(shared(asked) as CFDictionary, &mine)
        diary("copy \(asked[kSecAttrAccount as String] ?? "*")@\(asked[kSecAttrServer as String] ?? "*") data=\(asked[kSecReturnData as String] != nil) -> \(status) \(rows(mine).count) rows")

        // One secret: the shared group's, or the old one, which then moves.
        if (asked[kSecReturnData as String] as? Bool) == true {
            if status == errSecSuccess {
                result?.pointee = mine
                return status
            }
            var found: CFTypeRef?
            let was = SecItemCopyMatching(before(asked) as CFDictionary, &found)
            if was == errSecSuccess {
                result?.pointee = found
                move(asked, secret: found)
            }
            return was
        }

        // A list: the shared group's, then anything from before not also
        // there, marked as such.
        var found: CFTypeRef?
        let was = SecItemCopyMatching(before(asked) as CFDictionary, &found)
        let ours = status == errSecSuccess ? rows(mine) : []
        let have = Set(ours.map(key))
        let theirs = (was == errSecSuccess ? rows(found) : []).filter { !have.contains(key($0)) }
        let all = ours + theirs.map { row -> [String: Any] in
            var marked = row
            marked[old] = true
            return marked
        }
        guard !all.isEmpty else { return errSecItemNotFound }
        result?.pointee = all as CFArray
        return errSecSuccess
    }

    /// One item, by its reference, in the keychain it is in. An old one's
    /// secret, once read, moves like one asked for by name, and the item
    /// handed back carries the copy's reference instead of its own — or,
    /// if no copy could be made, its own with the mark.
    private static func copy(one asked: [String: Any], isOld: Bool, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard isOld else {
            // The reference and what to hand back, and nothing to narrow it:
            // the shared group answers errSecParam to a read by reference
            // with a label, a group or a server beside it (an update or a
            // delete takes them). The reference came from a list of ours.
            let kept = [kSecClass, kSecValuePersistentRef, kSecReturnData, kSecReturnAttributes,
                        kSecReturnPersistentRef, kSecMatchLimit].map { $0 as String }
            var one = asked.filter { kept.contains($0.key) }
            one[kSecUseDataProtectionKeychain as String] = true
            one[kSecAttrSynchronizable as String] = kSecAttrSynchronizableAny
            let status = SecItemCopyMatching(one as CFDictionary, result)
            diary("copy ref data=\(asked[kSecReturnData as String] != nil) -> \(status)")
            return status
        }
        guard (asked[kSecReturnData as String] as? Bool) == true else {
            return SecItemCopyMatching(before(asked) as CFDictionary, result)
        }
        // Its attributes with it: what the copy is made of.
        var look = asked
        look[kSecReturnAttributes as String] = true
        look[kSecReturnPersistentRef as String] = true
        look[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        let was = SecItemCopyMatching(before(look) as CFDictionary, &found)
        diary("copy old ref -> \(was)")
        guard was == errSecSuccess, var item = found as? [String: Any],
              let data = item[kSecValueData as String] as? Data
        else { return was }
        if let copy = move(item, data: data) {
            item[kSecValuePersistentRef as String] = copy
        } else {
            item[old] = true
        }
        result?.pointee = item as CFDictionary
        return was
    }

    /// Only the shared group is written to: the login keychain's items are
    /// read, copied across, and left (see `delete` for when one goes).
    static func update(_ query: CFDictionary, _ fields: CFDictionary) -> OSStatus {
        guard available, var asked = query as? [String: Any] else { return SecItemUpdate(query, fields) }
        guard asked.removeValue(forKey: old) == nil else { return errSecItemNotFound }
        let status = SecItemUpdate(shared(asked) as CFDictionary, fields)
        if asked[kSecValuePersistentRef as String] != nil { diary("update ref -> \(status)") }
        return status
    }

    static func add(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus {
        guard available, let item = attributes as? [String: Any] else { return SecItemAdd(attributes, result) }
        let status = SecItemAdd(shared(item, adding: true) as CFDictionary, result)
        diary("add \(item[kSecAttrAccount as String] ?? "?") -> \(status)")
        return status
    }

    /// Called only when you remove a password. By its reference, that one
    /// item goes, from the keychain it is in, and with it whatever would
    /// take its place in the list as though the removal hadn't happened:
    ///
    /// - for an item in the shared group that was the last one there for its
    ///   site and account, the old items under them in the login keychain,
    ///   which the list had hidden behind it;
    /// - for an old item, the copy a read of it already made in the shared
    ///   group (same site, account and protocol).
    ///
    /// Without a reference, everything of ours under that name goes, here
    /// and from before, as it always did.
    @discardableResult
    static func delete(_ query: CFDictionary) -> OSStatus {
        guard available, var asked = query as? [String: Any] else { return SecItemDelete(query) }
        let isOld = asked.removeValue(forKey: old) != nil
        guard let ref = asked.removeValue(forKey: kSecValuePersistentRef as String) else {
            let mine = SecItemDelete(shared(asked) as CFDictionary)
            let was = SecItemDelete(before(asked) as CFDictionary)
            return mine == errSecSuccess || was == errSecSuccess ? errSecSuccess : mine
        }
        // What is left of the query names the site and account.
        let name = asked

        if isOld {
            // Its own protocol, read before it goes: the copy has the same.
            var look: [String: Any] = [
                kSecClass as String: kSecClassInternetPassword,
                kSecValuePersistentRef as String: ref,
                kSecReturnAttributes as String: true,
                kSecMatchLimit as String: kSecMatchLimitOne,
            ]
            var found: CFTypeRef?
            SecItemCopyMatching(before(look) as CFDictionary, &found)
            let said = found as? [String: Any] ?? [:]
            look = name
            look[kSecValuePersistentRef as String] = ref
            let was = SecItemDelete(before(look) as CFDictionary)
            diary("delete old ref -> \(was)")
            if was == errSecSuccess, let server = said[kSecAttrServer as String], let account = said[kSecAttrAccount as String] {
                var copy = name
                copy[kSecAttrServer as String] = server
                copy[kSecAttrAccount as String] = account
                copy[kSecAttrProtocol as String] = said[kSecAttrProtocol as String] ?? kSecAttrProtocolHTTPS
                SecItemDelete(shared(copy) as CFDictionary)
            }
            return was
        }

        var one = name
        one[kSecValuePersistentRef as String] = ref
        let mine = SecItemDelete(shared(one) as CFDictionary)
        diary("delete ref -> \(mine)")
        guard mine == errSecSuccess, name[kSecAttrServer as String] != nil, name[kSecAttrAccount as String] != nil else { return mine }
        var left = name
        left[kSecReturnAttributes as String] = true
        left[kSecMatchLimit as String] = kSecMatchLimitOne
        var found: CFTypeRef?
        if SecItemCopyMatching(shared(left) as CFDictionary, &found) == errSecItemNotFound {
            let was = SecItemDelete(before(name) as CFDictionary)
            diary("delete old behind -> \(was)")
        }
        return mine
    }

    // MARK: - moving across

    /// An item from before, read by name: copied into the shared group with
    /// what it said (its protocol, when it was last used).
    private static func move(_ asked: [String: Any], secret: CFTypeRef?) {
        guard let data = secret as? Data,
              let server = asked[kSecAttrServer as String] as? String,
              let account = asked[kSecAttrAccount as String] as? String,
              let label = asked[kSecAttrLabel as String] as? String
        else { return }
        var found: CFTypeRef?
        let look: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: label,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        SecItemCopyMatching(before(look) as CFDictionary, &found)
        var said = found as? [String: Any] ?? [:]
        said[kSecAttrServer as String] = server
        said[kSecAttrAccount as String] = account
        said[kSecAttrLabel as String] = label
        move(said, data: data)
    }

    /// An item from before, with its attributes and secret: copied into the
    /// shared group with what it said. The copy's reference, if it was made.
    @discardableResult
    private static func move(_ said: [String: Any], data: Data) -> Data? {
        guard let server = said[kSecAttrServer as String] as? String,
              let account = said[kSecAttrAccount as String] as? String,
              let label = said[kSecAttrLabel as String] as? String
        else { return nil }
        var item: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: server,
            kSecAttrAccount as String: account,
            kSecAttrLabel as String: label,
            kSecValueData as String: data,
            kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeHTMLForm,
            kSecAttrProtocol as String: said[kSecAttrProtocol as String] ?? kSecAttrProtocolHTTPS,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
            kSecReturnPersistentRef as String: true,
        ]
        if let comment = said[kSecAttrComment as String] { item[kSecAttrComment as String] = comment }
        var made: CFTypeRef?
        let added = SecItemAdd(shared(item, adding: true) as CFDictionary, &made)
        diary("move \(account) -> \(added)")
        return added == errSecSuccess ? made as? Data : nil
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
