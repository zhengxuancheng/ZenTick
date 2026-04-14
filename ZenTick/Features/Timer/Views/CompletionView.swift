import SwiftUI

struct CompletionView: View {
    let durationMinutes: Int
    @Binding var note: String
    let onDismiss: () -> Void

    @State private var ringScale: CGFloat = 0.3
    @State private var ringOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var noteOpacity: Double = 0
    @State private var buttonOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @FocusState private var noteIsFocused: Bool

    var body: some View {
        ZStack {
            Color.timerBackground
                .ignoresSafeArea()
                .onTapGesture { noteIsFocused = false }

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale)

                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color.accentColor,
                                    Color.accentColor.opacity(0.6),
                                    Color.green.opacity(0.8),
                                    Color.accentColor
                                ],
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(.white)
                        .scaleEffect(ringScale)
                        .opacity(ringOpacity)
                }

                VStack(spacing: 6) {
                    Text(String(localized: "completion_title"))
                        .font(.title2.weight(.medium))
                        .foregroundStyle(.white)

                    Text(String(localized: "completion_duration \(durationMinutes)"))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .opacity(textOpacity)

                // Session note input
                VStack(spacing: 8) {
                    TextField(
                        String(localized: "note_placeholder"),
                        text: $note,
                        axis: .vertical
                    )
                    .lineLimit(1...3)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .focused($noteIsFocused)

                    Text(String(localized: "note_hint"))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 32)
                .opacity(noteOpacity)

                Spacer()

                Button {
                    HapticService.light()
                    noteIsFocused = false
                    onDismiss()
                } label: {
                    Text(String(localized: "completion_done"))
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.accentColor.opacity(0.8), in: RoundedRectangle(cornerRadius: 25))
                }
                .padding(.horizontal, 40)
                .opacity(buttonOpacity)
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            HapticService.success()

            withAnimation(.spring(duration: 0.8, bounce: 0.3)) {
                ringScale = 1.0
                ringOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.6).delay(0.4)) {
                textOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.7)) {
                noteOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(1.0)) {
                buttonOpacity = 1.0
            }
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
                .delay(1.0)
            ) {
                pulseScale = 1.15
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "a11y_completion \(durationMinutes)"))
    }
}
