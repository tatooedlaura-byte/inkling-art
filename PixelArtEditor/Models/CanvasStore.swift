import UIKit

class CanvasStore: ObservableObject {
    @Published var canvasView: PixelCanvasUIView?
    @Published var smoothCanvasView: SmoothCanvasUIView?
}
