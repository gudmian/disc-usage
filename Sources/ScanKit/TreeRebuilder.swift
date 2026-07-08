/// Иммутабельные операции над деревом: замена/удаление узла с пересчётом
/// размеров предков. path — имена узлов от корня (без имени самого корня).
public enum TreeRebuilder {
    public static func replacing(
        nodeAt path: [String], with replacement: FileNode, in root: FileNode
    ) -> FileNode? {
        guard let first = path.first else { return replacement }
        guard let child = root.child(named: first) else { return nil }
        guard let newChild = replacing(nodeAt: Array(path.dropFirst()), with: replacement, in: child)
        else { return nil }
        let newChildren = root.children.map { $0 === child ? newChild : $0 }
        return FileNode(directoryNamed: root.name, children: newChildren)
    }

    public static func removingNode(at path: [String], in root: FileNode) -> FileNode? {
        guard let first = path.first else { return nil }
        guard let child = root.child(named: first) else { return nil }
        if path.count == 1 {
            let newChildren = root.children.filter { $0 !== child }
            return FileNode(directoryNamed: root.name, children: newChildren)
        }
        guard let newChild = removingNode(at: Array(path.dropFirst()), in: child) else { return nil }
        let newChildren = root.children.map { $0 === child ? newChild : $0 }
        return FileNode(directoryNamed: root.name, children: newChildren)
    }
}
