import SwiftUI
import AppKit

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
    let onDrillDown: () -> Void
    let isDrillDownable: Bool
    let isWatched: Bool
    let onWatch: () -> Void
    let extraSizeLabel: String?

    var body: some View {
        let minLabelW: CGFloat = 95
        let minLabelH: CGFloat = 58

        Button(action: {
            let flags = NSEvent.modifierFlags
            if flags.contains(.command) {
                onTap()
            } else if flags.contains(.control) {
                onQueue()
            } else if isDrillDownable {
                onDrillDown()
            } else {
                onTap()
            }
        }) {
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
                        if let extraSizeLabel {
                            Text(extraSizeLabel)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.95))
                                .lineLimit(1)
                        }
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
        .help("Left Click: Drill Down (if available). CTRL+Click: Add to Delete Queue. CMD+Click: Show in Finder.")
        .contextMenu {
            Button(action: onTap) {
                Label("Show in Finder", systemImage: "folder")
            }
            if isQueued {
                Button(action: onUnqueue) {
                    Label("Remove From Delete Queue", systemImage: "xmark.circle")
                }
            } else {
                Button(action: onQueue) {
                    Label("Add To Delete Queue", systemImage: "trash")
                }
            }
            Button(action: onDrillDown) {
                Label("Drill Down", systemImage: "arrow.down.right")
            }
            .disabled(!isDrillDownable)
            Button(action: onWatch) {
                Label(isWatched ? "Unwatch" : "Watch", systemImage: isWatched ? "eye.slash" : "eye")
            }
            Divider()
            Button("Left Click: Drill Down") {}
                .disabled(true)
            Button("CTRL+Click: Add To Delete Queue") {}
                .disabled(true)
            Button("CMD+Click: Show in Finder") {}
                .disabled(true)
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
    let onDrillDown: (AuditItem) -> Void
    let isDrillDownable: (AuditItem) -> Bool
    let isWatched: (AuditItem) -> Bool
    let onWatch: (AuditItem) -> Void
    let extraSizeLabel: (AuditItem) -> String?

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
                        onHoverChanged: onHoverChanged,
                        onDrillDown: { onDrillDown(entry.item) },
                        isDrillDownable: isDrillDownable(entry.item),
                        isWatched: isWatched(entry.item),
                        onWatch: { onWatch(entry.item) },
                        extraSizeLabel: extraSizeLabel(entry.item)
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

struct PathTreeRowView: View {
    let node: PathTreeNode
    @State private var isExpanded = false
    let depth: Int
    let levelMaxSize: Int64
    let onDrillDown: (PathTreeNode) -> Void
    let onShowInFinder: (PathTreeNode) -> Void
    let onQueue: (PathTreeNode) -> Void
    let onUnqueue: (PathTreeNode) -> Void
    let isQueued: Bool
    let onWatch: (PathTreeNode) -> Void
    let isWatched: Bool

    private var barRatio: CGFloat {
        guard levelMaxSize > 0 else { return 0 }
        return min(1, max(0, CGFloat(node.totalSize) / CGFloat(levelMaxSize)))
    }

    private var childrenMaxSize: Int64 {
        max(node.children.map(\.totalSize).max() ?? 0, 1)
    }

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

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isQueued ? Color.yellow.opacity(0.55) : Color.accentColor.opacity(0.55))
                        .frame(width: max(4, geo.size.width * barRatio))
                }
                .frame(height: 12)
            }
            .frame(height: 12)
            .padding(.leading, CGFloat(depth) * 16 + 16)
            .padding(.trailing, 8)
            .contentShape(Rectangle())
            .onTapGesture {
                let flags = NSEvent.modifierFlags
                if flags.contains(.command) {
                    onShowInFinder(node)
                } else if flags.contains(.control) {
                    onQueue(node)
                } else {
                    onDrillDown(node)
                }
            }
            .contextMenu {
                Button("Show in Finder") {
                    onShowInFinder(node)
                }
                if isQueued {
                    Button("Remove From Delete Queue") {
                        onUnqueue(node)
                    }
                } else {
                    Button("Add To Delete Queue") {
                        onQueue(node)
                    }
                }
                Button("Drill Down") {
                    onDrillDown(node)
                }
                .disabled(node.children.isEmpty)
                Button(isWatched ? "Unwatch" : "Watch") {
                    onWatch(node)
                }
                Divider()
                Button("Left Click: Drill Down") {}
                    .disabled(true)
                Button("CTRL+Click: Add To Delete Queue") {}
                    .disabled(true)
                Button("CMD+Click: Show in Finder") {}
                    .disabled(true)
            }

            if isExpanded {
                ForEach(node.children) { child in
                    PathTreeRowView(
                        node: child,
                        depth: depth + 1,
                        levelMaxSize: childrenMaxSize,
                        onDrillDown: onDrillDown,
                        onShowInFinder: onShowInFinder,
                        onQueue: onQueue,
                        onUnqueue: onUnqueue,
                        isQueued: isQueued,
                        onWatch: onWatch,
                        isWatched: isWatched
                    )
                }
            }
        }
    }
}

