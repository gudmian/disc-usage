import CoreGraphics

/// Squarified treemap (Bruls, Huizing, van Wijk).
/// values — по убыванию; выход выровнен по индексам входа.
public enum TreemapLayout {
    public static func squarify(values: [Double], in rect: CGRect) -> [CGRect] {
        guard !values.isEmpty else { return [] }
        let total = values.reduce(0, +)
        guard total > 0, rect.width > 0, rect.height > 0 else {
            return Array(repeating: CGRect(origin: rect.origin, size: .zero), count: values.count)
        }
        let scale = rect.width * rect.height / total
        let areas = values.map { $0 * scale }

        var result: [CGRect] = []
        var remaining = rect
        var row: [Double] = []
        var index = 0
        while index < areas.count {
            let area = areas[index]
            if area <= 0 { break }
            let side = min(remaining.width, remaining.height)
            if row.isEmpty || worstAspect(row + [area], side) <= worstAspect(row, side) {
                row.append(area)
                index += 1
            } else {
                result.append(contentsOf: layoutRow(row, in: &remaining))
                row = []
            }
        }
        if !row.isEmpty {
            result.append(contentsOf: layoutRow(row, in: &remaining))
        }
        while result.count < values.count {
            result.append(CGRect(origin: remaining.origin, size: .zero))
        }
        return result
    }

    private static func worstAspect(_ row: [Double], _ side: Double) -> Double {
        guard !row.isEmpty, side > 0 else { return .infinity }
        let sum = row.reduce(0, +)
        guard sum > 0, let maxArea = row.max(), let minArea = row.min(), minArea > 0 else {
            return .infinity
        }
        let sideSquared = side * side
        let sumSquared = sum * sum
        return Swift.max(sideSquared * maxArea / sumSquared, sumSquared / (sideSquared * minArea))
    }

    private static func layoutRow(_ row: [Double], in remaining: inout CGRect) -> [CGRect] {
        let sum = row.reduce(0, +)
        var rects: [CGRect] = []
        if remaining.width >= remaining.height {
            let stripWidth = sum / remaining.height
            var y = remaining.minY
            for area in row {
                let height = area / stripWidth
                rects.append(CGRect(x: remaining.minX, y: y, width: stripWidth, height: height))
                y += height
            }
            remaining = CGRect(
                x: remaining.minX + stripWidth, y: remaining.minY,
                width: remaining.width - stripWidth, height: remaining.height)
        } else {
            let stripHeight = sum / remaining.width
            var x = remaining.minX
            for area in row {
                let width = area / stripHeight
                rects.append(CGRect(x: x, y: remaining.minY, width: width, height: stripHeight))
                x += width
            }
            remaining = CGRect(
                x: remaining.minX, y: remaining.minY + stripHeight,
                width: remaining.width, height: remaining.height - stripHeight)
        }
        return rects
    }
}
