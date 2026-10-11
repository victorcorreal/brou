import AppKit
import CloudKit
import Foundation
import os

// Bookmarks in iCloud, the same in Search on the Mac and on Victor's iPhone.
//
// Not in Office Commun's Search: added for this build. The schema is shared
// with the iPhone app and written down in Victor's SINCRONIZACION.md; change
// it there and in both apps at once.
//
// Each bookmark and each folder is one record in the zone "Search" of the
// private database of iCloud.cat.correal.search. CKSyncEngine keeps track of
// what has been sent and what has come in. The list itself stays what it was,
// bookmarks.json: this only compares it with what iCloud last agreed on.
// What differs goes up; what comes down is folded into the list.
//
// Nothing runs without the iCloud entitlement (a build without Victor's
// profile, `swift build`, the unit tests), and nothing runs in a test run
// unless SEARCH_SYNC_ZONE names a zone of its own.

@MainActor
final class CloudSync {
    static private(set) var shared: CloudSync?

    static let container = "iCloud.cat.correal.search"
    static let bookmarkType = "Bookmark"

    /// From Bookmarks.init: once, when the list has been read.
    static func start(_ bookmarks: Bookmarks) {
        guard shared == nil, let zone = zoneName, entitled else { return }
        shared = CloudSync(bookmarks, zone: zone)
    }

    /// The zone: "Search" for the browser somebody uses, and only the one a
    /// test run is given for a test run.
    private static var zoneName: String? {
        let asked = ProcessInfo.processInfo.environment["SEARCH_SYNC_ZONE"]
        if Store.testing { return asked.flatMap { $0.isEmpty ? nil : $0 } }
        return "Search"
    }

