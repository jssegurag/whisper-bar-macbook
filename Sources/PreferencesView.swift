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
        case general, text, intelligence, languages, live, sound, shortcuts

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general:   return "General"
            case .text:      return "Texto"
            case .intelligence: return "Inteligencia"
            case .languages: return "Idiomas"
            case .live:      return "En vivo"
            case .sound:     return "Sonido"
            case .shortcuts: return "Atajos"
            }
        }

        var symbol: String {
            switch self {
            case .general:   return "gearshape"
            case .text:      return "text.alignleft"
            case .intelligence: return "sparkles"
            case .languages: return "globe"
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
            case .text:      return config.dictionaryEnabled || config.snippetsEnabled
            case .intelligence: return config.isLlmValid
            case .languages: return config.translationEnabled
            case .live:      return config.isWhisperStreamValid
            case .sound:     return config.audioFeedbackEnabled
            }
        }
    }

    static let windowWidth: CGFloat = 760
    static let sidebarWidth: CGFloat = 206
    /// Ancho útil del detalle. Se fija en lugar de dejarlo crecer: una sección
    /// cuyo contenido pida más ancho que la ventana comprime la barra lateral y le
    /// recorta los iconos, que es justo lo que hacía «General» con su Form.
    static var detailWidth: CGFloat { windowWidth - sidebarWidth - 1 }

    @State private var selection: Section = .general
    @State private var setupStatus = SetupStatus.current()

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: Self.windowWidth, height: 552)
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
        .frame(width: Self.sidebarWidth)
        .fixedSize(horizontal: true, vertical: false)
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
                case .intelligence: IntelligenceTab()
                case .languages: TranslationTab()
                case .live:      LiveSection()
                case .sound:     AudioTab()
                case .shortcuts: ShortcutsTab()
                }
            }
            .frame(width: Self.detailWidth, alignment: .topLeading)
        }
        .frame(width: Self.detailWidth)
        .clipped()
    }
}
