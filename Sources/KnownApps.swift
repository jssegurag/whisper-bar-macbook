import Foundation

/// Las aplicaciones que Gluffi sabe clasificar, con su nombre.
///
/// **Se envían todas, estén instaladas o no.** La primera versión filtraba contra
/// lo que hubiera en la máquina en el primer arranque, y eso hacía la
/// funcionalidad menos útil de dos maneras: quien instalaba Slack al día
/// siguiente no lo veía aparecer en «Mensajería», y quien abría la pestaña en una
/// máquina recién montada se encontraba perfiles casi vacíos y no entendía para
/// qué servían.
///
/// Un identificador de una app que no tienes es **inofensivo**: la resolución es
/// por coincidencia exacta, así que nunca casa con nada. Lo único que costaba
/// enviarlo era enseñar `com.tinyspeck.slackmacgap` en una lista, sin forma de
/// saber qué es. Por eso el nombre viaja aquí: la lista la escribimos nosotros,
/// así que podemos decir «Slack» aunque el sistema no la conozca.
///
/// **Los bundle ID están verificados, no recordados.** Varios de los candidatos
/// obvios son inestables —Cursor usa un identificador de todesktop que cambia
/// entre versiones, los de JetBrains varían por producto— así que los que estaban
/// instalados se comprobaron con `osascript -e 'id of app "Nombre"'`. Los demás
/// salen de la documentación de cada fabricante y están marcados abajo, para que
/// quien los corrija sepa cuáles no pasaron por una máquina real.
enum KnownApps {

    struct Entry: Equatable {
        let name: String
        let bundleID: String
    }

    /// Terminales y editores. Lo que se dicta aquí son comandos y nombres de
    /// símbolo: ni mayúscula inicial ni punto final.
    static let terminal: [Entry] = [
        Entry(name: "Terminal", bundleID: "com.apple.Terminal"),                    // verificado
        Entry(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92"),           // verificado
        Entry(name: "Visual Studio Code", bundleID: "com.microsoft.VSCode"),        // verificado
        Entry(name: "Termius", bundleID: "com.termius-dmg.mac"),                    // verificado
        Entry(name: "iTerm", bundleID: "com.googlecode.iterm2"),
        Entry(name: "Ghostty", bundleID: "com.mitchellh.ghostty"),
        Entry(name: "Warp", bundleID: "dev.warp.Warp-Stable"),
        Entry(name: "Zed", bundleID: "dev.zed.Zed"),
        Entry(name: "Xcode", bundleID: "com.apple.dt.Xcode"),
        Entry(name: "Sublime Text", bundleID: "com.sublimetext.4"),
        Entry(name: "IntelliJ IDEA", bundleID: "com.jetbrains.intellij"),
        Entry(name: "PyCharm", bundleID: "com.jetbrains.pycharm"),
        Entry(name: "WebStorm", bundleID: "com.jetbrains.WebStorm"),
        Entry(name: "Android Studio", bundleID: "com.google.android.studio"),
    ]

    /// Chats. El punto final suena cortante y se habla como se habla.
    static let messaging: [Entry] = [
        Entry(name: "WhatsApp", bundleID: "net.whatsapp.WhatsApp"),                 // verificado
        Entry(name: "Mensajes", bundleID: "com.apple.MobileSMS"),                   // verificado
        Entry(name: "Slack", bundleID: "com.tinyspeck.slackmacgap"),
        Entry(name: "Telegram", bundleID: "ru.keepcoder.Telegram"),
        Entry(name: "Discord", bundleID: "com.hnc.Discord"),
        Entry(name: "Signal", bundleID: "org.whispersystems.signal-desktop"),
        Entry(name: "Microsoft Teams", bundleID: "com.microsoft.teams2"),
    ]

    /// Correo y documentos. Se escribe como se escribe.
    static let writing: [Entry] = [
        Entry(name: "Mail", bundleID: "com.apple.mail"),                            // verificado
        Entry(name: "Notas", bundleID: "com.apple.Notes"),                          // verificado
        Entry(name: "Pages", bundleID: "com.apple.iWork.Pages"),
        Entry(name: "Microsoft Word", bundleID: "com.microsoft.Word"),
        Entry(name: "Microsoft Outlook", bundleID: "com.microsoft.Outlook"),
        Entry(name: "Notion", bundleID: "notion.id"),
        Entry(name: "Obsidian", bundleID: "md.obsidian"),
        Entry(name: "Bear", bundleID: "net.shinyfrog.bear"),
        Entry(name: "Spark", bundleID: "com.readdle.smartemail-Mac"),
    ]

    static var all: [Entry] { terminal + messaging + writing }

    /// El nombre que le corresponde a un identificador, si lo conocemos.
    ///
    /// Lo usa la lista de un perfil para no tener que enseñar el identificador
    /// crudo de una app que el usuario no tiene instalada.
    static func name(for bundleID: String) -> String? {
        all.first { $0.bundleID == bundleID }?.name
    }
}
