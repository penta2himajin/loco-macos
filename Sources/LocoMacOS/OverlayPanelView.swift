import SwiftUI
import LocoMacOSCore

/// Spotlight / Raycast–inspired launcher chrome: one search row + answer body.
struct OverlayPanelView: View {
    @Bindable var vm: OverlayViewModel
    var onDismiss: () -> Void

    @FocusState private var inputFocused: Bool

    private let panelWidth: CGFloat = 640
    private let cornerRadius: CGFloat = 20

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        VStack(spacing: 0) {
            searchRow
            if showsBody {
                Divider().opacity(0.22)
                bodySection
            }
        }
        .frame(width: panelWidth)
        .glassEffect(.regular.interactive(), in: shape)
        .shadow(color: .black.opacity(0.28), radius: 28, y: 12)
        .onAppear {
            inputFocused = true
        }
        .onChange(of: vm.isBusy) { _, busy in
            if !busy { inputFocused = true }
        }
    }

    /// Body opens for replies / clarify / errors — not for busy-only “Thinking…”.
    private var showsBody: Bool {
        !vm.reply.isEmpty
            || !vm.clarifyChoices.isEmpty
            || vm.status.hasPrefix("Error")
            || vm.status.hasPrefix("Runtime failed")
    }

    private var searchRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .symbolRenderingMode(.hierarchical)

            TextField("Ask loco…", text: $vm.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .regular))
                .focused($inputFocused)
                .disabled(vm.isBusy)
                .onSubmit { vm.submit() }

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
                .frame(maxHeight: 280)
            } else if vm.status.hasPrefix("Error") || vm.status.hasPrefix("Runtime failed") {
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
