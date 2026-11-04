import Foundation
import Observation

/// A JSON file on disk mirrored into memory, saved shortly after edits
/// and reloaded when the file changes outside the app (e.g. a dotfiles pull).
@MainActor
@Observable
final class JSONDocument<Value: Codable & Equatable> {
    var value: Value {
        didSet {
            guard value != oldValue, !isApplyingDiskChange else { return }
            onChange?(value)
            scheduleSave()
        }
    }

    /// Set when the file on disk could not be read.
    private(set) var loadError: String?

    @ObservationIgnored let fileURL: URL
    @ObservationIgnored var onChange: ((Value) -> Void)?
    @ObservationIgnored private let initialValue: Value
    @ObservationIgnored private var lastDiskData: Data?
    @ObservationIgnored private var isApplyingDiskChange = false
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    init(fileURL: URL, initialValue: Value) {
        self.fileURL = fileURL
        self.initialValue = initialValue
        self.value = initialValue
    }

    /// Loads the file, creating it with the initial value when missing.
    func load() {
        guard JSONFile.read(fileURL) != nil else {
            save()
            return
        }
        reloadIfChanged()
    }

    func reloadIfChanged() {
        guard let data = JSONFile.read(fileURL), data != lastDiskData else { return }
        lastDiskData = data
        do {
            let decoded = try JSONFile.decoder.decode(Value.self, from: data)
            loadError = nil
            guard decoded != value else { return }
            isApplyingDiskChange = true
            value = decoded
            isApplyingDiskChange = false
            onChange?(value)
        } catch {
            loadError = "\(fileURL.lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            save()
        }
    }

    private func save() {
        do {
            let data = try JSONFile.encoder.encode(value)
            try JSONFile.write(data, to: fileURL)
            lastDiskData = data
            loadError = nil
        } catch {
            loadError = "Could not save \(fileURL.lastPathComponent): \(error.localizedDescription)"
        }
    }
}