struct PathTreeView: View {
    let roots: [PathTreeNode]
    let onDrillDown: (PathTreeNode) -> Void
    let onShowInFinder: (PathTreeNode) -> Void
    let onQueue: (PathTreeNode) -> Void
    let onUnqueue: (PathTreeNode) -> Void
    let isQueued: (PathTreeNode) -> Bool
    let onWatch: (PathTreeNode) -> Void
    let isWatched: (PathTreeNode) -> Bool

    private var rootMaxSize: Int64 {
        max(roots.map(\.totalSize).max() ?? 0, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(roots) { root in
                    PathTreeRowView(
                        node: root,
                        depth: 0,
                        levelMaxSize: rootMaxSize,
                        onDrillDown: onDrillDown,
                        onShowInFinder: onShowInFinder,
                        onQueue: onQueue,
                        onUnqueue: onUnqueue,
                        isQueued: isQueued(root),
                        onWatch: onWatch,
                        isWatched: isWatched(root)
                    )
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
    @State private var showGarbagePaths = false
    @State private var newExcludePath = ""

    private let systemGarbagePaths = [
        "/private/var/tmp",
        "/private/var/log",
        "/Library/Caches",
        "/Library/Logs",
        "/System/Volumes/Data/private/var/tmp",
        "/System/Volumes/Data/private/var/log",
        "/System/Volumes/Data/Library/Caches",
        "/System/Volumes/Data/Library/Logs",
        "/System/Volumes/Data/Users",
        "/System/Volumes/Data/Applications"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Scan Settings")
                .font(.title3.bold())

            GroupBox {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle(isOn: $model.includeFullDiskGarbageDeepScan) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Full Disk Scan")
                                .font(.headline)
                            Text("Scans everything starting from /. Very slow, but finds all large files and garbage across the entire disk. All custom location settings below are ignored.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(4)
            } label: {
                Label("Scan Mode", systemImage: "scope")
                    .font(.subheadline.weight(.semibold))
            }

            if model.includeFullDiskGarbageDeepScan {
                Text("Full disk scan is active - all location and garbage root settings are locked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                GroupBox {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Choose which folders to scan for large files.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Select All") { model.setAllLocations(enabled: true) }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
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
                        .frame(minHeight: 200)
                    }
                    .padding(4)
                } label: {
                    Label("Your Locations", systemImage: "folder")
                        .font(.subheadline.weight(.semibold))
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(isOn: $model.includeSystemGarbageScan) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Include system garbage locations")
                                Text("Also scans common system temp, cache, and log folders for garbage candidates (zero-byte files, partials, old logs, etc.).")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        if model.includeSystemGarbageScan {
                            DisclosureGroup(isExpanded: $showGarbagePaths) {
                                VStack(alignment: .leading, spacing: 3) {
                                    ForEach(systemGarbagePaths, id: \.self) { path in
                                        if FileManager.default.fileExists(atPath: path) {
                                            Text(path)
                                                .font(.system(.caption2, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            } label: {
                                Text("Show scanned system paths")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(4)
                } label: {
                    Label("System Garbage Roots", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                }
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skip specific folders during scan. Useful for network drives, external backups, or known huge unimportant directories.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        TextField("Enter path to exclude...", text: $newExcludePath)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            let trimmed = newExcludePath.trimmingCharacters(in: .whitespaces)
                            if !trimmed.isEmpty && !model.excludedPaths.contains(trimmed) {
                                model.excludedPaths.append(trimmed)
                                newExcludePath = ""
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(newExcludePath.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    if !model.excludedPaths.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(model.excludedPaths, id: \.self) { path in
                                HStack {
                                    Text(path)
                                        .font(.caption2)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Spacer()
                                    Button(action: {
                                        model.excludedPaths.removeAll { $0 == path }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(4)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(4)
                            }
                        }
                    } else {
                        Text("No paths excluded (full scan enabled)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .italic()
                    }
                }
                .padding(4)
            } label: {
                Label("Exclude Paths", systemImage: "xmark.bin.fill")
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()
            HStack {
                Spacer()
                Button("Done") { onClose() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 690, height: 680)
    }
}

struct DeleteQueueSheetView: View {
    @ObservedObject var model: ScanViewModel
    let onClose: () -> Void
    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deletion Queue")
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

struct KeyboardHandler: NSViewRepresentable {
    let model: ScanViewModel

    func makeNSView(context: Context) -> NSView {
        let view = KeyboardView(model: model)
        DispatchQueue.main.async { view.window?.makeFirstResponder(view) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyboardView: NSView {
        let model: ScanViewModel

        init(model: ScanViewModel) {
            self.model = model
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError() }
        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                super.keyDown(with: event)
                return
            }
            Task { @MainActor in
                switch event.charactersIgnoringModifiers {
                case "1": model.viewMode = .files
                case "2": model.viewMode = .fileTypes
                case "3": model.viewMode = .folders
                case "4": model.viewMode = .folderTypes
                case "5": model.viewMode = .tree
                case "q": model.viewCategoryFilter = .all
                case "w": model.viewCategoryFilter = .hugeOnly
                case "e": model.viewCategoryFilter = .garbageOnly
                case "a": model.toggleRisk(.safe)
                case "s": model.toggleRisk(.review)
                case "d": model.toggleRisk(.caution)
                default: break
                }
            }
        }
    }
}
