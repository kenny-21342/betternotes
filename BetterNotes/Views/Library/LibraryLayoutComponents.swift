import SwiftData
import SwiftUI

/// How the library lists notebooks. Stored per device.
enum LibraryLayout: String, CaseIterable {
    case grid, list

    var label: String { self == .grid ? AppLocalization.text("Grid") : AppLocalization.text("List") }
    var icon: String { self == .grid ? "square.grid.2x2" : "list.bullet" }
}

/// A checkmark badge shown on a notebook while the library is selecting.
struct LibrarySelectionBadge: View {
    let isSelected: Bool

    var body: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .symbolRenderingMode(.palette)
            .foregroundStyle(isSelected ? Color.white : Color.secondary, isSelected ? Color.accentColor : Color.clear)
            .background(Circle().fill(.background.opacity(0.85)).padding(2))
            .accessibilityHidden(true)
    }
}

/// One notebook as a compact row: thumbnail, title, and the details that the
/// grid cover spreads over a tall card.
struct NotebookListRow: View {
    let notebook: Notebook
    var isSelecting = false
    var isSelected = false

    private var pageCount: Int { notebook.pages.filter { $0.trashedAt == nil }.count }

    var body: some View {
        HStack(spacing: 14) {
            if isSelecting { LibrarySelectionBadge(isSelected: isSelected) }
            ZStack {
                LinearGradient(colors: [notebook.coverColor, notebook.coverColor2],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                if let emoji = notebook.coverEmoji, !emoji.isEmpty { Text(emoji).font(.title3) }
            }
            .frame(width: 42, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 3, y: 2)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if notebook.isFavorite { Image(systemName: "star.fill").foregroundStyle(.orange).font(.caption) }
                    Text(notebook.title).font(.headline).lineLimit(1)
                }
                HStack(spacing: 6) {
                    Text(notebook.modifiedAt, format: .dateTime.month().day().year())
                    Text("·")
                    Text("Pages: \(pageCount)")
                    if !notebook.folderName.isEmpty {
                        Text("·")
                        Label(notebook.folderName, systemImage: "folder").labelStyle(.titleAndIcon).lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 72)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemGroupedBackground)))
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(notebook.title)
        .accessibilityValue("\(pageCount) pages")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Moves every selected notebook to one folder, or creates a folder for them.
struct MoveNotebooksSheet: View {
    let notebookIDs: [UUID]
    let existingFolders: [String]
    var onMoved: () -> Void
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var newFolder = ""
    @State private var parentFolder = ""
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Move To") {
                    Button("Notes", systemImage: "books.vertical") { apply("") }
                    ForEach(existingFolders, id: \.self) { folder in
                        Button(folder, systemImage: "folder") { apply(folder) }
                    }
                }
                Section("New Folder") {
                    Picker("Parent Folder", selection: $parentFolder) {
                        Text("Top Level").tag("")
                        ForEach(existingFolders, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Folder name", text: $newFolder)
                    Button("Create and Move", action: createAndMove)
                        .disabled(newFolder.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .navigationTitle("Move \(notebookIDs.count) Notebooks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
            .alert("Couldn’t Move Notebooks", isPresented: Binding(get: { saveError != nil },
                                                                   set: { if !$0 { saveError = nil } })) {
                Button("OK", role: .cancel) { saveError = nil }
            } message: { Text(saveError ?? "") }
        }
    }

    private func apply(_ folder: String) {
        do {
            _ = try NotebookFolders.move(notebookIDs: notebookIDs, to: folder, in: context)
            NotificationCenter.default.post(name: .noteCorpusDidChange, object: nil)
            onMoved()
            dismiss()
        } catch { saveError = error.localizedDescription }
    }

    private func createAndMove() {
        do {
            let folder = try NotebookFolders.create(newFolder, in: context, parentPath: parentFolder)
            apply(folder.path)
        } catch { saveError = error.localizedDescription }
    }
}
