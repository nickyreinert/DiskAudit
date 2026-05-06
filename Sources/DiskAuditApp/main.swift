import SwiftUI
import AppKit

struct ScanLocation: Identifiable, Hashable {
    let id: UUID
    let title: String
    let url: URL
    var isEnabled: Bool

    init(title: String, url: URL, isEnabled: Bool) {
        self.id = UUID()
        self.title = title
        self.url = url
        self.isEnabled = isEnabled
    }
}

enum ScanCategory: String, CaseIterable, Hashable, Identifiable {
    case tempFiles = "Temporary"
    case caches = "Caches"
    case partials = "Partials"
    case virtualEnvs = "Virtual Environments"
    case nodePackages = "Node Packages"
    case images = "Images"
    case videos = "Videos"
    case archives = "Archives"
    case documents = "Documents"
    case logs = "Logs"
    case applications = "Applications"
    case others = "Others"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .tempFiles: return Color(red: 0.89, green: 0.44, blue: 0.20)
        case .caches: return Color(red: 0.82, green: 0.58, blue: 0.14)
        case .partials: return Color(red: 0.85, green: 0.36, blue: 0.17)
        case .virtualEnvs: return Color(red: 0.35, green: 0.54, blue: 0.93)
        case .nodePackages: return Color(red: 0.16, green: 0.69, blue: 0.31)
        case .images: return Color(red: 0.11, green: 0.67, blue: 0.78)
        case .videos: return Color(red: 0.60, green: 0.35, blue: 0.87)
        case .archives: return Color(red: 0.50, green: 0.50, blue: 0.57)
        case .documents: return Color(red: 0.21, green: 0.47, blue: 0.92)
        case .logs: return Color(red: 0.86, green: 0.29, blue: 0.32)
        case .applications: return Color(red: 0.08, green: 0.60, blue: 0.66)
        case .others: return Color(red: 0.35, green: 0.36, blue: 0.41)
        }
    }

    var explanation: String {
        switch self {
        case .tempFiles:
            return "Temporary files are often leftovers. Zero-byte and old tmp files are usually safe cleanup candidates."
        case .caches:
            return "Caches speed up apps but can grow large. Apps usually recreate them."
        case .partials:
            return "Partial files come from interrupted downloads/transfers and are often disposable."
        case .virtualEnvs:
            return "Virtual environment folders contain project dependencies. Remove only if project is inactive."
        case .nodePackages:
            return "node_modules is commonly reinstallable and a top cleanup candidate for development machines."
        case .images:
            return "Image files can accumulate quickly; prefer archive or deduplication over blind deletion."
        case .videos:
            return "Videos are large and often important. Archive old content before deleting."
        case .archives:
            return "Archives may duplicate already extracted data and are common cleanup opportunities."
        case .documents:
            return "Documents may be important; review business/personal relevance before deletion."
        case .logs:
            return "Log files are often safe to rotate or delete when old, especially in cache/tmp trees."
        case .applications:
            return "Applications can be huge; remove only unused apps."
        case .others:
            return "Unclassified item. Review path and usage manually."
        }
    }
}

enum RiskLevel: String, CaseIterable, Hashable, Identifiable {
    case safe = "safe"
    case review = "review"
    case caution = "caution"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .safe: return "SAFE"
        case .review: return "REVIEW"
        case .caution: return "CAUTION"
        }
    }

    var color: Color {
        switch self {
        case .safe: return Color(red: 0.20, green: 0.68, blue: 0.34)
        case .review: return Color(red: 0.84, green: 0.57, blue: 0.12)
        case .caution: return Color(red: 0.86, green: 0.22, blue: 0.25)
        }
    }

    var hint: String {
        switch self {
        case .safe:
            return "Usually safe to remove after a quick path sanity check."
        case .review:
            return "Potentially useful. Confirm project/app relevance first."
        case .caution:
            return "Likely user-critical data or apps. Delete only with high confidence."
        }
    }
}

enum AuditItemKind: String {
    case file
    case folder
}

struct AuditItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let sizeBytes: Int64
    let kind: AuditItemKind
    let category: ScanCategory
    let garbageReason: String?
    let risk: RiskLevel

    var displayName: String {
        let name = url.lastPathComponent
        return name.isEmpty ? url.path : name
    }

    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

enum TreemapViewMode: String, CaseIterable, Identifiable {
    case files = "Huge Files"
    case folders = "Huge Folders"
    case tree = "Folder Tree"

    var id: String { rawValue }
}

enum ViewCategoryFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case hugeOnly = "Huge Only"
    case garbageOnly = "Garbage Only"

    var id: String { rawValue }
}

struct CleanupJournalEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let deletedCount: Int
    let freedBytes: Int64

    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: freedBytes, countStyle: .file)
    }
}

@MainActor
final class ScanViewModel: ObservableObject {
    @Published var minSizeMB: Int = 200
    @Published var isScanning = false
    @Published var progressValue: Double = 0
    @Published var progressLabel = "Ready"
    @Published var scannedCount: Int = 0

    @Published var files: [AuditItem] = []
    @Published var folders: [AuditItem] = []
    @Published var selectedCategories: Set<ScanCategory> = Set(ScanCategory.allCases)
    @Published var selectedRisks: Set<RiskLevel> = Set(RiskLevel.allCases)
    @Published var viewMode: TreemapViewMode = .files
    @Published var viewCategoryFilter: ViewCategoryFilter = .all

    @Published var includeSystemGarbageScan = true
    @Published var includeFullDiskGarbageDeepScan = false

    @Published var scanLocations: [ScanLocation] = []
    @Published var deleteQueue: [AuditItem] = []
    @Published var cleanupJournal: [CleanupJournalEntry] = []
    @Published var statusMessage: String = ""
    @Published var hoveredItem: AuditItem?
    @Published var treeRoots: [PathTreeNode] = []
    @Published var lastScanTimestamp: Date?

    private var scanTask: Task<Void, Never>?

    init() {
        scanLocations = Self.defaultLocations()
        loadJournal()
        loadScanResults()
    }

