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
    case files = "Files"
    case fileTypes = "File Types"
    case folders = "Folders"
    case folderTypes = "Folder Types"
    case tree = "Tree"

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
    @Published var currentScanningPath: String = ""
    @Published var excludedPaths: [String] = []
    @Published var currentDrillDownExtension: String? = nil
    @Published var currentDrillDownFolderName: String? = nil
    @Published var currentTreeDrillPath: String? = nil

    private var scanTask: Task<Void, Never>?
    private var groupedByExtensionCacheKey: String = ""
    private var groupedByExtensionCacheItems: [AuditItem] = []
    private var groupedByExtensionCacheCounts: [String: Int] = [:]
    private var filesForExtensionCacheKey: String = ""
    private var filesForExtensionCacheExt: String = ""
    private var filesForExtensionCacheItems: [AuditItem] = []
    private var groupedByFolderNameCacheKey: String = ""
    private var groupedByFolderNameCacheItems: [AuditItem] = []
    private var groupedByFolderNameCacheCounts: [String: Int] = [:]
    private var foldersForNameCacheKey: String = ""
    private var foldersForNameCacheName: String = ""
    private var foldersForNameCacheItems: [AuditItem] = []

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
        currentDrillDownExtension = nil
        currentDrillDownFolderName = nil
        currentTreeDrillPath = nil
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
        currentDrillDownExtension = nil
        currentDrillDownFolderName = nil
        currentTreeDrillPath = nil

        scanTask = Task(priority: .userInitiated) {
            let resourceKeys: [URLResourceKey] = [.isRegularFileKey, .isSymbolicLinkKey]
            var seenPaths = Set<String>()
            var scannedCount = 0

            var heavyOrGarbageFiles: [AuditItem] = []
            var folderAccumulator: [String: Int64] = [:]
            var folderGarbageCount: [String: Int] = [:]

            outer: for root in allRoots {
                guard let enumerator = FileManager.default.enumerator(
                    at: root,
                    includingPropertiesForKeys: resourceKeys,
                    options: [],
                    errorHandler: { _, _ in true }
                ) else { continue }

                while let fileURL = enumerator.nextObject() as? URL {
                    if Task.isCancelled { break outer }

                    let path = fileURL.path

                    if self.excludedPaths.contains(where: { path.hasPrefix($0) }) {
                        enumerator.skipDescendants()
                        continue
                    }
                    if seenPaths.contains(path) { continue }

                    do {
                        let values = try fileURL.resourceValues(forKeys: Set(resourceKeys))
                        if values.isSymbolicLink == true { continue }
                        guard values.isRegularFile == true else { continue }
                    } catch { continue }

                    seenPaths.insert(path)
                    scannedCount += 1

                    guard let size = self.fileSize(for: fileURL) else { continue }

                    let cat = self.classify(path: path, isFolder: false)
                    let garbageReason = self.garbageReason(path: path, size: size)
                    let insideHeavyRoot = heavyRoots.contains { path.hasPrefix($0.path) }
                    let insideGarbageRoot = garbageRoots.contains { path.hasPrefix($0.path) }

                    if insideHeavyRoot || (garbageReason != nil && insideGarbageRoot) {
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

                    if scannedCount % 200 == 0 {
                        let count = scannedCount
                        await MainActor.run {
                            self.scannedCount = count
                            self.progressLabel = "Scanning: \(count) files found..."
                            self.currentScanningPath = path
                        }
                    }
                }
            }

            var folderItems: [AuditItem] = []
            for (path, size) in folderAccumulator {
                let garbageHits = folderGarbageCount[path, default: 0]
                if size > 0 || garbageHits >= 20 {
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

            let finalCount = scannedCount
            await MainActor.run {
                self.scannedCount = finalCount
                self.files = heavyOrGarbageFiles
                self.folders = folderItems
                self.treeRoots = PathTreeBuilder.buildTree(from: self.files + self.folders)
                self.lastScanTimestamp = Date()
                self.isScanning = false
                self.progressValue = 1
                self.progressLabel = "Finished — \(finalCount) files scanned"
                self.currentScanningPath = ""
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
        currentScanningPath = ""
    }

    func openInFinder(_ item: AuditItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
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
        let source: [AuditItem]
        switch viewMode {
        case .files, .fileTypes:
            source = files
        case .folders, .folderTypes, .tree:
            source = folders
        }
        guard !selectedCategories.isEmpty, !selectedRisks.isEmpty else { return [] }
        return source.filter { item in
            let riskPass = selectedRisks.contains(item.risk)
            let categoryPass = selectedCategories.contains(item.category)
            let scopePass = matchesViewCategoryFilter(item)
            return riskPass && categoryPass && scopePass
        }
    }

    var groupedByExtension: [AuditItem] {
        guard viewMode == .fileTypes else { return filteredItems }

        let key = fileTypeFilterCacheKey()
        if key == groupedByExtensionCacheKey {
            return groupedByExtensionCacheItems
        }

        let source = filteredFilesForCurrentFilters()
        var extensionMap: [String: (totalSize: Int64, count: Int)] = [:]

        for item in source {
            let ext = URL(fileURLWithPath: item.url.path).pathExtension.isEmpty ? "[no extension]" : URL(fileURLWithPath: item.url.path).pathExtension
            if extensionMap[ext] != nil {
                extensionMap[ext]!.totalSize += item.sizeBytes
                extensionMap[ext]!.count += 1
            } else {
                extensionMap[ext] = (totalSize: item.sizeBytes, count: 1)
            }
        }

        groupedByExtensionCacheCounts = extensionMap.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.count
        }

        groupedByExtensionCacheItems = extensionMap
            .sorted { $0.value.totalSize > $1.value.totalSize }
            .map { ext, data in
                let cat = self.categoryForExtension(ext)
                let risk = self.riskLevel(category: cat, garbageReason: nil, isFolder: false)
                return AuditItem(
                    url: URL(fileURLWithPath: "/\(ext)", isDirectory: false),
                    sizeBytes: data.totalSize,
                    kind: .file,
                    category: cat,
                    garbageReason: nil,
                    risk: risk
                )
            }
        groupedByExtensionCacheKey = key
        return groupedByExtensionCacheItems
    }
    
    func filesForExtension(_ ext: String) -> [AuditItem] {
        let key = fileTypeFilterCacheKey()
        if key == filesForExtensionCacheKey && ext == filesForExtensionCacheExt {
            return filesForExtensionCacheItems
        }

        let searchExt = ext == "[no extension]" ? "" : ext
        filesForExtensionCacheItems = filteredFilesForCurrentFilters().filter { item in
            let itemExt = URL(fileURLWithPath: item.url.path).pathExtension
            return (itemExt.isEmpty && searchExt.isEmpty) || itemExt == searchExt
        }
        filesForExtensionCacheKey = key
        filesForExtensionCacheExt = ext
        return filesForExtensionCacheItems
    }

    var groupedByFolderName: [AuditItem] {
        let key = folderTypeFilterCacheKey()
        if key == groupedByFolderNameCacheKey {
            return groupedByFolderNameCacheItems
        }

        let source = filteredFoldersForCurrentFilters()
        var nameMap: [String: (totalSize: Int64, count: Int)] = [:]

        for item in source {
            let name = item.url.lastPathComponent
            let folderName = name.isEmpty ? "[root]" : name
            if nameMap[folderName] != nil {
                nameMap[folderName]!.totalSize += item.sizeBytes
                nameMap[folderName]!.count += 1
            } else {
                nameMap[folderName] = (totalSize: item.sizeBytes, count: 1)
            }
        }

        groupedByFolderNameCacheCounts = nameMap.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.count
        }

        groupedByFolderNameCacheItems = nameMap
            .sorted { $0.value.totalSize > $1.value.totalSize }
            .map { folderName, data in
                let cat = self.categoryForFolderName(folderName)
                let risk = self.riskLevel(category: cat, garbageReason: nil, isFolder: true)
                return AuditItem(
                    url: URL(fileURLWithPath: "/\(folderName)", isDirectory: true),
                    sizeBytes: data.totalSize,
                    kind: .folder,
                    category: cat,
                    garbageReason: nil,
                    risk: risk
                )
            }
        groupedByFolderNameCacheKey = key
        return groupedByFolderNameCacheItems
    }

    func foldersForName(_ name: String) -> [AuditItem] {
        let key = folderTypeFilterCacheKey()
        if key == foldersForNameCacheKey && name == foldersForNameCacheName {
            return foldersForNameCacheItems
        }
        let searchName = name == "[root]" ? "" : name
        foldersForNameCacheItems = filteredFoldersForCurrentFilters().filter { item in
            let itemName = item.url.lastPathComponent
            return (itemName.isEmpty && searchName.isEmpty) || itemName == searchName
        }
        foldersForNameCacheKey = key
        foldersForNameCacheName = name
        return foldersForNameCacheItems
    }

    func groupedFolderCount(for item: AuditItem) -> Int {
        groupedByFolderNameCacheCounts[item.url.lastPathComponent, default: 0]
    }

    private func folderTypeFilterCacheKey() -> String {
        let categories = selectedCategories.map(\.rawValue).sorted().joined(separator: "|")
        let risks = selectedRisks.map(\.rawValue).sorted().joined(separator: "|")
        return "\(folders.count)#\(categories)#\(risks)#\(viewCategoryFilter.rawValue)#\(minSizeMB)"
    }

    private func filteredFoldersForCurrentFilters() -> [AuditItem] {
        guard !selectedCategories.isEmpty, !selectedRisks.isEmpty else { return [] }
        return folders.filter { item in
            selectedRisks.contains(item.risk)
            && selectedCategories.contains(item.category)
            && matchesViewCategoryFilter(item)
        }
    }

    func groupedFileCount(for item: AuditItem) -> Int {
        groupedByExtensionCacheCounts[item.url.lastPathComponent, default: 0]
    }

    private func fileTypeFilterCacheKey() -> String {
        let categories = selectedCategories.map(\.rawValue).sorted().joined(separator: "|")
        let risks = selectedRisks.map(\.rawValue).sorted().joined(separator: "|")
        return "\(files.count)#\(categories)#\(risks)#\(viewCategoryFilter.rawValue)#\(minSizeMB)"
    }

    private func filteredFilesForCurrentFilters() -> [AuditItem] {
        guard !selectedCategories.isEmpty, !selectedRisks.isEmpty else { return [] }
        return files.filter { item in
            selectedRisks.contains(item.risk)
            && selectedCategories.contains(item.category)
            && matchesViewCategoryFilter(item)
        }
    }
    
    func drillDown(_ item: AuditItem) {
        if viewMode == .fileTypes && currentDrillDownExtension == nil {
            currentDrillDownExtension = item.url.lastPathComponent
        } else if viewMode == .folderTypes && currentDrillDownFolderName == nil {
            currentDrillDownFolderName = item.url.lastPathComponent
        }
    }
    
    func backFromDrillDown() {
        currentDrillDownExtension = nil
        currentDrillDownFolderName = nil
    }
    
    func isDrillDownable(_ item: AuditItem) -> Bool {
        return (viewMode == .fileTypes && currentDrillDownExtension == nil)
            || (viewMode == .folderTypes && currentDrillDownFolderName == nil)
    }

    var currentTreeRoots: [PathTreeNode] {
        guard let drillPath = currentTreeDrillPath,
              let node = findTreeNode(path: drillPath, in: treeRoots) else {
            return treeRoots
        }
        return node.children
    }

    func drillDownTree(_ node: PathTreeNode) {
        guard !node.children.isEmpty else { return }
        currentTreeDrillPath = node.fullPath
    }

    func backFromTreeDrillDown() {
        currentTreeDrillPath = nil
    }

    func openTreeNodeInFinder(_ node: PathTreeNode) {
        let url = URL(fileURLWithPath: node.fullPath, isDirectory: true)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func queueTreeNode(_ node: PathTreeNode) {
        queue(treeNodeAuditItem(node))
    }

    func unqueueTreeNode(_ node: PathTreeNode) {
        unqueue(treeNodeAuditItem(node))
    }

    func isTreeNodeQueued(_ node: PathTreeNode) -> Bool {
        isQueued(treeNodeAuditItem(node))
    }

    private func treeNodeAuditItem(_ node: PathTreeNode) -> AuditItem {
        let category = classify(path: node.fullPath, isFolder: true)
        let risk = riskLevel(category: category, garbageReason: nil, isFolder: true)
        return AuditItem(
            url: URL(fileURLWithPath: node.fullPath, isDirectory: true),
            sizeBytes: node.totalSize,
            kind: .folder,
            category: category,
            garbageReason: nil,
            risk: risk
        )
    }

    private func findTreeNode(path: String, in nodes: [PathTreeNode]) -> PathTreeNode? {
        for node in nodes {
            if node.fullPath == path {
                return node
            }
            if let found = findTreeNode(path: path, in: node.children) {
                return found
            }
        }
        return nil
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

    func toggleCategory(_ category: ScanCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    func toggleRisk(_ risk: RiskLevel) {
        if selectedRisks.contains(risk) {
            selectedRisks.remove(risk)
        } else {
            selectedRisks.insert(risk)
        }
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
        let source: [AuditItem]
        switch viewMode {
        case .files, .fileTypes:
            source = files
        case .folders, .folderTypes, .tree:
            source = folders
        }
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

    private func categoryForExtension(_ ext: String) -> ScanCategory {
        switch ext.lowercased() {
        case "jpg", "jpeg", "png", "gif", "webp", "heic", "tif", "tiff", "bmp", "svg",
             "ico", "raw", "cr2", "nef", "arw", "dng", "psd", "ai", "eps", "xcf":
            return .images
        case "mp4", "mov", "mkv", "avi", "webm", "m4v", "flv", "wmv", "mpg", "mpeg",
             "3gp", "ts", "vob", "rm", "rmvb", "m2ts":
            return .videos
        case "zip", "rar", "7z", "tar", "gz", "bz2", "xz", "dmg", "iso", "pkg",
             "deb", "rpm", "cab", "lz", "lzma", "zst", "tgz", "tbz2":
            return .archives
        case "log", "out":
            return .logs
        case "tmp", "temp":
            return .tempFiles
        case "part", "partial", "crdownload":
            return .partials
        case "pdf", "doc", "docx", "txt", "rtf", "xls", "xlsx", "ppt", "pptx", "md",
             "pages", "numbers", "key", "odt", "ods", "odp", "csv", "epub", "mobi":
            return .documents
        case "app":
            return .applications
        default:
            return .others
        }
    }

    private func categoryForFolderName(_ name: String) -> ScanCategory {
        let lower = name.lowercased()
        if lower == "node_modules" { return .nodePackages }
        if lower == ".venv" || lower == "venv" || lower == "env" || lower == ".env"
            || lower == "virtualenv" || lower == ".virtualenv" { return .virtualEnvs }
        if lower.contains("cache") || lower.contains("caches") { return .caches }
        if lower.contains("log") || lower == "logs" { return .logs }
        if lower.contains("tmp") || lower.contains("temp") { return .tempFiles }
        return .others
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

        struct SavedAuditItem: Codable {
            let path: String
            let sizeBytes: Int64
            let kind: String
            let category: String
            let garbageReason: String?
            let risk: String
        }

        struct SavedScanData: Codable {
            let timestamp: String
            let files: [SavedAuditItem]
            let folders: [SavedAuditItem]
        }

        guard let timestamp = lastScanTimestamp else { return }
        let formatter = ISO8601DateFormatter()
        let data = SavedScanData(
            timestamp: formatter.string(from: timestamp),
            files: files.map {
                SavedAuditItem(
                    path: $0.url.path,
                    sizeBytes: $0.sizeBytes,
                    kind: $0.kind.rawValue,
                    category: $0.category.rawValue,
                    garbageReason: $0.garbageReason,
                    risk: $0.risk.rawValue
                )
            },
            folders: folders.map {
                SavedAuditItem(
                    path: $0.url.path,
                    sizeBytes: $0.sizeBytes,
                    kind: $0.kind.rawValue,
                    category: $0.category.rawValue,
                    garbageReason: $0.garbageReason,
                    risk: $0.risk.rawValue
                )
            }
        )

        do {
            let encoder = JSONEncoder()
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

        struct SavedAuditItem: Codable {
            let path: String
            let sizeBytes: Int64
            let kind: String
            let category: String
            let garbageReason: String?
            let risk: String
        }

        struct SavedScanData: Codable {
            let timestamp: String
            let files: [SavedAuditItem]
            let folders: [SavedAuditItem]
        }

        do {
            let decoder = JSONDecoder()
            let data = try decoder.decode(SavedScanData.self, from: jsonData)
            let formatter = ISO8601DateFormatter()
            if let timestamp = formatter.date(from: data.timestamp) {
                lastScanTimestamp = timestamp

                files = data.files.compactMap { saved in
                    guard let kind = AuditItemKind(rawValue: saved.kind),
                          let category = ScanCategory(rawValue: saved.category),
                          let risk = RiskLevel(rawValue: saved.risk) else {
                        return nil
                    }
                    return AuditItem(
                        url: URL(fileURLWithPath: saved.path, isDirectory: kind == .folder),
                        sizeBytes: saved.sizeBytes,
                        kind: kind,
                        category: category,
                        garbageReason: saved.garbageReason,
                        risk: risk
                    )
                }

                folders = data.folders.compactMap { saved in
                    guard let kind = AuditItemKind(rawValue: saved.kind),
                          let category = ScanCategory(rawValue: saved.category),
                          let risk = RiskLevel(rawValue: saved.risk) else {
                        return nil
                    }
                    return AuditItem(
                        url: URL(fileURLWithPath: saved.path, isDirectory: kind == .folder),
                        sizeBytes: saved.sizeBytes,
                        kind: kind,
                        category: category,
                        garbageReason: saved.garbageReason,
                        risk: risk
                    )
                }

                treeRoots = PathTreeBuilder.buildTree(from: files + folders)
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

class PathTreeNode: Identifiable {
    let id = UUID()
    let name: String
    let fullPath: String
    var sizeBytes: Int64 = 0
    var children: [PathTreeNode] = []

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
        .background(KeyboardHandler(model: model))
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
                Text("Disk usage analysis and cleanup tool")
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
                Button("About") { AboutPanelController.shared.show() }
                    .buttonStyle(.bordered)
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
                        VStack(alignment: .leading, spacing: 8) {
                            if let drillPath = model.currentTreeDrillPath {
                                HStack {
                                    Button("Back") {
                                        model.backFromTreeDrillDown()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    Text("Drill-down: \(drillPath)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                }
                            }

                            PathTreeView(
                                roots: model.currentTreeRoots,
                                onDrillDown: { model.drillDownTree($0) },
                                onShowInFinder: { model.openTreeNodeInFinder($0) },
                                onQueue: { model.queueTreeNode($0) },
                                onUnqueue: { model.unqueueTreeNode($0) },
                                isQueued: { model.isTreeNodeQueued($0) }
                            )
                        }
                        .background(Color(red: 0.94, green: 0.94, blue: 0.92))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                    }
                } else if displayedTreemapItems.isEmpty {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondary.opacity(0.08))
                        .overlay(
                            Text(model.isScanning ? "Scan in progress..." : "No items for current filters. Start scan or adjust filters.")
                                .foregroundStyle(.secondary)
                        )
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        if model.viewMode == .fileTypes, let currentExt = model.currentDrillDownExtension {
                            HStack {
                                Button("Back") {
                                    model.backFromDrillDown()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Text("File type drill-down: \(currentExt)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }

                        if model.viewMode == .folderTypes, let currentName = model.currentDrillDownFolderName {
                            HStack {
                                Button("Back") {
                                    model.backFromDrillDown()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                                Text("Folder type drill-down: \(currentName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        }

                    TreemapCanvas(
                        items: displayedTreemapItems,
                        isQueued: { model.isQueued($0) },
                        onTap: { model.openInFinder($0) },
                        onQueue: { model.queue($0) },
                        onUnqueue: { model.unqueue($0) },
                        onHoverChanged: { model.hoveredItem = $0 },
                        onDrillDown: { model.drillDown($0) },
                        isDrillDownable: { model.isDrillDownable($0) },
                        extraSizeLabel: {
                            if model.viewMode == .fileTypes && model.currentDrillDownExtension == nil {
                                return "\(model.groupedFileCount(for: $0)) files"
                            }
                            if model.viewMode == .folderTypes && model.currentDrillDownFolderName == nil {
                                return "\(model.groupedFolderCount(for: $0)) folders"
                            }
                            return nil
                        }
                    )
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var displayedTreemapItems: [AuditItem] {
        if model.viewMode == .fileTypes {
            if let ext = model.currentDrillDownExtension {
                return Array(model.filesForExtension(ext).prefix(320))
            }
            return Array(model.groupedByExtension.prefix(320))
        }
        if model.viewMode == .folderTypes {
            if let name = model.currentDrillDownFolderName {
                return Array(model.foldersForName(name).prefix(320))
            }
            return Array(model.groupedByFolderName.prefix(320))
        }
        return Array(model.filteredItems.prefix(320))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Filters")
                .font(.headline)

            HStack {
                Text("View Mode")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("(1), (2), (3), (4), (5)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Picker("View", selection: $model.viewMode) {
                ForEach(TreemapViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Text("Threshold (MB)")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                TextField("MB", value: $model.minSizeMB, format: .number)
                    .frame(width: 84)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Text("Category Filter")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("(Q), (W), (E)")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            Picker("View Category", selection: $model.viewCategoryFilter) {
                ForEach(ViewCategoryFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .disabled(model.viewMode == .tree)

            if model.viewMode != .tree {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Risk Level")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("(A), (S), (D)")
                                .font(.caption)
                                .foregroundStyle(.gray)
                        }
                    }
                    Spacer()
                    ForEach(RiskLevel.allCases) { risk in
                        Button {
                            model.toggleRisk(risk)
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
            }

            if model.viewMode != .tree {
                let label = (model.viewMode == .folders || model.viewMode == .folderTypes) ? "Folder Type Filter" : "File Type Filter"
                let preview = (model.viewMode == .folders || model.viewMode == .folderTypes) ? model.folderCategorySizePreview : model.fileCategorySizePreview
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(label)
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Select All") { model.selectAllCategories() }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                        Text("CMD + Left Mouse for exclusive selection")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(ScanCategory.allCases, id: \.self) { category in
                            CategoryFilterChip(
                                category: category,
                                selected: model.selectedCategories.contains(category),
                                sizePreview: ByteCountFormatter.string(
                                    fromByteCount: preview[category, default: 0],
                                    countStyle: .file
                                ),
                                action: {
                                    if model.selectedCategories.contains(category) {
                                        model.selectedCategories.remove(category)
                                    } else {
                                        model.selectedCategories.insert(category)
                                    }
                                },
                                commandAction: { model.selectOnlyCategory(category) }
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

struct DiskAuditApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About DISK AUDIT") {
                    AboutPanelController.shared.show()
                }
            }
        }
    }
}

DiskAuditApp.main()
