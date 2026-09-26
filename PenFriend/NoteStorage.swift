import Foundation
import PencilKit

enum NoteStorageLocation: Sendable {
    case iCloud
    case local

    var statusMessage: String {
        switch self {
        case .iCloud:
            return "Notes sync with iCloud."
        case .local:
            return "iCloud unavailable. Notes stay on this device."
        }
    }
}

struct NoteStorageSnapshot: Sendable {
    let pages: [NotePage]
    let location: NoteStorageLocation
    let didMigrateFromLocalStorage: Bool
    let shouldCreateInitialFile: Bool
}

protocol NoteStorageControlling: Sendable {
    func loadSnapshot() async throws -> NoteStorageSnapshot
    func loadLocalSnapshot() async throws -> NoteStorageSnapshot
    func savePages(_ pages: [NotePage]) async throws -> NoteStorageLocation
    func ensureLocalFallbackNotebookExists() async throws
}

private struct StoredNotebook: Codable {
    var revision: UInt64
    var pages: [StoredNotePage]

    init(revision: UInt64 = 0, pages: [StoredNotePage]) {
        self.revision = revision
        self.pages = pages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        revision = try container.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        pages = try container.decode([StoredNotePage].self, forKey: .pages)
    }
}

private struct StoredNotePage: Codable {
    var id: UUID
    var drawingData: Data

    init(id: UUID = UUID(), drawingData: Data = PKDrawing().dataRepresentation()) {
        self.id = id
        self.drawingData = drawingData
    }
}

enum NoteStorageError: LocalizedError {
    case missingAppSupportDirectory

    var errorDescription: String? {
        switch self {
        case .missingAppSupportDirectory:
            return "Application Support is unavailable."
        }
    }
}