    func clearScanResults() {
        files = []
        folders = []
        treeRoots = []
        lastScanTimestamp = nil
        hoveredItem = nil
        statusMessage = "Scan results cleared."
        deleteScanResultsFile()
    }

    func startScan() {
        guard !isScanning else { return }

        let heavyRoots = scanLocations.filter { $0.isEnabled }.map { $0.url }
        guard !heavyRoots.isEmpty else {
            statusMessage = "Please enable at least one scan location in Settings."
            return
        }

        let garbageRoots = resolvedGarbageRoots()
        let allRoots = deduplicateRoots(heavyRoots + garbageRoots)

        isScanning = true
        progressValue = 0
        progressLabel = "Preparing scan..."
        scannedCount = 0
        statusMessage = ""
        files = []
        folders = []
        hoveredItem = nil

        let thresholdBytes = Int64(max(1, minSizeMB)) * 1024 * 1024

        scanTask = Task(priority: .userInitiated) {
            let allFiles = self.collectAllRegularFiles(in: allRoots)
            let total = max(1, allFiles.count)

            var heavyOrGarbageFiles: [AuditItem] = []
            var folderAccumulator: [String: Int64] = [:]
            var folderGarbageCount: [String: Int] = [:]

            for (index, fileURL) in allFiles.enumerated() {
                if Task.isCancelled { break }

                guard let size = self.fileSize(for: fileURL) else { continue }

                let path = fileURL.path
                let cat = self.classify(path: path, isFolder: false)
                let garbageReason = self.garbageReason(path: path, size: size)
                let insideHeavyRoot = heavyRoots.contains { path.hasPrefix($0.path) }
                let insideGarbageRoot = garbageRoots.contains { path.hasPrefix($0.path) }

                let includeHeavy = insideHeavyRoot && size >= thresholdBytes
                let includeGarbage = garbageReason != nil && insideGarbageRoot

                if includeHeavy || includeGarbage {
                    let risk = self.riskLevel(category: cat, garbageReason: garbageReason, isFolder: false)
                    heavyOrGarbageFiles.append(
                        AuditItem(
                            url: fileURL,
                            sizeBytes: size,
                            kind: .file,
                            category: cat,
                            garbageReason: garbageReason,
                            risk: risk
                        )
                    )

                    self.accumulateAncestors(of: fileURL, size: size, roots: allRoots, store: &folderAccumulator)

                    if garbageReason != nil {
                        self.accumulateGarbageAncestors(of: fileURL, roots: allRoots, store: &folderGarbageCount)
                    }
                }

                if index % 120 == 0 || index == total - 1 {
                    let progress = Double(index + 1) / Double(total)
                    await MainActor.run {
                        self.scannedCount = index + 1
                        self.progressValue = progress
                        self.progressLabel = "Scanning files: \(index + 1) of \(total)"
                    }
                }
            }

            var folderItems: [AuditItem] = []
            for (path, size) in folderAccumulator {
                let garbageHits = folderGarbageCount[path, default: 0]
                if size >= thresholdBytes || garbageHits >= 20 {
                    let folderURL = URL(fileURLWithPath: path, isDirectory: true)
                    let cat = self.classify(path: path, isFolder: true)
                    let reason = garbageHits >= 20 ? "Contains \(garbageHits) garbage-candidate files" : nil
                    let risk = self.riskLevel(category: cat, garbageReason: reason, isFolder: true)
                    folderItems.append(
                        AuditItem(
                            url: folderURL,
                            sizeBytes: size,
                            kind: .folder,
                            category: cat,
                            garbageReason: reason,
                            risk: risk
                        )
                    )
                }
            }

            heavyOrGarbageFiles.sort { $0.sizeBytes > $1.sizeBytes }
            folderItems.sort { $0.sizeBytes > $1.sizeBytes }

            await MainActor.run {
                self.files = Array(heavyOrGarbageFiles.prefix(1200))
                self.folders = Array(folderItems.prefix(1200))
                self.treeRoots = PathTreeBuilder.buildTree(from: self.files + self.folders)
                self.lastScanTimestamp = Date()
                self.isScanning = false
                self.progressValue = 1
                self.progressLabel = "Finished"
                self.statusMessage = "Scan finished. Found \(self.files.count) file candidates and \(self.folders.count) folder candidates."
                self.saveScanResults()
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        progressLabel = "Cancelled"
    }

    func openInFinder(_ item: AuditItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func toggleAllFilters() {
        if selectedCategories.count == ScanCategory.allCases.count {
            selectedCategories.removeAll()
        } else {
            selectedCategories = Set(ScanCategory.allCases)
        }
    }

    func toggleAllRiskFilters() {
        if selectedRisks.count == RiskLevel.allCases.count {
            selectedRisks.removeAll()
        } else {
            selectedRisks = Set(RiskLevel.allCases)
        }
    }

    func toggleLocation(_ location: ScanLocation) {
        guard let idx = scanLocations.firstIndex(where: { $0.id == location.id }) else { return }
        scanLocations[idx].isEnabled.toggle()
    }

    func setAllLocations(enabled: Bool) {
        for index in scanLocations.indices {
            scanLocations[index].isEnabled = enabled
        }
    }

    func queue(_ item: AuditItem) {
        if deleteQueue.contains(where: { $0.url.path == item.url.path }) {
            return
        }
        deleteQueue.append(item)
    }

    func unqueue(_ item: AuditItem) {
        deleteQueue.removeAll { $0.url.path == item.url.path }
    }

    func isQueued(_ item: AuditItem) -> Bool {
        deleteQueue.contains(where: { $0.url.path == item.url.path })
    }

    var deleteQueueFreedEstimate: Int64 {
        normalizedDeleteTargets().reduce(0) { $0 + $1.sizeBytes }
    }

    func rmCommandsPreview() -> String {
        let targets = normalizedDeleteTargets()
        if targets.isEmpty {
            return "# No queued items"
        }
        return targets.map { "rm -rf -- \(shellQuote($0.url.path))" }.joined(separator: "\n")
    }

    func exportDeleteQueueScript() {
        let scriptBody = rmCommandsPreview()
        if scriptBody == "# No queued items" {
            statusMessage = "Delete queue is empty. Nothing to export."
            return
        }

        let savePanel = NSSavePanel()
        savePanel.canCreateDirectories = true
        savePanel.nameFieldStringValue = "disk-audit-delete-queue.sh"
        savePanel.allowedContentTypes = []

        let response = savePanel.runModal()
        guard response == .OK, let outputURL = savePanel.url else {
            return
        }

        let content = "#!/usr/bin/env bash\nset -euo pipefail\n\n" + scriptBody + "\n"
        do {
            try content.write(to: outputURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: outputURL.path)
            statusMessage = "Exported delete script to \(outputURL.path)"
        } catch {
            statusMessage = "Failed to export script: \(error.localizedDescription)"
        }
    }

    func executeDeleteQueue() {
        let targets = normalizedDeleteTargets()
        guard !targets.isEmpty else {
            statusMessage = "Delete queue is empty."
            return
        }

        let allowedRoot = NSHomeDirectory()
        var deletedCount = 0
        var deletedBytes: Int64 = 0

        for item in targets {
            let path = item.url.path
            guard path.hasPrefix(allowedRoot + "/") || path == allowedRoot else {
                continue
            }
            do {
                if FileManager.default.fileExists(atPath: path) {
                    try FileManager.default.removeItem(at: item.url)
                    deletedCount += 1
                    deletedBytes += item.sizeBytes
                }
            } catch {
                continue
            }
        }

        if deletedCount > 0 {
            logCleanup(bytes: deletedBytes, count: deletedCount)
            removeDeletedFromCurrentView(deletedPaths: targets.map { $0.url.path })
            statusMessage = "Deleted \(deletedCount) items, freed \(ByteCountFormatter.string(fromByteCount: deletedBytes, countStyle: .file))."
        } else {
            statusMessage = "No queued items were deleted."
        }
    }

    var filteredItems: [AuditItem] {
        let source = viewMode == .files ? files : folders
        guard !selectedCategories.isEmpty, !selectedRisks.isEmpty else { return [] }
        return source.filter { item in
            let riskPass = selectedRisks.contains(item.risk)
            let categoryPass = selectedCategories.contains(item.category)
            let scopePass = matchesViewCategoryFilter(item)
            return riskPass && categoryPass && scopePass
        }
    }

    var fileCategorySizePreview: [ScanCategory: Int64] {
        var totals: [ScanCategory: Int64] = [:]
        let source = files.filter { selectedRisks.contains($0.risk) && matchesViewCategoryFilter($0) }
        for item in source {
            totals[item.category, default: 0] += item.sizeBytes
        }
        return totals
    }

    var folderCategorySizePreview: [ScanCategory: Int64] {
        var totals: [ScanCategory: Int64] = [:]
        let source = folders.filter { selectedRisks.contains($0.risk) && matchesViewCategoryFilter($0) }
        for item in source {
            totals[item.category, default: 0] += item.sizeBytes
        }
        return totals
    }

    func selectOnlyCategory(_ category: ScanCategory) {
        selectedCategories = [category]
    }

    func selectAllCategories() {
        selectedCategories = Set(ScanCategory.allCases)
    }

    private func matchesViewCategoryFilter(_ item: AuditItem) -> Bool {
        switch viewCategoryFilter {
        case .all:
            return true
        case .hugeOnly:
            return item.sizeBytes >= Int64(max(1, minSizeMB)) * 1024 * 1024
        case .garbageOnly:
            return item.garbageReason != nil
        }
    }

    var summaryLine: String {
        let source = viewMode == .files ? files : folders
        let filtered = filteredItems
        let totalBytes = filtered.reduce(Int64(0)) { $0 + $1.sizeBytes }
        let totalReadable = ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        return "Showing \(filtered.count) of \(source.count) items, total \(totalReadable)"
    }

    private static func defaultLocations() -> [ScanLocation] {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return [
            ScanLocation(title: "Home", url: home, isEnabled: true),
            ScanLocation(title: "Desktop", url: home.appendingPathComponent("Desktop", isDirectory: true), isEnabled: true),
            ScanLocation(title: "Documents", url: home.appendingPathComponent("Documents", isDirectory: true), isEnabled: true),
            ScanLocation(title: "Downloads", url: home.appendingPathComponent("Downloads", isDirectory: true), isEnabled: true),
            ScanLocation(title: "Pictures", url: home.appendingPathComponent("Pictures", isDirectory: true), isEnabled: false),
            ScanLocation(title: "Movies", url: home.appendingPathComponent("Movies", isDirectory: true), isEnabled: false),
            ScanLocation(title: "Library/Caches", url: home.appendingPathComponent("Library/Caches", isDirectory: true), isEnabled: true),
            ScanLocation(title: "Applications", url: URL(fileURLWithPath: "/Applications", isDirectory: true), isEnabled: false)
        ]
    }

    private func resolvedGarbageRoots() -> [URL] {
        if includeFullDiskGarbageDeepScan {
            return [URL(fileURLWithPath: "/System/Volumes/Data", isDirectory: true)]
        }

        guard includeSystemGarbageScan else {
            return scanLocations.filter { $0.isEnabled }.map { $0.url }
        }

        return deduplicateRoots([
            URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true),
            URL(fileURLWithPath: "/private/var/tmp", isDirectory: true),
            URL(fileURLWithPath: "/private/var/log", isDirectory: true),
            URL(fileURLWithPath: "/Library/Caches", isDirectory: true),
            URL(fileURLWithPath: "/Library/Logs", isDirectory: true),
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/private/var/tmp", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/private/var/log", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/Library/Caches", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/Library/Logs", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/Users", isDirectory: true),
            URL(fileURLWithPath: "/System/Volumes/Data/Applications", isDirectory: true)
        ])
    }

    private func deduplicateRoots(_ roots: [URL]) -> [URL] {
        var seen = Set<String>()
        return roots.filter { url in
            let p = url.path
            if seen.contains(p) { return false }
            seen.insert(p)
            return FileManager.default.fileExists(atPath: p)
        }
    }

    private func collectAllRegularFiles(in roots: [URL]) -> [URL] {
        var result: [URL] = []
        var seen = Set<String>()
        let keys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]

        for root in roots {
            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                if Task.isCancelled { break }
                let path = fileURL.path
                if seen.contains(path) {
                    continue
                }

                do {
                    let values = try fileURL.resourceValues(forKeys: Set(keys))
                    if values.isSymbolicLink == true { continue }
                    if values.isRegularFile == true {
                        seen.insert(path)
                        result.append(fileURL)
                    }
                } catch {
                    continue
                }
            }
        }

        return result
    }

