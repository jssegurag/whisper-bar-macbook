import SwiftUI

/// Sección «Idiomas».
///
/// Solo traduce al inglés, y no es una decisión de producto: whisper trae `-tr`,
/// que traduce **hacia** inglés y nada más. La dirección contraria no existe.
///
/// Antes había un selector de idioma destino que, para cualquier cosa que no
/// fuera inglés, exigía descargar un modelo de lenguaje de un gigabyte y pasaba
/// la transcripción por él. Se quitó: mucho costo para una traducción de calidad
/// incierta, cuando quien la necesita tiene mejores herramientas a un atajo.
struct TranslationTab: View {

    @State private var enabled: Bool
    @State private var modifiers: String

    init() {
        _enabled = State(initialValue: Config.shared.translationEnabled)
        _modifiers = State(initialValue: HotkeyBinding.glyphs(
            for: Config.shared.hotkeyModifiers(for: .translate)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                Toggle("Traducir al inglés al dictar", isOn: $enabled)
                    .font(.system(size: 13))
                    .onChange(of: enabled) { Config.shared.translationEnabled = $0 }
                Text("Hablas en tu idioma y se pega en inglés. Lo hace el propio motor de voz, sin instalar nada más.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 420, alignment: .leading)
            }

            HStack(spacing: 8) {
                Text("Atajo").font(.system(size: 13))
                Text(modifiers)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white.opacity(0.09)))
                Text("se cambia en Atajos")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
            .opacity(enabled ? 1 : 0.4)

            // Se dice para que nadie lo busque: la limitación es del motor.
            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Solo al inglés. El motor de voz traduce hacia el inglés y no admite la dirección contraria.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 420, alignment: .leading)

            Spacer(minLength: 0)
        }
        .padding(20)
    }
}
