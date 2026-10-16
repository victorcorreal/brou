import Foundation
import Security
import LocalAuthentication

// Where passwords live: the macOS keychain, under this app's own name, as
// internet passwords keyed by site and account. Nothing is written to disk by
// this app in any other form, and nothing is ever logged.
//
// This is the same coffer Safari's are in, but not the same drawer: Apple keeps
// Safari's behind an entitlement no other browser gets. So these are Office
// Browser's — in the system's vault, unlocked with the Mac, shown with Touch ID.

struct Login: Identifiable, Equatable, Hashable {
    var host: String
    var user: String
    var password: String
    /// When it was last used to sign in, if known. Newest first in lists.
    var used: Date?
    /// Kept from a page sent in the clear, over plain http. Only these are
    /// offered on such a page: one kept from https, or from before this was
    /// written down, is never handed to a page anyone on the way could have
    /// written.
    var clear = false
    /// Which keychain item it is. Nil for one a page has just sent and that
    /// isn't kept yet.
    var ref: Vault.Ref?

    var id: String { ref?.id ?? host + "\u{1}" + user }
}

/// One item as a list needs it: the site, the account, and when it was last
/// used, without the secret. Reading a secret is one keychain call, and the
/// list asks for one only when a password is shown or copied: a drawer of four
/// hundred kept passwords would otherwise be four hundred calls before the
/// panel could draw itself. Nothing that writes a password or fills one into a
/// page takes this type, so a row cannot be handed on as though it held one.
struct Kept: Identifiable, Equatable, Hashable {
    var host: String
    var user: String
    /// When it was last used to sign in, if known. Newest first in lists.
    var used: Date?
    /// Kept from a page sent in the clear, over plain http. See `Login`.
    var clear = false
    /// When it went into the keychain. With `used` and `clear`, what tells
    /// two items with the same site and account apart in the list.
    var saved: Date?
    var ref: Vault.Ref?

    var id: String { ref?.id ?? host + "\u{1}" + user }
}

enum Vault {
    /// What every item of ours is tagged with. A test run tags its own, so a
    /// password saved while trying something never sits among the real ones.
    private static let label = Store.world.map { "Search (\($0))" } ?? "Search"

    /// The keychain's own name for one item, and which keychain it is in.
    /// Two items can share a site and an account — one kept over http and
    /// one over https, say, each saved on a different device before iCloud
    /// brought the other across — and only this tells them apart. Reading a
    /// secret, noting a use and taking one away go by it: by site and
    /// account, taking one away took both, and noting a use wrote one
    /// password over the other.
    struct Ref: Hashable {
        let data: Data
        /// In the login keychain, where Search kept passwords before the
        /// shared group (see VaultCloud). A reference from one keychain is
        /// never handed to the other: the login keychain goes by the
        /// reference alone, whatever else the query says.
        var old = false

        var id: String { (old ? "old:" : "") + data.base64EncodedString() }
    }

    // MARK: - reading

    /// The keychain will list many items, or hand over one secret — not
    /// both in one call. Asked for every item's data at once it answers
    /// errSecParam, and it did so quietly enough that for a while this app
    /// saved passwords it could never read back. So: the list first, without
    /// secrets, then each secret on its own.

    /// What is kept for a host, exactly. See `logins(matching:)` for the
    /// version that also looks across a site's subdomains.
    static func logins(for host: String) -> [Login] {
        rows(where: [kSecAttrServer as String: host]).compactMap(login(from:))
    }

    /// The keychain matches a server name exactly, and a sign-in rarely lives
    /// on the page you saved it from — accounts.example.com asks, and the
    /// password was kept for example.com. So the site is matched as a site:
    /// the host first, then anything sharing its registrable domain.
    static func logins(matching host: String) -> [Login] {
        let domain = registrable(host)
        let exact = logins(for: host)
        let wider = rows(where: [:])
            .filter { ($0[kSecAttrServer as String] as? String).map { $0 != host && registrable($0) == domain } ?? false }
            .compactMap(login(from:))
        return (exact + wider).sorted { ($0.used ?? .distantPast) > ($1.used ?? .distantPast) }
    }

