import Foundation

struct ProjectFileManager {
    static let fileExtension = "pxl"

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func save(data: ProjectData, name: String) throws -> URL {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        let sanitized = name.replacingOccurrences(of: "/", with: "-")
        let url = documentsDirectory.appendingPathComponent("\(sanitized).\(fileExtension)")
        try jsonData.write(to: url, options: .atomic)
        return url
    }

    static func load(url: URL) throws -> ProjectData {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ProjectData.self, from: data)
    }

    struct ProjectInfo: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let date: Date
    }

    static func listProjects() -> [ProjectInfo] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: documentsDirectory,
                                                       includingPropertiesForKeys: [.contentModificationDateKey],
                                                       options: .skipsHiddenFiles) else {
            return []
        }
        return files
            .filter { $0.pathExtension == fileExtension }
            .compactMap { url -> ProjectInfo? in
                let attrs = try? fm.attributesOfItem(atPath: url.path)
                let date = attrs?[.modificationDate] as? Date ?? Date.distantPast
                let name = url.deletingPathExtension().lastPathComponent
                return ProjectInfo(name: name, url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    static func deleteProject(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