    private func fileSize(for url: URL) -> Int64? {
        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
            if let n = attrs[.size] as? NSNumber {
                return n.int64Value
            }
        } catch {
            return nil
        }
        return nil
    }

    private func accumulateAncestors(of fileURL: URL, size: Int64, roots: [URL], store: inout [String: Int64]) {
        var current = fileURL.deletingLastPathComponent()
        var depth = 0

        while depth < 12 {
            let path = current.path
            let isInsideRoot = roots.contains(where: { path.hasPrefix($0.path) })
            if !isInsideRoot || path == "/" {
                break
            }
            store[path, default: 0] += size
            depth += 1
            current.deleteLastPathComponent()
        }
    }

    private func accumulateGarbageAncestors(of fileURL: URL, roots: [URL], store: inout [String: Int]) {
        var current = fileURL.deletingLastPathComponent()
        var depth = 0

        while depth < 12 {
            let path = current.path
            let isInsideRoot = roots.contains(where: { path.hasPrefix($0.path) })
            if !isInsideRoot || path == "/" {
                break
            }
            store[path, default: 0] += 1
            depth += 1
            current.deleteLastPathComponent()
        }
    }

    private func classify(path: String, isFolder: Bool) -> ScanCategory {
        let lower = path.lowercased()
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()

        if lower.contains("/node_modules/") || lower.hasSuffix("/node_modules") { return .nodePackages }
        if lower.contains("/.venv/") || lower.hasSuffix("/.venv") || lower.contains("/venv/") || lower.hasSuffix("/venv") || lower.contains("/env/") || lower.hasSuffix("/env") { return .virtualEnvs }
        if lower.contains("/library/caches/") || lower.contains("/caches/") || lower.hasSuffix("cache") || lower.hasSuffix("caches") { return .caches }
        if ext == "part" || ext == "partial" || ext == "crdownload" { return .partials }
        if ext == "tmp" || ext == "temp" || lower.contains("/tmp/") || lower.contains("/private/var/tmp/") { return .tempFiles }
        if ["jpg", "jpeg", "png", "gif", "webp", "heic", "tif", "tiff", "bmp", "svg"].contains(ext) { return .images }
        if ["mp4", "mov", "mkv", "avi", "webm", "m4v"].contains(ext) { return .videos }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso"].contains(ext) { return .archives }
        if ["log", "out"].contains(ext) || lower.contains("/logs/") { return .logs }
        if ["pdf", "doc", "docx", "txt", "rtf", "xls", "xlsx", "ppt", "pptx", "md", "pages", "numbers", "key"].contains(ext) { return .documents }
        if ext == "app" || lower.contains("/applications/") { return .applications }

        if isFolder {
            if lower.contains("/downloads/") { return .partials }
            if lower.contains("/pictures/") || lower.contains("/photos library") { return .images }
        }

        return .others
    }

    private func garbageReason(path: String, size: Int64) -> String? {
        let lower = path.lowercased()
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        let name = URL(fileURLWithPath: path).lastPathComponent.lowercased()

        if size == 0 {
            return "Zero-byte file (common leftover metadata artifact)."
        }
        if name == ".ds_store" {
            return "Finder metadata file. Often low-value clutter."
        }
        if ["tmp", "temp"].contains(ext) && size < 2 * 1024 * 1024 {
            return "Small temporary file candidate."
        }
        if ["part", "partial", "crdownload"].contains(ext) && size < 100 * 1024 * 1024 {
            return "Partial/incomplete download file."
        }
        if ["log", "out"].contains(ext) && size < 8 * 1024 * 1024 {
            return "Small log file likely disposable."
        }
        if (lower.contains("/library/caches/") || lower.contains("/tmp/") || lower.contains("/private/var/log/")) && size < 1024 * 1024 {
            return "Small cache/temp/journal artifact."
        }

        return nil
    }

    private func riskLevel(category: ScanCategory, garbageReason: String?, isFolder: Bool) -> RiskLevel {
        if garbageReason != nil {
            return .safe
        }

        switch category {
        case .tempFiles, .caches, .partials, .logs:
            return .safe
        case .nodePackages, .virtualEnvs, .archives, .others:
            return .review
        case .documents, .images, .videos, .applications:
            return .caution
        }
    }

    private func normalizedDeleteTargets() -> [AuditItem] {
        var uniqueByPath: [String: AuditItem] = [:]
        for item in deleteQueue {
            uniqueByPath[item.url.path] = item
        }
        let sorted = uniqueByPath.values.sorted { $0.url.path.count < $1.url.path.count }

        var keep: [AuditItem] = []
        for item in sorted {
            let isChildOfKept = keep.contains { item.url.path.hasPrefix($0.url.path + "/") }
            if !isChildOfKept {
                keep.append(item)
            }
        }
        return keep
    }

    private func removeDeletedFromCurrentView(deletedPaths: [String]) {
        let deletedSet = Set(deletedPaths)
        files.removeAll { item in
            deletedSet.contains(where: { item.url.path == $0 || item.url.path.hasPrefix($0 + "/") })
        }
        folders.removeAll { item in
            deletedSet.contains(where: { item.url.path == $0 || item.url.path.hasPrefix($0 + "/") })
        }
        deleteQueue.removeAll { item in
            deletedSet.contains(where: { item.url.path == $0 || item.url.path.hasPrefix($0 + "/") })
        }
        if let hovered = hoveredItem,
           deletedSet.contains(where: { hovered.url.path == $0 || hovered.url.path.hasPrefix($0 + "/") }) {
            hoveredItem = nil
        }
    }

    private func shellQuote(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func journalFileURL() -> URL? {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("DiskAuditNative", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("cleanup_journal.tsv", isDirectory: false)
        } catch {
            return nil
        }
    }

    private func loadJournal() {
        guard let fileURL = journalFileURL(),
              let text = try? String(contentsOf: fileURL, encoding: .utf8) else {
            cleanupJournal = []
            return
        }

        let formatter = ISO8601DateFormatter()
        var parsed: [CleanupJournalEntry] = []
        for line in text.split(separator: "\n") {
            let cols = line.split(separator: "\t")
            if cols.count != 3 { continue }
            guard let dt = formatter.date(from: String(cols[0])),
                  let count = Int(cols[1]),
                  let bytes = Int64(cols[2]) else { continue }
            parsed.append(CleanupJournalEntry(timestamp: dt, deletedCount: count, freedBytes: bytes))
        }
        cleanupJournal = parsed.sorted { $0.timestamp > $1.timestamp }
    }

    private func logCleanup(bytes: Int64, count: Int) {
        guard bytes > 0, count > 0, let fileURL = journalFileURL() else { return }

        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date()))\t\(count)\t\(bytes)\n"

        if let handle = try? FileHandle(forWritingTo: fileURL) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
                try handle.close()
            } catch {
                try? handle.close()
            }
        } else {
            try? line.write(to: fileURL, atomically: true, encoding: .utf8)
        }

        loadJournal()
    }

    private func scanResultsFileURL() -> URL? {
        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let dir = appSupport.appendingPathComponent("DiskAuditNative", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir.appendingPathComponent("scan_results.json", isDirectory: false)
        } catch {
            return nil
        }
    }

    private func saveScanResults() {
        guard let fileURL = scanResultsFileURL() else { return }

        struct SavedScanData: Codable {
            let timestamp: String
            let filesCount: Int
            let foldersCount: Int
            let totalSize: Int64

            init(timestamp: Date, files: [AuditItem], folders: [AuditItem]) {
                let formatter = ISO8601DateFormatter()
                self.timestamp = formatter.string(from: timestamp)
                self.filesCount = files.count
                self.foldersCount = folders.count
                self.totalSize = (files + folders).reduce(0) { $0 + $1.sizeBytes }
            }
        }

        guard let timestamp = lastScanTimestamp else { return }
        let data = SavedScanData(timestamp: timestamp, files: files, folders: folders)

        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let jsonData = try encoder.encode(data)
            try jsonData.write(to: fileURL, options: .atomic)
        } catch {
            return
        }
    }

    private func loadScanResults() {
        guard let fileURL = scanResultsFileURL(),
              FileManager.default.fileExists(atPath: fileURL.path),
              let jsonData = try? Data(contentsOf: fileURL) else {
            return
        }

        struct SavedScanData: Codable {
            let timestamp: String
            let filesCount: Int
            let foldersCount: Int
            let totalSize: Int64
        }

        do {
            let decoder = JSONDecoder()
            let data = try decoder.decode(SavedScanData.self, from: jsonData)
            let formatter = ISO8601DateFormatter()
            if let timestamp = formatter.date(from: data.timestamp) {
                lastScanTimestamp = timestamp
                statusMessage = "Loaded previous scan results from \(timestamp.formatted(date: .numeric, time: .standard))"
            }
        } catch {
            return
        }
    }

    private func deleteScanResultsFile() {
        guard let fileURL = scanResultsFileURL() else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}

