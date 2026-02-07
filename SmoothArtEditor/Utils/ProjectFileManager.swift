import Foundation

enum ProjectFileManager {
    static var projectsDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("SmoothArtProjects", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    struct ProjectInfo: Identifiable {
        let id = UUID()
        let name: String
        let url: URL
        let date: Date
    }

    static func save(data: ProjectData, name: String) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let jsonData = try encoder.encode(data)

        let fileName = name.replacingOccurrences(of: "/", with: "-") + ".sart"
        let url = projectsDirectory.appendingPathComponent(fileName)
        try jsonData.write(to: url)
        return url
    }

    static func load(url: URL) throws -> ProjectData {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode(ProjectData.self, from: data)
    }

    static func listProjects() -> [ProjectInfo] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: projectsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "sart" }
            .compactMap { url -> ProjectInfo? in
                let name = url.deletingPathExtension().lastPathComponent
                let date = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
                return ProjectInfo(name: name, url: url, date: date)
            }
            .sorted { $0.date > $1.date }
    }

    static func deleteProject(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
