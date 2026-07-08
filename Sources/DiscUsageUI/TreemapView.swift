import AppKit
import ScanKit
import SwiftUI

struct TreemapView: View {
    let node: FileNode
    let parentPath: String
    let onOpen: (FileNode) -> Void
    let onSelect: (FileNode, String) -> Void
    let onTrash: (FileNode, String) -> Void

    @State private var hoveredID: FileNode.ID?

    var body: some View {
        GeometryReader { proxy in
            let children = node.children.filter { $0.size > 0 }
            let rects = TreemapLayout.squarify(
                values: children.map { Double($0.size) },
                in: CGRect(origin: .zero, size: proxy.size))
            ZStack(alignment: .topLeading) {
                ForEach(Array(zip(children, rects)), id: \.0.id) { child, rect in
                    if rect.width >= 1, rect.height >= 1 {
                        cell(for: child, rect: rect)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func cell(for child: FileNode, rect: CGRect) -> some View {
        let path = absolutePath(of: child)
        TreemapCell(node: child, rect: rect, isHovered: hoveredID == child.id)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .onHover { hovering in
                if hovering {
                    hoveredID = child.id
                } else if hoveredID == child.id {
                    hoveredID = nil
                }
            }
            .onTapGesture {
                if child.kind == .directory { onOpen(child) } else { onSelect(child, path) }
            }
            .contextMenu {
                Button("Показать в Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: path)])
                }
                Button("Скопировать путь") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(path, forType: .string)
                }
                Divider()
                Button("В Корзину", role: .destructive) { onTrash(child, path) }
            }
            .help("\(path) — \(ByteFormatter.string(child.size))")
    }

    private func absolutePath(of child: FileNode) -> String {
        parentPath == "/" ? "/" + child.name : parentPath + "/" + child.name
    }
}

struct TreemapCell: View {
    let node: FileNode
    let rect: CGRect
    let isHovered: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(NodeColor.color(for: NodeColor.category(for: node))
                .opacity(isHovered ? 1.0 : 0.8))
            .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(.background, lineWidth: 1))
            .overlay(alignment: .topLeading) {
                if rect.width > 64, rect.height > 30 {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(node.name).font(.caption).bold().lineLimit(1)
                        Text(ByteFormatter.string(node.size)).font(.caption2).opacity(0.85)
                    }
                    .padding(4)
                    .foregroundStyle(.white)
                }
            }
    }
}
