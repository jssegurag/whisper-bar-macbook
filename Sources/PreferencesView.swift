import SwiftUI

/// Ventana de Preferencias: solo la navegación entre pestañas.
///
/// Cada pestaña vive en su propio archivo (`PreferencesGeneralTab.swift`, etc.).
/// Antes las diez estaban aquí, en 806 líneas: cambiar una arriesgaba las otras
/// nueve, y dos personas tocando pestañas distintas conflictuaban siempre.
///
/// Las pestañas de Diccionario y Snippets viven con su funcionalidad, en
/// `DictionaryView.swift` y `SnippetsView.swift`.

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem { Label("General", systemImage: "gear") }
            ModelsTab()
                .tabItem { Label("Modelos", systemImage: "cpu") }
            LLMTab()
                .tabItem { Label("Corrección LLM", systemImage: "wand.and.stars") }
            TranslationTab()
                .tabItem { Label("Traducción", systemImage: "globe") }
            VoiceActionsTab()
                .tabItem { Label("Acciones", systemImage: "bolt.fill") }
            StreamingTab()
                .tabItem { Label("Streaming", systemImage: "waveform.circle") }
            DictionaryTab()
                .tabItem { Label("Diccionario", systemImage: "character.book.closed") }
            SnippetsTab()
                .tabItem { Label("Snippets", systemImage: "text.badge.plus") }
            AudioTab()
                .tabItem { Label("Audio", systemImage: "waveform") }
            ShortcutsTab()
                .tabItem { Label("Atajos", systemImage: "command") }
        }
        .frame(width: 580, height: 460)
        .padding()
    }
}
