import SwiftUI

struct ToolbarView: View {
    @Binding var selectedTool: Tool
    @Binding var selectedShapeKind: ShapeKind
    @Binding var shapeFilled: Bool
    @State private var showShapePicker = false

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
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
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(radius: 4)
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
