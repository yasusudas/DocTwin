import SwiftUI

struct HoverIconButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    var cornerRadius: CGFloat = 6

    func makeBody(configuration: Configuration) -> some View {
        HoverIconButton(
            configuration: configuration,
            size: size,
            cornerRadius: cornerRadius
        )
    }

    private struct HoverIconButton: View {
        let configuration: Configuration
        let size: CGFloat
        let cornerRadius: CGFloat

        @Environment(\.isEnabled) private var isEnabled
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(foregroundColor)
                .frame(width: size, height: size)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(backgroundColor)
                )
                .scaleEffect(configuration.isPressed ? 0.92 : 1)
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
                .animation(.easeOut(duration: 0.12), value: isHovering)
                .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
                .onHover { isHovering = isEnabled && $0 }
        }

        private var foregroundColor: Color {
            guard isEnabled else {
                return .secondary.opacity(0.35)
            }

            return isHovering || configuration.isPressed ? .primary : .secondary
        }

        private var backgroundColor: Color {
            guard isEnabled else {
                return .clear
            }

            if configuration.isPressed {
                return Color.accentColor.opacity(0.18)
            }

            if isHovering {
                return Color(nsColor: .separatorColor).opacity(0.24)
            }

            return .clear
        }
    }
}

extension ButtonStyle where Self == HoverIconButtonStyle {
    static var hoverIcon: HoverIconButtonStyle {
        HoverIconButtonStyle()
    }
}