actor NoteStorage: NoteStorageControlling {
    private let fileManager: FileManager
    private let notebookFileName = "Notebook.json"
    private let localFallbackMarkerFileName = "PendingLocalFallback.marker"
    private let ubiquityContainerIdentifier: String?
    private var cachedICloudNotebookURL: URL?

    init(
        fileManager: FileManager = .default,
        ubiquityContainerIdentifier: String? = Bundle.main.bundleIdentifier.map { "iCloud.\($0)" }
    ) {
        self.fileManager = fileManager
        self.ubiquityContainerIdentifier = ubiquityContainerIdentifier
    }

    func loadSnapshot() async throws -> NoteStorageSnapshot {
        let iCloudURL = try makeICloudNotebookURL()
        let localURL = try makeLocalNotebookURL()
        let localNotebook = try fileManager.fileExists(atPath: localURL.path) ? loadNotebook(from: localURL) : nil
        let iCloudNotebook: StoredNotebook?
        do {
            iCloudNotebook = try iCloudURL.flatMap { url in
                fileManager.fileExists(atPath: url.path) ? loadNotebook(from: url) : nil
            }
        } catch {
            cachedICloudNotebookURL = nil
            if let localNotebook {
                return NoteStorageSnapshot(
                    pages: try makePages(from: localNotebook),
                    location: .local,
                    didMigrateFromLocalStorage: false,
                    shouldCreateInitialFile: false
                )
            }
            throw error
        }
        let hasPendingLocalFallback = try hasPendingLocalFallback()

        if let iCloudURL, let localNotebook, hasPendingLocalFallback {
            try write(notebook: localNotebook, to: iCloudURL)
            try write(notebook: localNotebook, to: localURL)
            try clearPendingLocalFallback()
            return NoteStorageSnapshot(
                pages: try makePages(from: localNotebook),
                location: .iCloud,
                didMigrateFromLocalStorage: true,
                shouldCreateInitialFile: false
            )
        }

        if let iCloudURL, let iCloudNotebook, let localNotebook {
            if localNotebook.revision > iCloudNotebook.revision {
                try write(notebook: localNotebook, to: iCloudURL)
                try write(notebook: localNotebook, to: localURL)
                try clearPendingLocalFallback()
                return NoteStorageSnapshot(
                    pages: try makePages(from: localNotebook),
                    location: .iCloud,
                    didMigrateFromLocalStorage: true,
                    shouldCreateInitialFile: false
                )
            }

            try write(notebook: iCloudNotebook, to: localURL)
            try clearPendingLocalFallback()
            return NoteStorageSnapshot(
                pages: try makePages(from: iCloudNotebook),
                location: .iCloud,
                didMigrateFromLocalStorage: false,
                shouldCreateInitialFile: false
            )
        }

        if let iCloudNotebook {
            try write(notebook: iCloudNotebook, to: localURL)
            try clearPendingLocalFallback()
            return NoteStorageSnapshot(
                pages: try makePages(from: iCloudNotebook),
                location: .iCloud,
                didMigrateFromLocalStorage: false,
                shouldCreateInitialFile: false
            )
        }

        if let localNotebook {
            if let iCloudURL {
                try write(notebook: localNotebook, to: iCloudURL)
                try write(notebook: localNotebook, to: localURL)
                try clearPendingLocalFallback()
                return NoteStorageSnapshot(
                    pages: try makePages(from: localNotebook),
                    location: .iCloud,
                    didMigrateFromLocalStorage: true,
                    shouldCreateInitialFile: false
                )
            }

            return NoteStorageSnapshot(
                pages: try makePages(from: localNotebook),
                location: .local,
                didMigrateFromLocalStorage: false,
                shouldCreateInitialFile: false
            )
        }

        let emptyNotebook = StoredNotebook(revision: 1, pages: [StoredNotePage()])
        if let iCloudURL {
            do {
                try write(notebook: emptyNotebook, to: iCloudURL)
                try write(notebook: emptyNotebook, to: localURL)
                try clearPendingLocalFallback()
                return NoteStorageSnapshot(
                    pages: try makePages(from: emptyNotebook),
                    location: .iCloud,
                    didMigrateFromLocalStorage: false,
                    shouldCreateInitialFile: false
                )
            } catch {
                cachedICloudNotebookURL = nil
            }
        }

        try write(notebook: emptyNotebook, to: localURL)
        return NoteStorageSnapshot(
            pages: try makePages(from: emptyNotebook),
            location: .local,
            didMigrateFromLocalStorage: false,
            shouldCreateInitialFile: false
        )
    }

    func loadLocalSnapshot() async throws -> NoteStorageSnapshot {
        let localURL = try makeLocalNotebookURL()
        let notebook: StoredNotebook
        if fileManager.fileExists(atPath: localURL.path) {
            notebook = try loadNotebook(from: localURL)
        } else {
            notebook = StoredNotebook(revision: 1, pages: [StoredNotePage()])
            try write(notebook: notebook, to: localURL)
        }

        return NoteStorageSnapshot(
            pages: try makePages(from: notebook),
            location: .local,
            didMigrateFromLocalStorage: false,
            shouldCreateInitialFile: false
        )
    }

    func savePages(_ pages: [NotePage]) async throws -> NoteStorageLocation {
        let pagesToPersist = pages.isEmpty ? [NotePage()] : pages
        let localURL = try makeLocalNotebookURL()
        let iCloudURL = try makeICloudNotebookURL()
        let notebook = StoredNotebook(
            revision: try nextRevision(localURL: localURL, iCloudURL: iCloudURL),
            pages: pagesToPersist.map { page in
                StoredNotePage(id: page.id, drawingData: page.drawing.dataRepresentation())
            }
        )

        if let iCloudURL {
            do {
                try write(notebook: notebook, to: iCloudURL)
                try write(notebook: notebook, to: localURL)
                try clearPendingLocalFallback()
                return .iCloud
            } catch {
                cachedICloudNotebookURL = nil
                try write(notebook: notebook, to: localURL)
                try markPendingLocalFallback()
                return .local
            }
        }

        try write(notebook: notebook, to: localURL)
        return .local
    }

    func ensureLocalFallbackNotebookExists() async throws {
        let localURL = try makeLocalNotebookURL()
        guard !fileManager.fileExists(atPath: localURL.path) else {
            return
        }
        try write(notebook: StoredNotebook(pages: [StoredNotePage()]), to: localURL)
    }

    private func loadNotebook(from fileURL: URL) throws -> StoredNotebook {
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(StoredNotebook.self, from: data)
    }

    private func makePages(from notebook: StoredNotebook) throws -> [NotePage] {
        let pages = try notebook.pages.map { page in
            try NotePage(id: page.id, drawing: PKDrawing(data: page.drawingData))
        }
        return pages.isEmpty ? [NotePage()] : pages
    }

    private func write(notebook: StoredNotebook, to fileURL: URL) throws {
        let data = try JSONEncoder().encode(notebook)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func nextRevision(localURL: URL, iCloudURL: URL?) throws -> UInt64 {
        let localRevision = try existingRevision(at: localURL)
        let iCloudRevision = try existingRevision(at: iCloudURL)
        return max(localRevision, iCloudRevision) + 1
    }

    private func existingRevision(at fileURL: URL?) throws -> UInt64 {
        guard let fileURL, fileManager.fileExists(atPath: fileURL.path) else {
            return 0
        }
        return (try? loadNotebook(from: fileURL).revision) ?? 0
    }

    private func makeICloudNotebookURL() throws -> URL? {
        if let cachedICloudNotebookURL {
            return cachedICloudNotebookURL
        }

        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: ubiquityContainerIdentifier) else {
            return nil
        }

        let documentsURL = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let notebookURL = documentsURL.appendingPathComponent(notebookFileName)
        cachedICloudNotebookURL = notebookURL
        return notebookURL
    }

    private func makeLocalNotebookURL() throws -> URL {
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw NoteStorageError.missingAppSupportDirectory
        }

        let notesURL = appSupportURL
            .appendingPathComponent("PenFriend", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
        try fileManager.createDirectory(at: notesURL, withIntermediateDirectories: true)
        return notesURL.appendingPathComponent(notebookFileName)
    }

    private func markerURL() throws -> URL {
        try makeLocalNotebookURL()
            .deletingLastPathComponent()
            .appendingPathComponent(localFallbackMarkerFileName)
    }

    private func hasPendingLocalFallback() throws -> Bool {
        let markerURL = try markerURL()
        return fileManager.fileExists(atPath: markerURL.path)
    }

    private func markPendingLocalFallback() throws {
        let markerURL = try markerURL()
        try Data().write(to: markerURL, options: [.atomic])
    }

    private func clearPendingLocalFallback() throws {
        let markerURL = try markerURL()
        guard fileManager.fileExists(atPath: markerURL.path) else { return }
        try fileManager.removeItem(at: markerURL)
    }
}
