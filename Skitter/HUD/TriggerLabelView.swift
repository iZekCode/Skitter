import SwiftUI
import UIKit

struct TriggerLabelView: View {
    let labelState: BagTriggerLabelState

    private var accentColor: Color {
        labelState.isWin
            ? Color.green
            : Color(red: 0.9, green: 0.2, blue: 0.2)
    }

    private var imageName: String {
        labelState.isWin ? "byegone_image" : "food_pile_image"
    }

    var body: some View {
        if labelState.isVisible {
            VStack(spacing: 10) {

                // Item image
                if let url = Bundle.main.url(forResource: imageName, withExtension: "png"),
                   let uiImage = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(accentColor.opacity(0.5), lineWidth: 1)
                        )
                }

                // Label text 
                Text(labelState.message)
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(accentColor)
                    .kerning(4)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(Color.black.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
            .animation(.easeOut(duration: 0.2), value: labelState.isVisible)
        }
    }
}