    /// Everything this app holds, as the list needs it: no secrets. Each one
    /// is `secret(of:)`, a call of its own, and only when it is asked for.
    /// Read on demand and never kept in a property.
    static func all() -> [Kept] {
        rows(where: [:]).compactMap(kept(from:)).sorted(by: listed)
    }

    /// By site, then account; the same account twice, the one used last
    /// first.
    static func listed(_ a: Kept, _ b: Kept) -> Bool {
        if a.host != b.host { return a.host < b.host }
        if a.user != b.user { return a.user < b.user }
        return (a.used ?? .distantPast) > (b.used ?? .distantPast)
    }

    /// The items' attributes — no secrets — narrowed by whatever is given.
    private static func rows(where extra: [String: Any]) -> [[String: Any]] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrLabel as String: label,
            kSecReturnAttributes as String: true,
            kSecReturnPersistentRef as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll,
        ]
        extra.forEach { query[$0] = $1 }
        var out: CFTypeRef?
        let status = VaultCloud.copyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let rows = out as? [[String: Any]] else {
            // Nothing kept reads as "not found"; anything else is worth a
            // line in the log, because the panel will only say "nothing".
            if status != errSecItemNotFound { NSLog("Vault: keychain list failed (%d)", status) }
            return []
        }
        return rows
    }

    /// One item's secret, by the two things that name it: for an item the
    /// keychain listed without its reference.
    private static func secret(host: String, user: String) -> String? {
        var out: CFTypeRef?
        let status = VaultCloud.copyMatching([
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrLabel as String: label,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: user,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &out)
        guard status == errSecSuccess, let data = out as? Data else {
            if status != errSecItemNotFound { NSLog("Vault: keychain read failed (%d)", status) }
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// One item's secret, by its reference. One from the login keychain is
    /// copied to the shared group as it is read (see VaultCloud), and the
    /// reference that comes back is then the copy's.
    private static func secret(_ ref: Ref) -> (password: String, ref: Ref)? {
        var query = named(ref)
        query[kSecReturnData as String] = true
        query[kSecReturnPersistentRef as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var out: CFTypeRef?
        let status = VaultCloud.copyMatching(query as CFDictionary, &out)
        guard status == errSecSuccess, let item = out as? [String: Any],
              let data = item[kSecValueData as String] as? Data,
              let password = String(data: data, encoding: .utf8)
        else {
            if status != errSecItemNotFound, status != errSecSuccess { NSLog("Vault: keychain read failed (%d)", status) }
            return nil
        }
        return (password, self.ref(of: item) ?? ref)
    }

    /// One item's secret, where a list holds only the item: read when a
    /// password is shown or copied, and never as part of a list.
    static func secret(of kept: Kept) -> String? {
        guard let ref = kept.ref else { return secret(host: kept.host, user: kept.user) }
        return secret(ref)?.password
    }

    /// The query for one item, by its reference, for the keychain it is in.
    /// The label keeps it to ours wherever the keychain takes it beside a
    /// reference (see VaultCloud).
    private static func named(_ ref: Ref) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrLabel as String: label,
            kSecValuePersistentRef as String: ref.data,
        ]
        if ref.old { query[VaultCloud.old] = true }
        return query
    }

    /// The reference a row came with, and which keychain it is in.
    private static func ref(of row: [String: Any]) -> Ref? {
        (row[kSecValuePersistentRef as String] as? Data).map { Ref(data: $0, old: row[VaultCloud.old] != nil) }
    }

    /// What an item's attributes say beyond its name: when it was last used,
    /// and whether it was kept from a page sent in the clear.
    private static func noted(_ row: [String: Any]) -> (used: Date?, clear: Bool) {
        // The keychain has no "last used" of its own; it rides in the comment.
        let used = (row[kSecAttrComment as String] as? String)
            .flatMap(Double.init).map(Date.init(timeIntervalSince1970:))
        let clear = (row[kSecAttrProtocol as String] as? String) == (kSecAttrProtocolHTTP as String)
        return (used, clear)
    }

    /// One item with its secret, for the paths that hand a password over:
    /// filling a sign-in in, and telling whether one is already kept.
    private static func login(from row: [String: Any]) -> Login? {
        let user = account(of: row)
        guard let host = row[kSecAttrServer as String] as? String else { return nil }
        let (used, clear) = noted(row)
        guard let ref = ref(of: row) else {
            return secret(host: host, user: user).map { Login(host: host, user: user, password: $0, used: used, clear: clear) }
        }
        guard let (password, now) = secret(ref) else { return nil }
        return Login(host: host, user: user, password: password, used: used, clear: clear, ref: now)
    }

    /// The account an item is kept under. A sign-in with a password box
    /// alone — an access code, a dashboard's — is kept under no name, and
    /// the keychain lists such an item with no account at all, not an
    /// empty one: read as missing, it was saved and never offered again,
    /// nor shown in Settings, nor forgotten.
    private static func account(of row: [String: Any]) -> String {
        row[kSecAttrAccount as String] as? String ?? ""
    }

    /// One item without its secret, for the list.
    private static func kept(from row: [String: Any]) -> Kept? {
        guard let host = row[kSecAttrServer as String] as? String else { return nil }
        let user = account(of: row)
        let (used, clear) = noted(row)
        return Kept(host: host, user: user, used: used, clear: clear,
                    saved: row[kSecAttrCreationDate as String] as? Date, ref: ref(of: row))
    }

    // MARK: - writing

    @discardableResult
    static func save(host: String, user: String, password: String, used: Date? = nil, clear: Bool = false) -> Bool {
        guard !host.isEmpty, !password.isEmpty,
              let data = password.data(using: .utf8)
        else { return false }

        // Ours only. Server and account alone also match what other apps
        // keep for the same site — git's token for github.com under your
        // username — and an update would write this password over it.
        let identity: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: user,
            kSecAttrLabel as String: label,
        ]
        // A web form's, which also keeps ours apart from another app's item
        // in the keychain's eyes: one for the same server, account and
        // protocol — git's — makes adding ours fail as a duplicate.
        var fields: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrLabel as String: label,
            kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeHTMLForm,
            kSecAttrProtocol as String: clear ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS,
        ]
        if let used { fields[kSecAttrComment as String] = String(used.timeIntervalSince1970) }

        // The one kept over the same protocol first. With two for this
        // account, one over http and one over https, writing to both would
        // make them the same item twice, which the keychain refuses.
        var same = identity
        same[kSecAttrProtocol as String] = fields[kSecAttrProtocol as String]
        var status = VaultCloud.update(same as CFDictionary, fields as CFDictionary)
        if status == errSecItemNotFound { status = VaultCloud.update(identity as CFDictionary, fields as CFDictionary) }
        if status == errSecSuccess { return true }
        guard status == errSecItemNotFound else { return false }

        var fresh = identity.merging(fields) { _, new in new }
        fresh[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked
        return VaultCloud.add(fresh as CFDictionary, nil) == errSecSuccess
    }

    /// It was just used to sign in. Lists put it first from now on. Noted
    /// on this one item: by site and account it would also write this
    /// password over a second item that shares them.
    static func touch(_ login: Login) {
        guard let ref = login.ref else {
            save(host: login.host, user: login.user, password: login.password, used: Date(), clear: login.clear)
            return
        }
        // The login keychain is never written to. An old item has been
        // copied across by the time it is used (see `secret(_:)`); one whose
        // copy could not be made is left as it is.
        guard !ref.old else { return }
        var fields: [String: Any] = [
            kSecAttrComment as String: String(Date().timeIntervalSince1970),
            // Where it was last used is where it is offered from now on…
            kSecAttrProtocol as String: login.clear ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS,
        ]
        // …unless the same account is also kept over that protocol: the two
        // would become the same item twice. Then only the use is noted.
        if VaultCloud.update(named(ref) as CFDictionary, fields as CFDictionary) == errSecDuplicateItem {
            fields[kSecAttrProtocol as String] = nil
            _ = VaultCloud.update(named(ref) as CFDictionary, fields as CFDictionary)
        }
    }

    /// Takes away this one item, and only this one: a second item with the
    /// same site and account stays. What VaultCloud does about the copies
    /// standing behind it, in the shared group or the login keychain, is
    /// said there.
    static func forget(_ kept: Kept) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: kept.host,
            kSecAttrAccount as String: kept.user,
            kSecAttrLabel as String: label,
        ]
        if let ref = kept.ref { query.merge(named(ref)) { _, new in new } }
        VaultCloud.delete(query as CFDictionary)
    }

    /// A new item, beside any already kept for the same site and account:
    /// what the iPhone app makes when it saves one before iCloud has brought
    /// the Mac's across. Only a test run makes one this way, to have two
    /// that share a site and an account.
    @discardableResult
    static func plant(host: String, user: String, password: String, clear: Bool) -> Bool {
        guard Store.testing, let data = password.data(using: .utf8) else { return false }
        return VaultCloud.add([
            kSecClass as String: kSecClassInternetPassword,
            kSecAttrServer as String: host,
            kSecAttrAccount as String: user,
            kSecAttrLabel as String: label,
            kSecValueData as String: data,
            kSecAttrAuthenticationType as String: kSecAttrAuthenticationTypeHTMLForm,
            kSecAttrProtocol as String: clear ? kSecAttrProtocolHTTP : kSecAttrProtocolHTTPS,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ] as CFDictionary, nil) == errSecSuccess
    }

    // MARK: - sites that asked not to be asked

    private static let neverKey = "passwords.never"

    static var never: Set<String> {
        get { Set(Store.settings.stringArray(forKey: neverKey) ?? []) }
        set { Store.settings.set(Array(newValue).sorted(), forKey: neverKey) }
    }

    static func never(_ host: String) { never.insert(host) }
    static func isNever(_ host: String) -> Bool { never.contains(host) || never.contains(registrable(host)) }

    // MARK: - showing one

    /// A password is shown only to the person the Mac belongs to. Touch ID,
    /// the watch, or the account password — whatever the Mac itself takes.
    static func prove(_ reason: String, _ done: @escaping (Bool) -> Void) {
        let context = LAContext()
        var trouble: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &trouble) else {
            // No way to ask at all — a Mac with no password set. Then there is
            // nothing to prove.
            done(true)
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { ok, _ in
            DispatchQueue.main.async { done(ok) }
        }
    }

    // MARK: - the site behind a host

    /// example.com for www.example.com and accounts.example.com; bbc.co.uk
    /// stays bbc.co.uk.
    static func registrable(_ host: String) -> String {
        Registrable.domain(of: host, isSuffix: Passkeys.publicSuffix.map { test in { test($0 as CFString) } })
    }

    static func host(of text: String) -> String {
        var value = text.trimmingCharacters(in: .whitespaces)
        if !value.contains("://") { value = "https://" + value }
        // A website's, and nothing else: an Android app's login in an export
        // (android://…@com.vendor.app/) names a package, which can read as a
        // domain somebody else owns — com.vendor.app, .shopping… — and would
        // be offered to them.
        guard let url = URL(string: value), ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              let host = url.host()?.lowercased()
        else { return "" }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    // MARK: - taking in an export

    /// A CSV as Google Password Manager, Chrome or Dia write it: name, url,
    /// username, password, note. Read once, put in the keychain, and the file
    /// is yours to delete — this never keeps a copy of it.
    static func take(csv text: String) -> (kept: Int, skipped: Int) {
        var rows = parse(csv: text)
        guard !rows.isEmpty else { return (0, 0) }

        let header = rows.removeFirst().map { $0.lowercased() }
        func column(_ names: [String]) -> Int? {
            header.firstIndex { names.contains($0) }
        }
        guard let urlAt = column(["url", "login_uri", "website", "site"]),
              let userAt = column(["username", "login_username", "user", "email"]),
              let passAt = column(["password", "login_password"])
        else { return (0, rows.count) }

        var kept = 0, skipped = 0
        for row in rows {
            guard row.count > max(urlAt, max(userAt, passAt)) else {
                skipped += 1
                continue
            }
            let host = self.host(of: row[urlAt])
            let password = row[passAt]
            guard !host.isEmpty, !password.isEmpty else {
                skipped += 1
                continue
            }
            let clear = row[urlAt].trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("http://")
            save(host: host, user: row[userAt], password: password, clear: clear) ? (kept += 1) : (skipped += 1)
        }
        return (kept, skipped)
    }

    /// Called on the import worker. Parsing finishes before any keychain
    /// writes; cancellation between writes preserves an exact partial count.
    static func take(csv text: String, control: ImportFile.Control) -> (kept: Int, skipped: Int) {
        guard !control.isCancelled else { return (0, 0) }
        control.report(.init(message: "Reading password CSV…", completed: 0))
        var rows = parse(csv: text, control: control)
        guard !rows.isEmpty, !control.isCancelled else { return (0, 0) }
        let header = rows.removeFirst().map { $0.lowercased() }
        func column(_ names: [String]) -> Int? { header.firstIndex { names.contains($0) } }
        guard let urlAt = column(["url", "login_uri", "website", "site"]),
              let userAt = column(["username", "login_username", "user", "email"]),
              let passAt = column(["password", "login_password"])
        else { return (0, rows.count) }
        var kept = 0, skipped = 0
        control.report(.init(message: "Saving passwords…", completed: 0, total: rows.count))
        for (index, row) in rows.enumerated() {
            if control.isCancelled { break }
            defer {
                if (index + 1) % 25 == 0 || index + 1 == rows.count {
                    control.report(.init(message: "Saving passwords…", completed: index + 1, total: rows.count))
                }
            }
            guard row.count > max(urlAt, max(userAt, passAt)) else { skipped += 1; continue }
            let host = self.host(of: row[urlAt])
            let password = row[passAt]
            guard !host.isEmpty, !password.isEmpty else { skipped += 1; continue }
            let clear = row[urlAt].trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("http://")
            save(host: host, user: row[userAt], password: password, clear: clear) ? (kept += 1) : (skipped += 1)
        }
        return (kept, skipped)
    }

    /// Quoted fields, doubled quotes inside them, and newlines inside those —
    /// all three turn up in a real export.
    private static func parse(csv text: String, control: ImportFile.Control? = nil) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var quoted = false
        var index = text.startIndex
        var scanned = 0

        while index < text.endIndex {
            scanned += 1
            if scanned % 8192 == 0, let control {
                if control.isCancelled { return [] }
                control.report(.init(message: "Reading password CSV…", completed: scanned))
            }
            let c = text[index]
            if quoted {
                if c == "\"" {
                    let next = text.index(after: index)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        index = next
                    } else {
                        quoted = false
                    }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": quoted = true
                case ",": row.append(field); field = ""
                case "\n", "\r\n", "\r":
                    row.append(field)
                    field = ""
                    if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
                    row = []
                default: field.append(c)
                }
            }
            index = text.index(after: index)
        }
        row.append(field)
        if row.contains(where: { !$0.isEmpty }) { rows.append(row) }
        if let control {
            if control.isCancelled { return [] }
            control.report(.init(message: "Reading password CSV…", completed: scanned))
        }
        return rows
    }
}
