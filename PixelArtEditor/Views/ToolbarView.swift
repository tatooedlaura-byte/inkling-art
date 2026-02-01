import SwiftUI

struct ToolbarView: View {
    @Binding var selectedTool: Tool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Tool.allCases) { tool in
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
        .padding(8)
        .background(.ultraThinMaterial)
        .cornerRadius(14)
        .shadow(radius: 4)
    }
}
