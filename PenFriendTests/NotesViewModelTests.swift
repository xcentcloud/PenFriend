import XCTest
import PencilKit
@testable import PenFriend

@MainActor
final class NotesViewModelTests: XCTestCase {
    func testAddNewPageUpdatesSelectionAndLabel() {
        let storage = MockNoteStorage()
        let viewModel = NotesViewModel(noteStorage: storage)

        viewModel.addNewPage()

        XCTAssertEqual(viewModel.pages.count, 2)
        XCTAssertEqual(viewModel.selectedPageIndex, 1)
        XCTAssertEqual(viewModel.pageLabel, "Page 2 of 2")
    }

    func testNavigationRespectsPageBounds() {
        let storage = MockNoteStorage()
        let viewModel = NotesViewModel(noteStorage: storage)
        viewModel.addNewPage()
        viewModel.addNewPage()

        viewModel.selectedPageIndex = 0
        viewModel.goToPreviousPage()
        XCTAssertEqual(viewModel.selectedPageIndex, 0)

        viewModel.goToNextPage()
        XCTAssertEqual(viewModel.selectedPageIndex, 1)

        viewModel.goToNextPage()
        XCTAssertEqual(viewModel.selectedPageIndex, 2)

        viewModel.goToNextPage()
        XCTAssertEqual(viewModel.selectedPageIndex, 2)
    }

    func testRestoreIfNeededLoadsSnapshotOnlyOnce() async {
        let storage = MockNoteStorage(snapshot: NoteStorageSnapshot(
            pages: [NotePage(), NotePage()],
            location: .iCloud,
            didMigrateFromLocalStorage: false,
            shouldCreateInitialFile: false
        ))
        let viewModel = NotesViewModel(noteStorage: storage)

        await viewModel.restoreIfNeeded()
        await viewModel.restoreIfNeeded()

        let loadCount = await storage.loadSnapshotCallCount
        XCTAssertEqual(loadCount, 1)
        XCTAssertEqual(viewModel.pages.count, 2)
        XCTAssertTrue(isICloud(viewModel.storageLocation))
        XCTAssertEqual(viewModel.storageStatus, NoteStorageLocation.iCloud.statusMessage)
    }

    func testRestoreIfNeededShowsMigrationStatusWhenLocalNotesMoved() async {
        let storage = MockNoteStorage(snapshot: NoteStorageSnapshot(
            pages: [NotePage()],
            location: .iCloud,
            didMigrateFromLocalStorage: true,
            shouldCreateInitialFile: true
        ))
        let viewModel = NotesViewModel(noteStorage: storage)

        await viewModel.restoreIfNeeded()

        XCTAssertTrue(isICloud(viewModel.storageLocation))
        XCTAssertEqual(viewModel.storageStatus, "Moved existing notes into iCloud.")
    }

    private func isICloud(_ location: NoteStorageLocation) -> Bool {
        if case .iCloud = location { return true }
        return false
    }
}

private actor MockNoteStorage: NoteStorageControlling {
    private(set) var loadSnapshotCallCount = 0
    private let snapshot: NoteStorageSnapshot

    init(snapshot: NoteStorageSnapshot = NoteStorageSnapshot(
        pages: [NotePage()],
        location: .local,
        didMigrateFromLocalStorage: false,
        shouldCreateInitialFile: false
    )) {
        self.snapshot = snapshot
    }

    func loadSnapshot() async throws -> NoteStorageSnapshot {
        loadSnapshotCallCount += 1
        return snapshot
    }

    func loadLocalSnapshot() async throws -> NoteStorageSnapshot {
        snapshot
    }

    func savePages(_ pages: [NotePage]) async throws -> NoteStorageLocation {
        snapshot.location
    }

    func ensureLocalFallbackNotebookExists() async throws {}
}