    /// Whether this build was signed with the container: CKContainer stops
    /// the app on the spot when it wasn't.
    private static var entitled: Bool {
        guard let task = SecTaskCreateFromSelf(nil),
              let value = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil),
              let containers = value as? [String]
        else { return false }
        return containers.contains(container)
    }

    private let log = Logger(subsystem: "cat.correal.search", category: "iCloud")
    private weak var bookmarks: Bookmarks?
    private let zoneID: CKRecordZone.ID
    private var engine: CKSyncEngine!
    private var saved: Saved
    private var clock: Timer?
    private var dropping = false

    /// What is kept between launches: the engine's own state, and each record
    /// as iCloud last agreed on it, with the system fields that let the next
    /// save of it be a change rather than a conflict.
    private struct Saved: Codable {
        var state: CKSyncEngine.State.Serialization?
        var agreed: [String: Agreed] = [:]
        /// The iCloud account the records were agreed with.
        var account: String?
    }

    private struct Agreed: Codable {
        var node: Flat
        var system: Data?
    }

    /// One bookmark or folder as a record holds it.
    struct Flat: Codable, Equatable {
        var title: String
        var url: String?
        var folder: Bool
        /// The folder it is in; empty at the top level.
        var parent: String
        /// Its place among the others in that folder, lowest first.
        var position: Double
    }

    private static var file: URL {
        let zone = zoneName ?? "none"
        return Store.file(zone == "Search" ? "icloud.json" : "icloud-\(zone).json")
    }

    private init(_ bookmarks: Bookmarks, zone: String) {
        self.bookmarks = bookmarks
        zoneID = CKRecordZone.ID(zoneName: zone, ownerName: CKCurrentUserDefaultName)
        saved = (try? Data(contentsOf: CloudSync.file)).flatMap { try? JSONDecoder().decode(Saved.self, from: $0) } ?? Saved()
        let database = CKContainer(identifier: CloudSync.container).privateCloudDatabase
        let first = saved.state == nil
        engine = CKSyncEngine(CKSyncEngine.Configuration(database: database, stateSerialization: saved.state, delegate: self))
        // A test run cleaning up after itself: its zone goes, and nothing else
        // happens (see Tests/cloud_sync.py).
        if Store.testing, ProcessInfo.processInfo.environment["SEARCH_SYNC_DROP"] != nil {
            dropping = true
            engine.state.add(pendingDatabaseChanges: [.deleteZone(zoneID)])
            Task { try? await engine.sendChanges() }
            return
        }
        if first {
            engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        }
        queueDifferences()
        // No push from iCloud without a push entitlement, and with a saved
        // state the engine doesn't ask by itself: it is asked now, every few
        // minutes, and whenever the app comes forward.
        fetch()
        clock = Timer.scheduledTimer(withTimeInterval: CloudSync.every, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetch() }
        }
        NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.fetch() }
        }
        note("started in zone \(zone): saved state \(saved.state != nil), \(saved.agreed.count) agreed, account \(saved.account ?? "none")")
    }

    private func fetch() {
        Task {
            do { try await engine.fetchChanges() } catch { note("fetch failed: \(error)") }
        }
    }

    /// How often iCloud is asked, in seconds: every five minutes, or what a
    /// test run is given in SEARCH_SYNC_POLL.
    private static var every: TimeInterval {
        if Store.testing, let asked = ProcessInfo.processInfo.environment["SEARCH_SYNC_POLL"].flatMap(TimeInterval.init) { return asked }
        return 5 * 60
    }

    /// A test run's diary of what the engine did, for Tests/cloud_sync.py.
    private func note(_ line: String) {
        log.info("\(line, privacy: .public)")
        guard Store.testing, let data = "\(Date()) \(line)\n".data(using: .utf8) else { return }
        let file = Store.file("icloud-events.log")
        if let handle = try? FileHandle(forWritingTo: file) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: file)
        }
    }

    // MARK: - the list, as records

    /// Every bookmark and folder by id, each with its folder and place.
    nonisolated static func flatten(_ nodes: [Bookmark], parent: String = "") -> [String: Flat] {
        var out: [String: Flat] = [:]
        for (index, node) in nodes.enumerated() {
            let id = node.id.uuidString
            out[id] = Flat(title: node.title, url: node.isFolder ? nil : node.url, folder: node.isFolder,
                           parent: parent, position: Double(index))
            if let kids = node.children {
                out.merge(flatten(kids, parent: id)) { kept, _ in kept }
            }
        }
        return out
    }

    /// The list back from records. A record whose folder is gone, or that
    /// came to sit inside itself through two moves made at once on two
    /// devices, goes to the top level rather than out of sight — out of
    /// sight, the next comparison would have taken it for deleted.
    nonisolated static func tree(_ flat: [String: Flat]) -> [Bookmark] {
        var flat = flat
        for (id, node) in flat where !node.parent.isEmpty && flat[node.parent]?.folder != true {
            flat[id]?.parent = ""
        }
        func build(_ parent: String, _ kids: [String: [String]], _ seen: inout Set<String>) -> [Bookmark] {
            let ids = (kids[parent] ?? []).sorted {
                let a = flat[$0]!, b = flat[$1]!
                return a.position != b.position ? a.position < b.position : $0 < $1
            }
            return ids.compactMap { id in
                guard let node = flat[id], let uuid = UUID(uuidString: id), seen.insert(id).inserted else { return nil }
                var made = Bookmark(id: uuid, title: node.title, url: node.folder ? nil : node.url, children: nil)
                if node.folder { made.children = build(id, kids, &seen) }
                return made
            }
        }
        while true {
            var kids: [String: [String]] = [:]
            for (id, node) in flat { kids[node.parent, default: []].append(id) }
            var seen = Set<String>()
            let roots = build("", kids, &seen)
            let lost = flat.keys.filter { !seen.contains($0) }
            guard let first = lost.first else { return roots }
            flat[first]?.parent = ""
        }
    }

    // MARK: - going up

    /// From Bookmarks.save, after every change to the list.
    func changed() {
        guard !dropping else { return }
        queueDifferences()
    }

    /// What differs from what iCloud last agreed on is queued to be sent.
    private func queueDifferences() {
        guard let bookmarks else { return }
        let now = CloudSync.flatten(bookmarks.roots)
        var changes: [CKSyncEngine.PendingRecordZoneChange] = []
        for (id, node) in now where saved.agreed[id]?.node != node {
            changes.append(.saveRecord(recordID(id)))
        }
        for id in saved.agreed.keys where now[id] == nil {
            changes.append(.deleteRecord(recordID(id)))
        }
        guard !changes.isEmpty else { return }
        engine.state.add(pendingRecordZoneChanges: changes)
    }

    private func recordID(_ id: String) -> CKRecord.ID {
        CKRecord.ID(recordName: id, zoneID: zoneID)
    }

    private func record(_ id: String, _ node: Flat) -> CKRecord {
        var record: CKRecord?
        if let data = saved.agreed[id]?.system, let coder = try? NSKeyedUnarchiver(forReadingFrom: data) {
            coder.requiresSecureCoding = true
            record = CKRecord(coder: coder)
            coder.finishDecoding()
        }
        let made = record ?? CKRecord(recordType: CloudSync.bookmarkType, recordID: recordID(id))
        made["title"] = node.title
        made["url"] = node.url
        made["folder"] = node.folder ? 1 : 0
        made["parent"] = node.parent
        made["position"] = node.position
        made["modified"] = Date()
        return made
    }

    nonisolated static func flat(from record: CKRecord) -> Flat {
        Flat(title: record["title"] as? String ?? "",
             url: record["url"] as? String,
             folder: (record["folder"] as? Int64 ?? 0) != 0,
             parent: record["parent"] as? String ?? "",
             position: record["position"] as? Double ?? 0)
    }

    nonisolated static func systemFields(_ record: CKRecord) -> Data {
        let coder = NSKeyedArchiver(requiringSecureCoding: true)
        record.encodeSystemFields(with: coder)
        coder.finishEncoding()
        return coder.encodedData
    }

    // MARK: - coming down

    /// Records from iCloud folded into the list. iCloud's version of a record
    /// wins over a local change to the same one not yet sent; every other
    /// local change stays.
    private func fold(_ records: [CKRecord], deleted: [String]) {
        guard let bookmarks, !(records.isEmpty && deleted.isEmpty) else { return }
        var flat = CloudSync.flatten(bookmarks.roots)
        for record in records where record.recordType == CloudSync.bookmarkType {
            let id = record.recordID.recordName
            let node = CloudSync.flat(from: record)
            flat[id] = node
            saved.agreed[id] = Agreed(node: node, system: CloudSync.systemFields(record))
        }
        for id in deleted {
            flat[id] = nil
            saved.agreed[id] = nil
        }
        // adopt saves, which brings us back to changed(): the places, renumbered
        // from 0 in each folder, go up again if they differ.
        bookmarks.adopt(CloudSync.tree(flat))
        keep()
    }

    private func keep() {
        let snapshot = saved
        Disk.write(CloudSync.file, now: true) { try? JSONEncoder().encode(snapshot) }
    }

    /// Everything local goes up again, from nothing agreed: a new account, or
    /// a zone that was deleted.
    private func startOver() {
        saved.agreed = [:]
        engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
        queueDifferences()
        keep()
    }
}

