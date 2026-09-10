import Foundation

/// 「読み」と「選んだ言葉」の組ごとに、何回選んだかを記録する（設計書 4章）
public struct LearningStore: Codable, Equatable {
    public struct Entry: Codable, Equatable {
        public var count: Int
        public var lastUsed: Date
    }

    /// この回数以上選んだ言葉を先頭に出す
    public static let threshold = 3
    /// 覚えておく組の最大数
    public static let capacity = 5000

    public private(set) var entries: [String: Entry] = [:]

    public init() {}

    private static func key(_ reading: String, _ text: String) -> String {
        reading + "\t" + text
    }

    public mutating func record(reading: String, text: String, at date: Date) {
        let key = Self.key(reading, text)
        var entry = entries[key] ?? Entry(count: 0, lastUsed: date)
        entry.count += 1
        entry.lastUsed = date
        entries[key] = entry
        if entries.count > Self.capacity,
           let oldest = entries.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key {
            entries.removeValue(forKey: oldest)
        }
    }

    /// threshold 回以上選んだ言葉。回数の多い順、同じ回数なら最近使った順。
    public func learnedTexts(for reading: String) -> [String] {
        let prefix = reading + "\t"
        return entries
            .filter { $0.key.hasPrefix(prefix) && $0.value.count >= Self.threshold }
            .sorted { ($0.value.count, $0.value.lastUsed) > ($1.value.count, $1.value.lastUsed) }
            .map { String($0.key.dropFirst(prefix.count)) }
    }

    public func count(reading: String, text: String) -> Int {
        entries[Self.key(reading, text)]?.count ?? 0
    }

    public mutating func reset() {
        entries.removeAll()
    }

    public func save(to url: URL) throws {
        let data = try JSONEncoder().encode(self)
        try data.write(to: url, options: .atomic)
    }

    /// 保存したファイルを読む。ファイルがない・壊れているときは空で始める。
    public static func load(from url: URL) -> LearningStore {
        guard let data = try? Data(contentsOf: url),
              let store = try? JSONDecoder().decode(LearningStore.self, from: data) else {
            return LearningStore()
        }
        return store
    }
}
