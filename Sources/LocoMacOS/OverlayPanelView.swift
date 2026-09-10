import SwiftUI
import LocoMacOSCore

/// Spotlight / Raycast–inspired launcher chrome: one search row + answer body.
struct OverlayPanelView: View {
    @Bindable var vm: OverlayViewModel
    var onDismiss: () -> Void
    /// Called when SwiftUI layout size changes so the NSPanel can resize.
    var onMeasuredSize: ((CGSize) -> Void)? = nil

    @FocusState private var inputFocused: Bool

    private let panelWidth: CGFloat = OverlayPresentation.panelWidth
    private let cornerRadius: CGFloat = 20

    private var presentation: OverlayPresentation {
        OverlayPresentation(
            reply: vm.reply,
            clarifyCount: vm.clarifyChoices.count,
            status: vm.status
        )
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            searchRow
            if presentation.showsBody {
                Divider().opacity(0.22)
                bodySection
            }
        }
        .frame(width: panelWidth)
        // Standard Liquid Glass (`.regular`). Avoid `.clear` / heavy interactivity —
        // those read too translucent for a text launcher. Soft window tint for legibility.
        .background {
            shape.fill(Color(nsColor: .windowBackgroundColor).opacity(0.42))
        }
        .glassEffect(.regular.tint(Color(nsColor: .windowBackgroundColor).opacity(0.25)), in: shape)
        .shadow(color: .black.opacity(0.22), radius: 24, y: 10)
        .background {
            GeometryReader { geo in
                Color.clear
                    .preference(key: OverlayContentSizeKey.self, value: geo.size)
            }
        }
        .onPreferenceChange(OverlayContentSizeKey.self) { size in
            guard size.width > 0, size.height > 0 else { return }
            onMeasuredSize?(size)
        }
        .onAppear {
            inputFocused = true
        }
        .onChange(of: vm.isBusy) { _, busy in
            if !busy { inputFocused = true }
        }
    }

    private var searchRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            TextField(vm.composerPlaceholder, text: $vm.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .lineLimit(1...8)
                .focused($inputFocused)
                .disabled(vm.isBusy)
                .onKeyPress(phases: .down) { press in
                    if press.key == .return {
                        switch ComposerKeyChord.action(
                            returnWithCommand: press.modifiers.contains(.command)
                        ) {
                        case .submit:
                            vm.submit()
                            return .handled
                        case .insertNewline:
                            return .ignored
                        default:
                            return .ignored
                        }
                    }
                    let up = press.key == .upArrow
                    let down = press.key == .downArrow
                    switch ComposerKeyChord.action(
                        arrowUp: up,
                        arrowDown: down,
                        draftIsEmpty: vm.draft.isEmpty,
                        browsingHistory: !vm.history.isLive
                    ) {
                    case .historyUp:
                        vm.historyUp()
                        return .handled
                    case .historyDown:
                        vm.historyDown()
                        return .handled
                    default:
                        return .ignored
                    }
                }

            if vm.isBusy {
                ProgressView()
                    .controlSize(.small)
            } else if !vm.draft.isEmpty {
                Button {
                    vm.draft = ""
                    inputFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private var bodySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !vm.clarifyChoices.isEmpty {
                ForEach(vm.clarifyChoices, id: \.index) { choice in
                    Button {
                        vm.draft = "\(choice.index)"
                        vm.submit()
                    } label: {
                        HStack(spacing: 10) {
                            Text("\(choice.index)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .frame(width: 22, height: 22)
                                .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                            Text(choice.label)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                }
            }

            if !vm.reply.isEmpty {
                ScrollView {
                    Text(vm.reply)
                        .font(.system(size: 15))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(.trailing, 4)
                }
                // Grow with content up to 15 lines; only then scroll — same on first paint and reopen.
                .frame(height: ReplyLayout.viewportHeight(for: vm.reply))
            } else if presentation.hasError {
                Text(vm.status)
                    .font(.system(size: 13))
                    .foregroundStyle(.red.opacity(0.9))
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 14)
    }
}

private struct OverlayContentSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}
