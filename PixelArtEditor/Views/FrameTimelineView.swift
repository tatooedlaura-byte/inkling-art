import SwiftUI

struct FrameTimelineView: View {
    @ObservedObject var animationStore: AnimationStore
    @ObservedObject var canvasStore: CanvasStore
    @State private var contextMenuIndex: Int?

    private let thumbnailSize: CGFloat = 56

    var body: some View {
        HStack(spacing: 8) {
            // Play/Pause
            Button {
                if animationStore.isPlaying {
                    animationStore.stopPlayback(canvas: canvasStore.canvasView)
                } else if let cv = canvasStore.canvasView {
                    animationStore.startPlayback(canvas: cv)
                }
            } label: {
                Image(systemName: animationStore.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title3)
            }

            // Onion skin toggle
            Button {
                animationStore.onionSkinEnabled.toggle()
            } label: {
                Image(systemName: animationStore.onionSkinEnabled ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                    .font(.title3)
                    .foregroundColor(animationStore.onionSkinEnabled ? .blue : .primary)
            }

            // FPS stepper
            HStack(spacing: 2) {
                Text("\(animationStore.fps)")
                    .font(.caption.monospacedDigit())
                    .frame(width: 20)
                Stepper("", value: $animationStore.fps, in: 1...30)
                    .labelsHidden()
                    .scaleEffect(0.8)
            }
            .frame(width: 80)
            .onChange(of: animationStore.fps) { _ in
                animationStore.updatePlaybackSpeed()
            }

            Divider()
                .frame(height: 40)

            // Frame thumbnails
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(Array(animationStore.frames.enumerated()), id: \.offset) { index, frame in
                        frameThumbnail(index: index, frame: frame)
                    }

                    // Add frame button
                    Button {
                        if let cv = canvasStore.canvasView {
                            animationStore.addFrame(canvas: cv)
                        }
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4]))
                            .foregroundColor(.secondary)
                            .frame(width: thumbnailSize, height: thumbnailSize)
                            .overlay(Image(systemName: "plus").foregroundColor(.secondary))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func frameThumbnail(index: Int, frame: AnimationFrame) -> some View {
        let isSelected = index == animationStore.currentFrameIndex
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray6))
                .frame(width: thumbnailSize, height: thumbnailSize)

            if let img = PNGExporter.renderImage(grid: frame.grid, scale: max(1, Int(thumbnailSize) / frame.grid.width)) {
                Image(uiImage: img)
                    .resizable()
                    .interpolation(.none)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: thumbnailSize - 4, height: thumbnailSize - 4)
            }

            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                .frame(width: thumbnailSize, height: thumbnailSize)

            // Frame number
            Text("\(index + 1)")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.white)
                .padding(2)
                .background(Color.black.opacity(0.5))
                .cornerRadius(3)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(2)
        }
        .frame(width: thumbnailSize, height: thumbnailSize)
        .onTapGesture {
            if !animationStore.isPlaying, let cv = canvasStore.canvasView {
                animationStore.selectFrame(index: index, canvas: cv)
            }
        }
        .contextMenu {
            Button("Duplicate") {
                if let cv = canvasStore.canvasView {
                    animationStore.duplicateFrame(at: index, canvas: cv)
                }
            }
            if animationStore.frames.count > 1 {
                Button("Delete", role: .destructive) {
                    if let cv = canvasStore.canvasView {
                        animationStore.deleteFrame(at: index, canvas: cv)
                    }
                }
            }
        }
    }
}
