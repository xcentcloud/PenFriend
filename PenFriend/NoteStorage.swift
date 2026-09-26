import Foundation
import PencilKit

enum NoteStorageLocation {
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

struct NoteStorageSnapshot {
    let pages: [NotePage]
    let location: NoteStorageLocation
    let didMigrateFromLocalStorage: Bool
    let shouldCreateInitialFile: Bool
}

private struct StoredNotebook: Codable {
    var pages: [StoredNotePage]

    static let empty = StoredNotebook(pages: [StoredNotePage()])
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

actor NoteStorage {
    private let fileManager: FileManager
    private let notebookFileName = "Notebook.json"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func loadSnapshot() throws -> NoteStorageSnapshot {
        let iCloudURL = try makeICloudNotebookURL()
        let localURL = try makeLocalNotebookURL()

        if let iCloudURL, fileManager.fileExists(atPath: iCloudURL.path) {
            return NoteStorageSnapshot(
                pages: try loadPages(from: iCloudURL),
                location: .iCloud,
                didMigrateFromLocalStorage: false,
                shouldCreateInitialFile: false
            )
        }

        if fileManager.fileExists(atPath: localURL.path) {
            let pages = try loadPages(from: localURL)
            if let iCloudURL {
                try write(pages: pages, to: iCloudURL)
                return NoteStorageSnapshot(
                    pages: pages,
                    location: .iCloud,
                    didMigrateFromLocalStorage: true,
                    shouldCreateInitialFile: false
                )
            }
            return NoteStorageSnapshot(
                pages: pages,
                location: .local,
                didMigrateFromLocalStorage: false,
                shouldCreateInitialFile: false
            )
        }

        return NoteStorageSnapshot(
            pages: [NotePage()],
            location: iCloudURL == nil ? .local : .iCloud,
            didMigrateFromLocalStorage: false,
            shouldCreateInitialFile: true
        )
    }

    func savePages(_ pages: [NotePage]) throws -> NoteStorageLocation {
        let pagesToPersist = pages.isEmpty ? [NotePage()] : pages

        if let iCloudURL = try makeICloudNotebookURL() {
            do {
                try write(pages: pagesToPersist, to: iCloudURL)
                return .iCloud
            } catch {
                let localURL = try makeLocalNotebookURL()
                try write(pages: pagesToPersist, to: localURL)
                return .local
            }
        }

        let localURL = try makeLocalNotebookURL()
        try write(pages: pagesToPersist, to: localURL)
        return .local
    }

    private func loadPages(from fileURL: URL) throws -> [NotePage] {
        let data = try Data(contentsOf: fileURL)
        let notebook = try JSONDecoder().decode(StoredNotebook.self, from: data)
        let pages = notebook.pages.map { page in
            NotePage(id: page.id, drawing: (try? PKDrawing(data: page.drawingData)) ?? PKDrawing())
        }
        return pages.isEmpty ? [NotePage()] : pages
    }

    private func write(pages: [NotePage], to fileURL: URL) throws {
        let notebook = StoredNotebook(
            pages: pages.map { page in
                StoredNotePage(id: page.id, drawingData: page.drawing.dataRepresentation())
            }
        )
        let data = try JSONEncoder().encode(notebook)
        try data.write(to: fileURL, options: [.atomic])
    }

    private func makeICloudNotebookURL() throws -> URL? {
        guard let containerURL = fileManager.url(forUbiquityContainerIdentifier: nil) else {
            return nil
        }

        let documentsURL = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Notes", isDirectory: true)
        try fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        return documentsURL.appendingPathComponent(notebookFileName)
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
}
