import CloudKit
import Foundation

/// The cloud side of sync: iCloud's private database, through CloudKit.
/// It only ever moves records. Dart says what a record holds and whose
/// write wins; here a record is a uid, a kind, a moment, a JSON string of
/// columns and the pictures the columns name, and nothing is read into it.
///
/// Reached from Dart through `MethodChannelCloudTransport`, as `available`,
/// `pull` and `push`; `changed` goes the other way when a silent push says
/// another device has written.
final class CloudBridge {
  static let containerId = "iCloud.com.alkait.yesterdo"
  static let zoneName = "yesterdo"
  static let subscriptionId = "yesterdo-changes"

  /// The most records one operation may carry. The server allows 400.
  private static let batchSize = 200

  private let container = CKContainer(identifier: containerId)
  private var database: CKDatabase { container.privateCloudDatabase }
  private let zoneId = CKRecordZone.ID(zoneName: zoneName, ownerName: CKCurrentUserDefaultName)

  /// Whether the zone and the subscription are known to be in place. Kept
  /// across launches, so the server is not asked every time.
  private var ready: Bool {
    get { UserDefaults.standard.bool(forKey: "cloudReady") }
    set { UserDefaults.standard.set(newValue, forKey: "cloudReady") }
  }

  func available() async -> Bool {
    (try? await container.accountStatus()) == .available
  }

  /// Everything written or removed since [token], or since the beginning
  /// for nil, and the token to hand back next time. A token the server no
  /// longer knows starts again from the beginning. A zone gone from the
  /// server, as when the iCloud data was cleared, is made afresh and
  /// answered with `reset`, so Dart sends everything again.
  func pull(token: String?) async throws -> [String: Any] {
    try await prepare()
    var since = token.flatMap(CloudBridge.decodeToken)
    var changed: [[String: Any]] = []
    var deleted: [String] = []
    while true {
      let page: (
        modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
        deletions: [CKDatabase.RecordZoneChange.Deletion],
        changeToken: CKServerChangeToken,
        moreComing: Bool
      )
      do {
        page = try await database.recordZoneChanges(inZoneWith: zoneId, since: since)
      } catch let error as CKError where error.code == .changeTokenExpired {
        since = nil
        changed = []
        deleted = []
        continue
      } catch let error as CKError
        where error.code == .zoneNotFound || error.code == .userDeletedZone
      {
        ready = false
        try await prepare()
        return ["changed": [], "deleted": [], "reset": true]
      }
      for (_, result) in page.modificationResultsByID {
        if case .success(let modification) = result {
          changed.append(decode(modification.record))
        }
      }
      for deletion in page.deletions {
        deleted.append(deletion.recordID.recordName)
      }
      since = page.changeToken
      if !page.moreComing { break }
    }
    var answer: [String: Any] = ["changed": changed, "deleted": deleted]
    if let since { answer["token"] = CloudBridge.encodeToken(since) }
    return answer
  }

  /// Hands a batch up. The server's copy is overwritten whatever it holds:
  /// what was pulled just before has already been judged against it. A
  /// record already gone from the server is as good as deleted.
  func push(_ batch: [String: Any]) async throws {
    try await prepare()
    let records = ((batch["changed"] as? [[String: Any]]) ?? []).map(encode)
    let deletions = ((batch["deleted"] as? [String]) ?? []).map {
      CKRecord.ID(recordName: $0, zoneID: zoneId)
    }
    var saving = records[...]
    var deleting = deletions[...]
    while !saving.isEmpty || !deleting.isEmpty {
      let save = Array(saving.prefix(CloudBridge.batchSize))
      saving = saving.dropFirst(save.count)
      let delete = Array(deleting.prefix(CloudBridge.batchSize - save.count))
      deleting = deleting.dropFirst(delete.count)
      let outcome = try await database.modifyRecords(
        saving: save, deleting: delete, savePolicy: .allKeys, atomically: false)
      for (_, result) in outcome.saveResults {
        if case .failure(let error) = result { throw error }
      }
      for (_, result) in outcome.deleteResults {
        if case .failure(let error) = result,
          (error as? CKError)?.code != .unknownItem
        {
          throw error
        }
      }
    }
  }

  /// Makes the zone and the subscription that says when it changes, once.
  private func prepare() async throws {
    if ready { return }
    _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneId)], deleting: [])
    let subscription = CKDatabaseSubscription(subscriptionID: CloudBridge.subscriptionId)
    let info = CKSubscription.NotificationInfo()
    info.shouldSendContentAvailable = true
    subscription.notificationInfo = info
    _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
    ready = true
  }

  /// A record as Dart hands it over: columns as one JSON string, the
  /// pictures the columns name as assets beside it.
  private func encode(_ json: [String: Any]) -> CKRecord {
    let kind = json["kind"] as? String ?? "todo"
    let uid = json["uid"] as? String ?? ""
    let record = CKRecord(recordType: kind, recordID: CKRecord.ID(recordName: uid, zoneID: zoneId))
    record["kind"] = kind
    record["updatedAt"] = (json["updatedAt"] as? Int ?? 0) as NSNumber
    let fields = json["fields"] as? [String: Any] ?? [:]
    if let data = try? JSONSerialization.data(withJSONObject: fields),
      let text = String(data: data, encoding: .utf8)
    {
      record["data"] = text
    }
    var names: [String] = []
    var assets: [CKAsset] = []
    for name in (json["images"] as? [String]) ?? [] {
      let url = ImageBridge.directory.appendingPathComponent(name)
      guard FileManager.default.fileExists(atPath: url.path) else { continue }
      names.append(name)
      assets.append(CKAsset(fileURL: url))
    }
    // Left off when there are none: the Development schema is made from
    // the first record seen, and an empty list has no type to make it from.
    if !assets.isEmpty {
      record["imageNames"] = names
      record["images"] = assets
    }
    return record
  }

  /// A record as it came down, with its pictures put in the images folder
  /// under the names the columns use, so Dart only ever sees names.
  private func decode(_ record: CKRecord) -> [String: Any] {
    var fields: [String: Any] = [:]
    if let text = record["data"] as? String, let data = text.data(using: .utf8),
      let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    {
      fields = parsed
    }
    let names = record["imageNames"] as? [String] ?? []
    let assets = record["images"] as? [CKAsset] ?? []
    for (name, asset) in zip(names, assets) {
      guard let from = asset.fileURL else { continue }
      let to = ImageBridge.directory.appendingPathComponent(name)
      if !FileManager.default.fileExists(atPath: to.path) {
        try? FileManager.default.copyItem(at: from, to: to)
      }
    }
    return [
      "kind": record["kind"] as? String ?? record.recordType,
      "uid": record.recordID.recordName,
      "updatedAt": (record["updatedAt"] as? NSNumber)?.intValue ?? 0,
      "fields": fields,
    ]
  }

  private static func encodeToken(_ token: CKServerChangeToken) -> String? {
    (try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true))?
      .base64EncodedString()
  }

  private static func decodeToken(_ text: String) -> CKServerChangeToken? {
    guard let data = Data(base64Encoded: text) else { return nil }
    return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
  }
}
