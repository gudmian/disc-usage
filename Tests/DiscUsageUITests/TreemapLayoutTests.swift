import CoreGraphics
import Testing
@testable import DiscUsageUI

private let container = CGRect(x: 0, y: 0, width: 400, height: 300)

@Test func areasAreProportionalToValues() {
    let values: [Double] = [600, 300, 60, 30, 10]
    let rects = TreemapLayout.squarify(values: values, in: container)
    #expect(rects.count == values.count)
    let total = values.reduce(0, +)
    for (value, rect) in zip(values, rects) {
        let expected = value / total * (400 * 300)
        #expect(abs(rect.width * rect.height - expected) < 0.5)
    }
}

@Test func rectsDoNotOverlapAndStayInBounds() {
    let values: [Double] = [500, 400, 300, 200, 100, 50, 25]
    let rects = TreemapLayout.squarify(values: values, in: container)
    for rect in rects {
        #expect(container.insetBy(dx: -0.01, dy: -0.01).contains(rect))
    }
    for i in rects.indices {
        for j in rects.indices where i < j {
            let overlap = rects[i].intersection(rects[j])
            let area = overlap.isNull ? 0 : overlap.width * overlap.height
            #expect(area < 0.01)
        }
    }
}

@Test func degenerateInputsAreHandled() {
    #expect(TreemapLayout.squarify(values: [], in: container).isEmpty)
    let withZeros = TreemapLayout.squarify(values: [100, 0, 0], in: container)
    #expect(withZeros.count == 3)
    #expect(withZeros[0].width * withZeros[0].height > 0)
    #expect(withZeros[1].width * withZeros[1].height == 0)
    let zeroRect = TreemapLayout.squarify(values: [1, 2], in: .zero)
    #expect(zeroRect.count == 2)
}
