import SwiftUI
import AppKit

/// Sección «Atajos». Editables, no de solo lectura.
///
/// La pestaña anterior mostraba las tres combinaciones y no dejaba cambiarlas.
/// `⌘⌥` choca con atajos de otras apps y el usuario no podía hacer nada.
struct ShortcutsTab: View {

    @State private var bindings: [HotkeyBinding] = Config.shared.hotkeyBindings
    /// Acción cuya combinación se está capturando ahora.
    @State private var capturing: HotkeyBinding.Action?
    @State private var validation: HotkeyBinding.Validation = .ok
    @State private var monitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(bindings, id: \.action.id) { binding in
                row(binding)
            }
            if let message = validation.message {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn)
                    Text(message)
                        .font(.system(size: 11.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: 440, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .onDisappear { stopCapture() }
    }

    private func row(_ binding: HotkeyBinding) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(binding.action.title).font(.system(size: 13))
                    Text(binding.action.purpose)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: 300, alignment: .leading)
                }
                Spacer(minLength: 0)
                combinationButton(binding)
            }

            if binding.action.supportsModes {
                Picker("", selection: Binding(
                    get: { binding.mode },
                    set: { setMode($0, for: binding.action) })) {
                    ForEach(HotkeyBinding.Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 280)

                Text(binding.mode.explanation)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    /// El botón muestra la combinación y, al pulsarlo, espera la nueva.
    private func combinationButton(_ binding: HotkeyBinding) -> some View {
        let isCapturing = capturing == binding.action
        return Button {
            isCapturing ? stopCapture() : startCapture(for: binding.action)
        } label: {
            Text(isCapturing ? "Pulsa las teclas…" : binding.glyphs)
                .font(.system(size: isCapturing ? 11.5 : 15, weight: .medium))
                .frame(minWidth: 108)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isCapturing ? Theme.brand.opacity(0.18) : Color.white.opacity(0.09)))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isCapturing ? Theme.brand : Color.white.opacity(0.12)))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Pulsa para cambiar la combinación")
    }

    // MARK: - Captura

    /// Se escucha `flagsChanged` en local: la ventana de Preferencias está activa,
    /// así que no hace falta un monitor global ni permiso de Accesibilidad para
    /// esto.
    private func startCapture(for action: HotkeyBinding.Action) {
        stopCapture()
        capturing = action
        validation = .ok
        monitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            let pressed = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .intersection([.command, .option, .shift, .control])
            // Se decide al soltar: mientras el usuario suma teclas, el conjunto
            // crece, y el que vale es el más completo antes de la soltada.
            if pressed.isEmpty {
                stopCapture()
            } else {
                commit(pressed, for: action)
            }
            return event
        }
    }

    private func commit(_ modifiers: NSEvent.ModifierFlags, for action: HotkeyBinding.Action) {
        let result = HotkeyBinding.validate(modifiers, for: action, others: bindings)
        validation = result
        guard result == .ok else { return }
        Config.shared.setHotkeyModifiers(modifiers, for: action)
        reload()
    }

    private func stopCapture() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        capturing = nil
    }

    private func setMode(_ mode: HotkeyBinding.Mode, for action: HotkeyBinding.Action) {
        Config.shared.setHotkeyMode(mode, for: action)
        reload()
    }

    /// Los atajos se vuelven a registrar sin reiniciar: AppDelegate escucha esto.
    private func reload() {
        bindings = Config.shared.hotkeyBindings
        NotificationCenter.default.post(name: .gluffiHotkeysChanged, object: nil)
    }
}

extension Notification.Name {
    static let gluffiHotkeysChanged = Notification.Name("gluffi.hotkeysChanged")
}
