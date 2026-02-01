import SwiftUI

struct TopBarView: View {
    @Binding var gridSize: Int
    @Binding var undoTrigger: Int
    @Binding var redoTrigger: Int
    var canvasView: PixelCanvasUIView?
    @State private var showExportMenu = false

    private let sizes = [8, 16, 32, 64]

    var body: some View {
        HStack(spacing: 16) {
            // Grid size picker
            Menu {
                ForEach(sizes, id: \.self) { size in
                    Button("\(size)×\(size)") {
                        gridSize = size
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "grid")
                    Text("\(gridSize)×\(gridSize)")
                        .font(.subheadline.monospacedDigit())
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5))
                .cornerRadius(8)
            }

            Spacer()

            // Undo / Redo
            Button {
                undoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.title3)
            }

            Button {
                redoTrigger += 1
            } label: {
                Image(systemName: "arrow.uturn.forward")
                    .font(.title3)
            }

            // Export
            Menu {
                Button("Save PNG (1x)") {
                    exportPNG(scale: 1)
                }
                Button("Save PNG (4x)") {
                    exportPNG(scale: 4)
                }
                Button("Save PNG (8x)") {
                    exportPNG(scale: 8)
                }
                Button("Copy to Clipboard") {
                    if let cv = canvasView {
                        PNGExporter.copyToClipboard(grid: cv.grid, scale: 4)
                    }
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func exportPNG(scale: Int) {
        guard let cv = canvasView else { return }
        PNGExporter.saveToPhotos(grid: cv.grid, scale: scale) { _ in }
    }
}