final class ProgressPanelController {
    private var panel: NSPanel?

    func show(model: ScanViewModel) {
        if panel == nil {
            let contentView = ProgressPanelView(model: model)
            let hosting = NSHostingView(rootView: contentView)

            let panel = NSPanel(
                contentRect: NSRect(x: 200, y: 220, width: 390, height: 146),
                styleMask: [.titled, .utilityWindow, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.title = "Disk Audit Progress"
            panel.level = .floating
            panel.isFloatingPanel = true
            panel.hidesOnDeactivate = false
            panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
            panel.standardWindowButton(.zoomButton)?.isHidden = true
            panel.contentView = hosting
            panel.center()
            self.panel = panel
        }

        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

struct ProgressPanelView: View {
    @ObservedObject var model: ScanViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scanning selected locations")
                .font(.headline)
            ProgressView(value: model.progressValue)
                .progressViewStyle(.linear)
            Text(model.progressLabel)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Text("Scanned: \(model.scannedCount) files")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if model.isScanning {
                    Button("Cancel") {
                        model.cancelScan()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct CategoryFilterChip: View {
    let category: ScanCategory
    let selected: Bool
    let sizePreview: String
    let action: () -> Void
    let commandAction: () -> Void

    var body: some View {
        Button {
            if NSEvent.modifierFlags.contains(.command) {
                commandAction()
            } else {
                action()
            }
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(category.color)
                    .frame(width: 8, height: 8)
                Text(category.rawValue)
                    .font(.caption)
                Text(sizePreview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(selected ? category.color.opacity(0.18) : Color.secondary.opacity(0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(selected ? category.color : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .help(category.explanation)
    }
}

struct RiskBadge: View {
    let risk: RiskLevel

    var body: some View {
        Text(risk.label)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(risk.color.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(risk.color, lineWidth: 1)
            )
            .foregroundStyle(risk.color)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .help(risk.hint)
    }
}

struct TreemapTile: View {
    let item: AuditItem
    let rect: CGRect
    let isQueued: Bool
    let onTap: () -> Void
    let onQueue: () -> Void
    let onUnqueue: () -> Void
    let onHoverChanged: (AuditItem?) -> Void

    var body: some View {
        let minLabelW: CGFloat = 95
        let minLabelH: CGFloat = 58

        Button(action: onTap) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(item.category.color)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(isQueued ? Color.yellow : Color.white.opacity(0.5), lineWidth: isQueued ? 2 : 1)
                    )

                if rect.width > minLabelW && rect.height > minLabelH {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            RiskBadge(risk: item.risk)
                            Spacer(minLength: 0)
                        }
                        Text(item.displayName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(item.readableSize)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.95))
                            .lineLimit(1)
                        if let reason = item.garbageReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(2)
                        }
                    }
                    .padding(7)
                }
            }
            .frame(width: rect.width, height: rect.height)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            onHoverChanged(hovering ? item : nil)
        }
        .help("\(item.category.rawValue): \(item.category.explanation)\nRisk: \(item.risk.label) - \(item.risk.hint)\n\n\(item.garbageReason ?? "No special garbage hint")\n\nPath: \(item.url.path)\n\nClick to reveal in Finder. Right-click to queue for deletion.")
        .contextMenu {
            if isQueued {
                Button("Remove From Delete Queue") {
                    onUnqueue()
                }
            } else {
                Button("Add To Delete Queue") {
                    onQueue()
                }
            }
            Divider()
            Button("Reveal In Finder") {
                onTap()
            }
        }
    }
}

struct TreemapCanvas: View {
    let items: [AuditItem]
    let isQueued: (AuditItem) -> Bool
    let onTap: (AuditItem) -> Void
    let onQueue: (AuditItem) -> Void
    let onUnqueue: (AuditItem) -> Void
    let onHoverChanged: (AuditItem?) -> Void

    var body: some View {
        GeometryReader { geo in
            let layout = TreemapLayout.squarified(items: items, in: CGRect(origin: .zero, size: geo.size))

            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color(red: 0.94, green: 0.94, blue: 0.92))

                ForEach(layout, id: \.item.id) { entry in
                    TreemapTile(
                        item: entry.item,
                        rect: entry.rect,
                        isQueued: isQueued(entry.item),
                        onTap: { onTap(entry.item) },
                        onQueue: { onQueue(entry.item) },
                        onUnqueue: { onUnqueue(entry.item) },
                        onHoverChanged: onHoverChanged
                    )
                    .position(x: entry.rect.midX, y: entry.rect.midY)
                    .frame(width: entry.rect.width, height: entry.rect.height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

struct TreemapLayout {
    struct Entry {
        let item: AuditItem
        let rect: CGRect
    }

    static func squarified(items: [AuditItem], in rect: CGRect) -> [Entry] {
        guard rect.width > 0, rect.height > 0, !items.isEmpty else { return [] }

        let sorted = items.sorted { $0.sizeBytes > $1.sizeBytes }
        let totalWeight = max(sorted.reduce(Int64(0)) { $0 + $1.sizeBytes }, 1)
        let targetCells = min(700, max(220, sorted.count * 8))
        let containerArea = rect.width * rect.height
        let cellSide = max(4, floor(sqrt(containerArea / CGFloat(targetCells))))
        let columns = max(1, Int(floor(rect.width / cellSide)))
        let spacing: CGFloat = 1

        var entries: [Entry] = []
        var cursorX = 0
        var cursorY = 0

        for item in sorted {
            let ratio = CGFloat(item.sizeBytes) / CGFloat(totalWeight)
            let cells = max(1, Int(round(ratio * CGFloat(targetCells))))
            let sideCells = max(1, Int(round(sqrt(CGFloat(cells)))))

            if cursorX + sideCells > columns {
                cursorX = 0
                cursorY += sideCells
            }

            let originX = rect.minX + CGFloat(cursorX) * cellSide
            let originY = rect.minY + CGFloat(cursorY) * cellSide
            let side = CGFloat(sideCells) * cellSide - spacing

            if originY + side > rect.maxY {
                break
            }

            let itemRect = CGRect(x: originX, y: originY, width: side, height: side)
            entries.append(Entry(item: item, rect: itemRect))

            cursorX += sideCells
        }

        return entries.filter { $0.rect.width > 2 && $0.rect.height > 2 }
    }
}

class PathTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let fullPath: String
    var sizeBytes: Int64 = 0
    var children: [PathTreeNode] = []
    var isExpanded: Bool = false

    init(name: String, fullPath: String) {
        self.name = name
        self.fullPath = fullPath
    }

    var totalSize: Int64 {
        sizeBytes + children.reduce(0) { $0 + $1.totalSize }
    }
}

struct PathTreeBuilder {
    static func buildTree(from items: [AuditItem]) -> [PathTreeNode] {
        var roots: [String: PathTreeNode] = [:]

        for item in items {
            let components = item.url.pathComponents
            guard !components.isEmpty else { continue }

            let rootKey = components[0]
            if roots[rootKey] == nil {
                roots[rootKey] = PathTreeNode(name: components[0], fullPath: components[0])
            }

            var currentNode = roots[rootKey]!
            var pathSoFar = rootKey

            for component in components.dropFirst() {
                pathSoFar = pathSoFar + "/" + component
                if let existing = currentNode.children.first(where: { $0.fullPath == pathSoFar }) {
                    currentNode = existing
                } else {
                    let newNode = PathTreeNode(name: component, fullPath: pathSoFar)
                    currentNode.children.append(newNode)
                    currentNode = newNode
                }
            }

            currentNode.sizeBytes += item.sizeBytes
        }

        let sortedRoots = roots.values.sorted { $0.name < $1.name }
        for root in sortedRoots {
            sortNodeChildren(root)
        }
        return sortedRoots
    }

    private static func sortNodeChildren(_ node: PathTreeNode) {
        node.children.sort { $0.totalSize > $1.totalSize }
        for child in node.children {
            sortNodeChildren(child)
        }
    }
}

struct PathTreeRowView: View {
    let node: PathTreeNode
    @State private var isExpanded = false
    let depth: Int
    let onTap: (PathTreeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                if !node.children.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "triangle.fill" : "triangle")
                            .font(.system(size: 8, weight: .semibold))
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Image(systemName: "square.fill")
                        .font(.system(size: 6))
                        .foregroundStyle(.secondary)
                        .frame(width: 12, height: 12)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text(node.name.isEmpty ? "/" : node.name)
                        .font(.caption)
                        .lineLimit(1)
                    if !node.children.isEmpty {
                        Text(ByteCountFormatter.string(fromByteCount: node.totalSize, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if node.children.isEmpty {
                    Text(ByteCountFormatter.string(fromByteCount: node.sizeBytes, countStyle: .file))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding(.vertical, 6)
            .padding(.leading, CGFloat(depth) * 16)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                onTap(node)
            }

            if isExpanded {
                ForEach(node.children) { child in
                    PathTreeRowView(node: child, depth: depth + 1, onTap: onTap)
                }
            }
        }
    }
}

struct PathTreeView: View {
    let roots: [PathTreeNode]
    let onNodeTap: (PathTreeNode) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(roots) { root in
                    PathTreeRowView(node: root, depth: 0, onTap: onNodeTap)
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct SettingsSheetView: View {
    @ObservedObject var model: ScanViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scan Settings")
                .font(.title3.bold())
            Text("Select focused roots for huge-item scan and enable broader garbage scan for system locations.")
                .foregroundStyle(.secondary)

            Toggle("Include system-wide garbage roots (recommended)", isOn: $model.includeSystemGarbageScan)
                .disabled(model.includeFullDiskGarbageDeepScan)
            Toggle("Deep full-disk garbage scan (very slow)", isOn: $model.includeFullDiskGarbageDeepScan)
                .help("Uses /System/Volumes/Data as garbage root and can take a long time.")

            HStack(spacing: 8) {
                Button("Select All Locations") {
                    model.setAllLocations(enabled: true)
                }
                .buttonStyle(.bordered)
                .disabled(model.includeFullDiskGarbageDeepScan)

                Button("Deselect All Locations") {
                    model.setAllLocations(enabled: false)
                }
                .buttonStyle(.bordered)
                .disabled(model.includeFullDiskGarbageDeepScan)

                Spacer()
            }

            List {
                ForEach(model.scanLocations) { location in
                    Toggle(isOn: Binding(
                        get: { location.isEnabled },
                        set: { _ in model.toggleLocation(location) }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.title)
                            Text(location.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(minHeight: 280)
            .disabled(model.includeFullDiskGarbageDeepScan)
            .opacity(model.includeFullDiskGarbageDeepScan ? 0.45 : 1)

            HStack {
                Text(model.includeFullDiskGarbageDeepScan ? "Deep full scan is active: location and garbage root switches are locked because the whole Data volume is scanned." : "Hint: location selection controls huge-item scan; garbage scan can be extended system-wide using toggles above.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    onClose()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 690, height: 490)
    }
}

struct DeleteQueueSheetView: View {
    @ObservedObject var model: ScanViewModel
    let onClose: () -> Void
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Delete Queue")
                .font(.title3.bold())
            Text("Review queued items and verify generated rm commands before execution.")
                .foregroundStyle(.secondary)

            Text("Estimated reclaimable: \(ByteCountFormatter.string(fromByteCount: model.deleteQueueFreedEstimate, countStyle: .file))")
                .font(.callout)

            List {
                ForEach(model.deleteQueue) { item in
                    HStack {
                        Circle().fill(item.category.color).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 8) {
                                Text(item.displayName)
                                RiskBadge(risk: item.risk)
                            }
                            Text(item.url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(item.readableSize)
                            .foregroundStyle(.secondary)
                    }
                    .contextMenu {
                        Button("Reveal In Finder") { model.openInFinder(item) }
                        Button("Remove From Queue") { model.unqueue(item) }
                    }
                }
            }
            .frame(minHeight: 220)

            Text("Generated command list")
                .font(.headline)
            TextEditor(text: .constant(model.rmCommandsPreview()))
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 140)
                .border(Color.secondary.opacity(0.2), width: 1)

            HStack {
                Button("Close") { onClose() }
                    .buttonStyle(.bordered)
                Button("Export .sh") { model.exportDeleteQueueScript() }
                    .buttonStyle(.bordered)
                    .disabled(model.deleteQueue.isEmpty)
                Spacer()
                Button("Execute Deletions") { showConfirm = true }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.deleteQueue.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 860, height: 730)
        .alert("Delete queued items now?", isPresented: $showConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { model.executeDeleteQueue() }
        } message: {
            Text("Queued paths will be removed. Deletion is currently limited to your home folder for safety.")
        }
    }
}

struct JournalSheetView: View {
    @ObservedObject var model: ScanViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanup Journal")
                .font(.title3.bold())
            Text("Freed storage per deletion run")
                .foregroundStyle(.secondary)

            if model.cleanupJournal.isEmpty {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay(Text("No cleanup runs logged yet.").foregroundStyle(.secondary))
            } else {
                List(model.cleanupJournal) { entry in
                    HStack {
                        Text(entry.timestamp.formatted(date: .numeric, time: .standard))
                        Spacer()
                        Text("Deleted: \(entry.deletedCount)")
                        Text("Freed: \(entry.readableSize)")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Close") { onClose() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 720, height: 480)
    }
}

struct HoverDetailsPanel: View {
    let item: AuditItem?

    var body: some View {
        Group {
            if let item {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Circle().fill(item.category.color).frame(width: 8, height: 8)
                        Text(item.displayName)
                            .font(.headline)
                        RiskBadge(risk: item.risk)
                        Spacer()
                        Text(item.readableSize)
                            .foregroundStyle(.secondary)
                    }
                    Text("Type: \(item.category.rawValue)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text(item.category.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let reason = item.garbageReason {
                        Text("Garbage hint: \(reason)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.url.path)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Item details")
                        .font(.headline)
                    Text("Hover a treemap tile to see category explanation, risk level and cleanup hint.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Text("This area is fixed to keep the treemap size stable.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 128, maxHeight: 128, alignment: .topLeading)
        .background(Color.secondary.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ContentView: View {
    @StateObject private var model = ScanViewModel()
    @State private var panelController = ProgressPanelController()
    @State private var showSettings = false
    @State private var showDeleteQueue = false
    @State private var showJournal = false

    var body: some View {
        VStack(spacing: 14) {
            header
            treemapPanel
            footer
        }
        .padding(16)
        .frame(minWidth: 1160, minHeight: 780)
        .onChange(of: model.isScanning) { scanning in
            if scanning {
                panelController.show(model: model)
            } else {
                panelController.hide()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsSheetView(model: model) { showSettings = false }
        }
        .sheet(isPresented: $showDeleteQueue) {
            DeleteQueueSheetView(model: model) { showDeleteQueue = false }
        }
        .sheet(isPresented: $showJournal) {
            JournalSheetView(model: model) { showJournal = false }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("DISK AUDIT")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Real treemap + hover explanations + risk labels + cleanup workflow")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let timestamp = model.lastScanTimestamp {
                    Text("Last scan: \(timestamp.formatted(date: .numeric, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Settings") { showSettings = true }
                    .buttonStyle(.bordered)

                Button("Delete Queue (\(model.deleteQueue.count))") { showDeleteQueue = true }
                    .buttonStyle(.bordered)

                Button("Journal") { showJournal = true }
                    .buttonStyle(.bordered)

                if model.lastScanTimestamp != nil {
                    Button("Clear Results") { model.clearScanResults() }
                        .buttonStyle(.bordered)
                }

                Text("Threshold (MB)")
                TextField("MB", value: $model.minSizeMB, format: .number)
                    .frame(width: 84)
                    .textFieldStyle(.roundedBorder)

                Button(model.isScanning ? "Scanning..." : "Start Scan") {
                    model.startScan()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isScanning)
            }
        }
    }

    private var treemapPanel: some View {
        HStack(spacing: 12) {
            sidebar

            VStack(alignment: .leading, spacing: 8) {
                Text(model.summaryLine)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if !model.statusMessage.isEmpty {
                    Text(model.statusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if model.viewMode == .tree {
                    if model.treeRoots.isEmpty {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.08))
                            .overlay(
                                Text(model.isScanning ? "Scan in progress..." : "No items to display. Start scan or adjust filters.")
                                    .foregroundStyle(.secondary)
                            )
                    } else {
                        PathTreeView(roots: model.treeRoots) { node in
                            let path = node.fullPath
                            if let url = URL(string: "file://" + path) {
                                NSWorkspace.shared.activateFileViewerSelecting([url])
                            }
                        }
                        .background(Color(red: 0.94, green: 0.94, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                } else if model.filteredItems.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.08))
                        .overlay(
                            Text(model.isScanning ? "Scan in progress..." : "No items for current filters. Start scan or adjust filters.")
                                .foregroundStyle(.secondary)
                        )
                } else {
                    TreemapCanvas(
                        items: Array(model.filteredItems.prefix(320)),
                        isQueued: { model.isQueued($0) },
                        onTap: { model.openInFinder($0) },
                        onQueue: { model.queue($0) },
                        onUnqueue: { model.unqueue($0) },
                        onHoverChanged: { model.hoveredItem = $0 }
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filters")
                .font(.headline)

            Picker("View", selection: $model.viewMode) {
                ForEach(TreemapViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Picker("View Category", selection: $model.viewCategoryFilter) {
                ForEach(ViewCategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.viewMode == .tree)

            if model.viewMode != .tree {
                HStack(spacing: 6) {
                    ForEach(RiskLevel.allCases) { risk in
                        Button {
                            if model.selectedRisks.contains(risk) {
                                model.selectedRisks.remove(risk)
                            } else {
                                model.selectedRisks.insert(risk)
                            }
                        } label: {
                            Text(risk.label)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(model.selectedRisks.contains(risk) ? risk.color.opacity(0.22) : Color.secondary.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(model.selectedRisks.contains(risk) ? risk.color : Color.gray.opacity(0.35), lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 7))
                                .foregroundStyle(model.selectedRisks.contains(risk) ? risk.color : Color.secondary)
                        }
                        .buttonStyle(.plain)
                        .help(risk.hint)
                    }
                }

                Button(model.selectedRisks.count == RiskLevel.allCases.count ? "Deselect All Risks" : "Select All Risks") {
                    model.toggleAllRiskFilters()
                }
                .buttonStyle(.bordered)
            }

            if model.viewMode == .tree {
                Text("Tree View Legend")
                    .font(.subheadline.weight(.semibold))
                Text("Hierarchical view of all scanned paths. Numbers show total size including subfolders.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            } else if model.viewMode == .files {
                HStack {
                    Text("File Type Filter")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Select All") {
                        model.selectAllCategories()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ScanCategory.allCases) { category in
                            CategoryFilterChip(
                                category: category,
                                selected: model.selectedCategories.contains(category),
                                sizePreview: ByteCountFormatter.string(
                                    fromByteCount: model.fileCategorySizePreview[category, default: 0],
                                    countStyle: .file
                                ),
                                action: {
                                    if model.selectedCategories.contains(category) {
                                        model.selectedCategories.remove(category)
                                    } else {
                                        model.selectedCategories.insert(category)
                                    }
                                },
                                commandAction: {
                                    model.selectOnlyCategory(category)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 210)
            } else if model.viewMode == .folders {
                HStack {
                    Text("Folder Type Filter")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Select All") {
                        model.selectAllCategories()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ScanCategory.allCases) { category in
                            CategoryFilterChip(
                                category: category,
                                selected: model.selectedCategories.contains(category),
                                sizePreview: ByteCountFormatter.string(
                                    fromByteCount: model.folderCategorySizePreview[category, default: 0],
                                    countStyle: .file
                                ),
                                action: {
                                    if model.selectedCategories.contains(category) {
                                        model.selectedCategories.remove(category)
                                    } else {
                                        model.selectedCategories.insert(category)
                                    }
                                },
                                commandAction: {
                                    model.selectOnlyCategory(category)
                                }
                            )
                        }
                    }
                }
                .frame(maxHeight: 210)
            }

            Divider()

            Text("Details")
                .font(.headline)
            HoverDetailsPanel(item: model.hoveredItem)
        }
        .frame(minWidth: 360, maxWidth: 360, maxHeight: .infinity, alignment: .topLeading)
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var footer: some View {
        HStack {
            Text("Hover tiles for explanations, right-click to queue deletion, click to reveal in Finder.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

@main
struct DiskAuditApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
    }
}