extension CloudSync: CKSyncEngineDelegate {
    func handleEvent(_ event: CKSyncEngine.Event, syncEngine: CKSyncEngine) async {
        if dropping {
            if case .sentDatabaseChanges(let sent) = event, sent.deletedZoneIDs.contains(zoneID) {
                try? Data().write(to: Store.file("icloud-dropped"))
            }
            return
        }
        note("event \(String(describing: event).prefix(300))")
        switch event {
        case .stateUpdate(let update):
            saved.state = update.stateSerialization
            keep()

        case .accountChange(let change):
            // The engine says "signed in" at launches too, not only when the
            // account is new: what was agreed only goes when the account is
            // another. Sending it all again from nothing agreed would write
            // this device's old copy over what the others changed.
            switch change.changeType {
            case .signIn(let user):
                if let known = saved.account, known != user.recordName { saved.agreed = [:] }
                saved.account = user.recordName
                engine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                queueDifferences()
                keep()
            case .switchAccounts(_, let user):
                saved.account = user.recordName
                startOver()
            case .signOut:
                // The list stays on the Mac; what was agreed with the old
                // account means nothing to the next one.
                saved.agreed = [:]
                saved.account = nil
                keep()
            @unknown default:
                break
            }

        case .fetchedDatabaseChanges(let changes):
            if changes.deletions.contains(where: { $0.zoneID == zoneID }) { startOver() }

        case .fetchedRecordZoneChanges(let changes):
            fold(changes.modifications.map(\.record),
                 deleted: changes.deletions.filter { $0.recordType == CloudSync.bookmarkType }.map(\.recordID.recordName))

        case .sentRecordZoneChanges(let sent):
            for record in sent.savedRecords where record.recordType == CloudSync.bookmarkType {
                saved.agreed[record.recordID.recordName] = Agreed(node: CloudSync.flat(from: record), system: CloudSync.systemFields(record))
            }
            for id in sent.deletedRecordIDs { saved.agreed[id.recordName] = nil }
            var theirs: [CKRecord] = []
            for failure in sent.failedRecordSaves {
                let id = failure.record.recordID
                switch failure.error.code {
                case .serverRecordChanged:
                    if let server = failure.error.serverRecord { theirs.append(server) }
                case .zoneNotFound:
                    syncEngine.state.add(pendingDatabaseChanges: [.saveZone(CKRecordZone(zoneID: zoneID))])
                    saved.agreed[id.recordName]?.system = nil
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                case .unknownItem:
                    saved.agreed[id.recordName]?.system = nil
                    syncEngine.state.add(pendingRecordZoneChanges: [.saveRecord(id)])
                case .networkFailure, .networkUnavailable, .zoneBusy, .serviceUnavailable,
                     .notAuthenticated, .operationCancelled, .requestRateLimited:
                    break
                default:
                    log.error("iCloud could not save \(id.recordName, privacy: .public): \(failure.error.localizedDescription, privacy: .public)")
                }
            }
            fold(theirs, deleted: [])
            // Changes made while this batch was on its way.
            queueDifferences()
            keep()

        case .sentDatabaseChanges, .willFetchChanges, .willFetchRecordZoneChanges, .didFetchRecordZoneChanges,
             .didFetchChanges, .willSendChanges, .didSendChanges:
            break

        @unknown default:
            break
        }
    }

    func nextRecordZoneChangeBatch(_ context: CKSyncEngine.SendChangesContext, syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch? {
        let pending = syncEngine.state.pendingRecordZoneChanges.filter { context.options.scope.contains($0) }
        let now = bookmarks.map { CloudSync.flatten($0.roots) } ?? [:]
        // The records are made here, on the main actor; the batch asks for
        // them from wherever it runs.
        var records: [CKRecord.ID: CKRecord] = [:]
        var gone: [CKSyncEngine.PendingRecordZoneChange] = []
        for change in pending {
            guard case .saveRecord(let id) = change else { continue }
            if let node = now[id.recordName] {
                records[id] = record(id.recordName, node)
            } else {
                // Gone since it was queued: nothing to send.
                gone.append(change)
            }
        }
        if !gone.isEmpty { syncEngine.state.remove(pendingRecordZoneChanges: gone) }
        let ready = records
        return await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: pending.filter { !gone.contains($0) }) { ready[$0] }
    }
}
