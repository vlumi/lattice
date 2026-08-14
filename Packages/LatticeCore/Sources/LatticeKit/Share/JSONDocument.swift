import SwiftUI
import UniformTypeIdentifiers

/// Write-only JSON wrapper for `.fileExporter` — the data export (see
/// `DataExport`). Mirrors PNGDocument, which does the same for share cards.
struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
