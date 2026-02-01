import SwiftUI

struct ColorPaletteView: View {
    @Binding var selectedColor: UIColor
    @Binding var selectedPaletteIndex: Int
    @State private var showColorPicker = false
    @State private var customColors: [UIColor] = []
    @State private var recentColors: [UIColor] = []
    @State private var pickerColor: Color = .black

    private let palettes = Palette.allPalettes

    var body: some View {
        VStack(spacing: 6) {
            // Palette selector
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(palettes.enumerated()), id: \.offset) { index, palette in
                        Button(palette.name) {
                            selectedPaletteIndex = index
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(selectedPaletteIndex == index ? Color.accentColor : Color(.systemGray5))
                        .foregroundColor(selectedPaletteIndex == index ? .white : .primary)
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 8)
            }

            // Recent colors
            if !recentColors.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Recent")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 40)

                        ForEach(Array(recentColors.enumerated()), id: \.offset) { _, color in
                            Button {
                                selectedColor = color
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(color))
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(colorsMatch(color, selectedColor) ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }

            // Colors
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    // Current color
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(selectedColor))
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white, lineWidth: 2))
                        .shadow(radius: 2)

                    // Color wheel button
                    Button {
                        pickerColor = Color(selectedColor)
                        showColorPicker = true
                    } label: {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.title)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 36, height: 36)
                    }

                    Divider().frame(height: 30)

                    // Palette colors
                    ForEach(Array(currentPalette.colors.enumerated()), id: \.offset) { _, color in
                        Button {
                            selectedColor = color
                            addToRecent(color)
                        } label: {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color(color))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(colorsMatch(color, selectedColor) ? Color.white : Color.clear, lineWidth: 2)
                                )
                        }
                    }

                    // Custom colors
                    if !customColors.isEmpty {
                        Divider().frame(height: 30)

                        ForEach(Array(customColors.enumerated()), id: \.offset) { index, color in
                            Button {
                                selectedColor = color
                                addToRecent(color)
                            } label: {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(color))
                                    .frame(width: 30, height: 30)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(colorsMatch(color, selectedColor) ? Color.white : Color.clear, lineWidth: 2)
                                    )
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    customColors.remove(at: index)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }

                }
                .padding(.horizontal, 8)
            }
        }
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .background(
            ColorPickerPresenter(
                isPresented: $showColorPicker,
                selectedColor: $selectedColor,
                onColorPicked: { color in
                    addToCustom(color)
                    addToRecent(color)
                }
            )
        )
    }

    private var currentPalette: Palette {
        palettes[safe: selectedPaletteIndex] ?? palettes[0]
    }

    private func addToRecent(_ color: UIColor) {
        // Remove duplicate if exists, then prepend
        recentColors.removeAll { colorsMatch($0, color) }
        recentColors.insert(color, at: 0)
        if recentColors.count > 16 {
            recentColors.removeLast()
        }
    }

    private func addToCustom(_ color: UIColor) {
        if !customColors.contains(where: { colorsMatch($0, color) }) {
            customColors.append(color)
        }
    }

    private func colorsMatch(_ a: UIColor, _ b: UIColor) -> Bool {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return abs(r1 - r2) < 0.01 && abs(g1 - g2) < 0.01 && abs(b1 - b2) < 0.01
    }
}

private struct ColorPickerPresenter: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    @Binding var selectedColor: UIColor
    var onColorPicked: (UIColor) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        context.coordinator.onColorChanged = { color in
            self.selectedColor = color
        }
        context.coordinator.onDismiss = {
            self.onColorPicked(self.selectedColor)
            self.isPresented = false
        }

        if isPresented && uiViewController.presentedViewController == nil {
            let picker = UIColorPickerViewController()
            picker.selectedColor = selectedColor
            picker.supportsAlpha = false
            picker.delegate = context.coordinator
            picker.presentationController?.delegate = context.coordinator
            uiViewController.present(picker, animated: true)
        } else if !isPresented, uiViewController.presentedViewController != nil {
            uiViewController.dismiss(animated: true)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, UIColorPickerViewControllerDelegate, UIAdaptivePresentationControllerDelegate {
        var onColorChanged: ((UIColor) -> Void)?
        var onDismiss: (() -> Void)?

        func colorPickerViewController(_ viewController: UIColorPickerViewController, didSelect color: UIColor, continuously: Bool) {
            onColorChanged?(color)
        }

        func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
            onDismiss?()
        }

        func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
            onDismiss?()
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
