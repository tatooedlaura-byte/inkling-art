import SwiftUI
import Foundation

struct ToolbarView: View {
    @Binding var selectedTool: Tool
    @Binding var selectedShapeKind: ShapeKind
    @Binding var shapeFilled: Bool
    var canvasMode: CanvasMode = .pixel
    @State private var showShapePicker = false

    // Smooth mode toggles
    @Binding var showGridOverlay: Bool
    @Binding var mirrorModeEnabled: Bool
    @Binding var showLayerPanel: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
                if shouldShowTool(tool) {
                    if tool == .shape {
                        shapeButton
                    } else {
                        Button {
                            selectedTool = tool
                        } label: {
                            Image(systemName: tool.iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedTool == tool ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(selectedTool == tool ? .white : .primary)
                                .cornerRadius(10)
                        }
                    }
                }
            }

            // Add divider and smooth mode buttons
            if canvasMode == .smooth {
                Divider()
                    .padding(.vertical, 4)

                // Grid button
                Button {
                    showGridOverlay.toggle()
                } label: {
                    Image(systemName: showGridOverlay ? "grid.circle.fill" : "grid.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(showGridOverlay ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(showGridOverlay ? .white : .primary)
                        .cornerRadius(10)
                }

                // Mirror button
                Button {
                    mirrorModeEnabled.toggle()
                } label: {
                    Image(systemName: mirrorModeEnabled ? "arrow.left.and.right.circle.fill" : "arrow.left.and.right.circle")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(mirrorModeEnabled ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(mirrorModeEnabled ? .white : .primary)
                        .cornerRadius(10)
                }

                // Layers button
                Button {
                    showLayerPanel.toggle()
                } label: {
                    Image(systemName: "square.3.layers.3d")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                        .background(showLayerPanel ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(showLayerPanel ? .white : .primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(radius: 4)
    }

    private func shouldShowTool(_ tool: Tool) -> Bool {
        switch canvasMode {
        case .pixel:
            return true
        case .smooth:
            return tool != .fill
        case .dotArt:
            return tool == .eraser || tool == .eyedropper
        }
    }

    private var shapeButton: some View {
        Button {
            if selectedTool == .shape {
                showShapePicker = true
            } else {
                selectedTool = .shape
            }
        } label: {
            Image(systemName: selectedShapeKind.iconName)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(selectedTool == .shape ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(selectedTool == .shape ? .white : .primary)
                .cornerRadius(10)
        }
        .onLongPressGesture(minimumDuration: 0.3) {
            selectedTool = .shape
            showShapePicker = true
        }
        .popover(isPresented: $showShapePicker) {
            shapePickerContent
        }
    }

    private var shapePickerContent: some View {
        VStack(spacing: 12) {
            Text("Shape")
                .font(.headline)
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 8) {
                ForEach(ShapeKind.allCases) { kind in
                    Button {
                        selectedShapeKind = kind
                        showShapePicker = false
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: kind.iconName)
                                .font(.title2)
                                .frame(width: 44, height: 44)
                                .background(selectedShapeKind == kind ? Color.accentColor : Color(.systemGray5))
                                .foregroundColor(selectedShapeKind == kind ? .white : .primary)
                                .cornerRadius(10)
                            Text(kind.displayName)
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .padding(.horizontal, 12)

            Divider()

            Toggle("Filled", isOn: $shapeFilled)
                .padding(.horizontal, 16)
                .disabled(selectedShapeKind == .line)

            Spacer().frame(height: 4)
        }
        .frame(width: 220)
        .padding(.vertical, 4)
    }
}
