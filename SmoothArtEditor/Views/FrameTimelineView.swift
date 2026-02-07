import SwiftUI

struct FrameTimelineView: View {
    @ObservedObject var animationStore: AnimationStore
    var canvasStore: CanvasStore

    var body: some View {
        HStack(spacing: 12) {
            // Playback controls
            HStack(spacing: 8) {
                Button {
                    if let cv = canvasStore.canvasView {
                        animationStore.togglePlayback(canvas: cv)
                    }
                } label: {
                    Image(systemName: animationStore.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }

                Stepper("FPS: \(animationStore.fps)", value: $animationStore.fps, in: 1...30)
                    .fixedSize()
            }

            Divider()
                .frame(height: 40)

            // Frame thumbnails
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(animationStore.frames.indices, id: \.self) { index in
                            frameThumb(index: index)
                                .id(index)
                        }

                        // Add frame button
                        Button {
                            if let cv = canvasStore.canvasView {
                                animationStore.syncCurrentFrameFromCanvas(cv)
                            }
                            animationStore.addFrame()
                            if let cv = canvasStore.canvasView {
                                animationStore.loadFrameToCanvas(cv, index: animationStore.currentFrameIndex)
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.title3)
                                .frame(width: 50, height: 50)
                                .background(Color(.systemGray5))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .onChange(of: animationStore.currentFrameIndex) { newIndex in
                    withAnimation {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            Divider()
                .frame(height: 40)

            // Frame actions
            HStack(spacing: 8) {
                Button {
                    if let cv = canvasStore.canvasView {
                        animationStore.syncCurrentFrameFromCanvas(cv)
                    }
                    animationStore.duplicateCurrentFrame()
                    if let cv = canvasStore.canvasView {
                        animationStore.loadFrameToCanvas(cv, index: animationStore.currentFrameIndex)
                    }
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.title3)
                }
                .disabled(animationStore.isPlaying)

                Button {
                    animationStore.deleteCurrentFrame()
                    if let cv = canvasStore.canvasView {
                        animationStore.loadFrameToCanvas(cv, index: animationStore.currentFrameIndex)
                    }
                } label: {
                    Image(systemName: "trash")
                        .font(.title3)
                }
                .disabled(animationStore.frames.count <= 1 || animationStore.isPlaying)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func frameThumb(index: Int) -> some View {
        Button {
            guard !animationStore.isPlaying else { return }
            if let cv = canvasStore.canvasView {
                animationStore.syncCurrentFrameFromCanvas(cv)
            }
            animationStore.selectFrame(at: index)
            if let cv = canvasStore.canvasView {
                animationStore.loadFrameToCanvas(cv, index: index)
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .frame(width: 50, height: 50)

                Text("\(index + 1)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(animationStore.currentFrameIndex == index ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}
