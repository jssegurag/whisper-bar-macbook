import SwiftUI

/// Ventana de Preferencias: barra lateral con siete secciones.
///
/// Venía de diez pestañas en un `TabView` de 580 pt, que necesitaban ~875: las
/// etiquetas se comprimían y dejaban de leerse. Y cuatro de esas pestañas pedían
/// rutas de binarios, que es configuración de instalación y no preferencia de
/// uso: eso se fue a la ventana de Configuración.
///
/// Las siete secciones agrupan por **lo que el usuario quiere hacer**, no por
/// cómo está construida la app. Ya no hay «Modelos» ni «Streaming».
struct PreferencesView: View {

    enum Section: String, CaseIterable, Identifiable {
        case general, text, languages, commands, live, sound, shortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:   return "General"
            case .text:      return "Texto"
            case .languages: return "Idiomas"
            case .commands:  return "Comandos"
            case .live:      return "En vivo"
            case .sound:     return "Sonido"
            case .shortcuts: return "Atajos"
            }
        }

        var symbol: String {
            switch self {
            case .general:   return "gearshape"
            case .text:      return "text.alignleft"
            case .languages: return "globe"
            case .commands:  return "bolt"
            case .live:      return "waveform"
            case .sound:     return "speaker.wave.2"
            case .shortcuts: return "command"
            }
        }

        /// Si la sección está aportando algo ahora mismo. El punto verde de la
        /// barra lateral responde a esto.
        var isActive: Bool {
            let config = Config.shared
            switch self {
            case .general, .shortcuts: return true
            case .text:      return config.llmEnabled || config.dictionaryEnabled || config.snippetsEnabled
            case .languages: return config.translationEnabled
            case .commands:  return config.voiceActionsEnabled
            case .live:      return config.isWhisperStreamValid
            case .sound:     return config.audioFeedbackEnabled
            }
        }
    }

    @State private var selection: Section = .general
    @State private var setupStatus = SetupStatus.current()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 760, height: 552)
        .tint(Theme.brand)
    }

    // MARK: - Barra lateral

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Section.allCases) { section in
                sidebarRow(section)
            }
            Spacer()
            Divider().padding(.vertical, 6)
            // La instalación vive aparte de las preferencias, pero se alcanza
            // desde aquí: es donde el usuario la va a buscar.
            Button {
                SetupWindowController.shared.showWindow()
            } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(setupStatus.needsAttention ? Theme.warn : Theme.brand)
                        .frame(width: 6, height: 6)
                    Text(setupStatus.needsAttention ? setupStatus.title : "Configuración…")
                        .font(.system(size: 12))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 9)
                .frame(height: 29)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .frame(width: 206)
        .onAppear { setupStatus = SetupStatus.current() }
    }

    private func sidebarRow(_ section: Section) -> some View {
        let selected = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: 8) {
                Image(systemName: section.symbol)
                    .font(.system(size: 12))
                    .frame(width: 16)
                Text(section.title).font(.system(size: 13))
                Spacer(minLength: 0)
                if section.isActive {
                    Circle().fill(Theme.brand).frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 9)
            .frame(height: 29)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(selected ? Theme.brand.opacity(0.16) : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Detalle

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch selection {
                case .general:   GeneralTab()
                case .text:      TextSection()
                case .languages: TranslationTab()
                case .commands:  VoiceActionsTab()
                case .live:      LiveSection()
                case .sound:     AudioTab()
                case .shortcuts: ShortcutsTab()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
