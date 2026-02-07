import UIKit
import PencilKit

struct VectorCanvas: Codable {
    private var drawingData: Data

    init(drawing: PKDrawing = PKDrawing()) {
        self.drawingData = drawing.dataRepresentation()
    }

    var drawing: PKDrawing {
        get { (try? PKDrawing(data: drawingData)) ?? PKDrawing() }
        set { drawingData = newValue.dataRepresentation() }
    }

    func render(size: CGSize, scale: CGFloat) -> UIImage? {
        let rect = CGRect(origin: .zero, size: size)
        return drawing.image(from: rect, scale: scale)
    }
}
