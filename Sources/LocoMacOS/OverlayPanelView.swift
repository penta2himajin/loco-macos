import SwiftUI
import LocoMacOSCore

struct OverlayPanelView: View {
    @Bindable var vm: OverlayViewModel
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("loco")
                    .font(.headline)
                Spacer()
                Text(vm.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Pin") {
                    vm.isPinned.toggle()
                }
                .font(.caption)
                Button("Esc") {
                    onDismiss()
                }
                .font(.caption)
                .keyboardShortcut(.escape, modifiers: [])
            }

            TextField("Ask loco…", text: $vm.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(10)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.35)))
                .lineLimit(1...4)
                .disabled(vm.isBusy)
                .onSubmit { vm.submit() }

            if !vm.clarifyChoices.isEmpty {
                HStack(spacing: 8) {
                    ForEach(vm.clarifyChoices, id: \.index) { choice in
                        Button("\(choice.index). \(choice.label)") {
                            vm.draft = "\(choice.index)"
                            vm.submit()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            ScrollView {
                Text(vm.reply.isEmpty ? " " : vm.reply)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .font(.body)
            }
            .frame(minHeight: 120, maxHeight: 220)
            .padding(10)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("⌃⌘Space · backend \(RuntimeConfig.overlayDefault.backend.rawValue)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Ask") { vm.submit() }
                    .disabled(vm.isBusy || vm.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .keyboardShortcut(.return, modifiers: [])
            }
        }
        .padding(16)
        .frame(width: 420)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
    }
}
