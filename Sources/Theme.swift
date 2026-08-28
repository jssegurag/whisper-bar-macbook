import AppKit
import SwiftUI

/// Design tokens del rediseño. Un solo sitio para los valores del handoff, para
/// que ninguna vista invente un verde propio.
///
/// El acento es único: `brand`. Desaparecen los neones cian, magenta y púrpura
/// que usaba la píldora, que eran el lenguaje visual de la app por accidente.
enum Theme {

    // MARK: - Color de marca

    /// #7ee800 — acento único: resaltado de menú, switches, botones primarios, onda.
    static let brandNS = NSColor(srgbRed: 126/255, green: 232/255, blue: 0, alpha: 1)
    /// #14200a — texto e iconos SOBRE verde. Nunca blanco sobre verde.
    static let onBrandNS = NSColor(srgbRed: 20/255, green: 32/255, blue: 10/255, alpha: 1)
    /// #a4f53c — verde para texto sobre fondo oscuro.
    static let brandHighNS = NSColor(srgbRed: 164/255, green: 245/255, blue: 60/255, alpha: 1)
    /// #ffd60a — falta algo, o dato sensible.
    static let warnNS = NSColor(srgbRed: 1, green: 214/255, blue: 10/255, alpha: 1)
    /// #ff453a — destructivo, punto de grabación.
    static let dangerNS = NSColor(srgbRed: 1, green: 69/255, blue: 58/255, alpha: 1)

    static var brand: Color     { Color(nsColor: brandNS) }
    static var onBrand: Color   { Color(nsColor: onBrandNS) }
    static var brandHigh: Color { Color(nsColor: brandHighNS) }
    static var warn: Color      { Color(nsColor: warnNS) }
    static var danger: Color    { Color(nsColor: dangerNS) }

    // MARK: - Superficies del menú

    /// Tile con su estado activo: fondo y borde verdes translúcidos.
    static let tileActiveFill   = NSColor(srgbRed: 126/255, green: 232/255, blue: 0, alpha: 0.13)
    static let tileActiveStroke = NSColor(srgbRed: 126/255, green: 232/255, blue: 0, alpha: 0.30)
    /// Tile inactivo: gris translúcido.
    static let tileFill   = NSColor(white: 1, alpha: 0.05)
    static let tileStroke = NSColor(white: 1, alpha: 0.07)

    // MARK: - Medidas del menú

    static let menuWidth: CGFloat    = 286
    static let menuPadding: CGFloat  = 5
    static let menuRowHeight: CGFloat = 26
    static let menuRowRadius: CGFloat = 5
    static let tileHeight: CGFloat   = 56
    static let tileRadius: CGFloat   = 7
    // MARK: - Píldora

    /// El handoff especifica 46. Se baja a 38 por decisión del cliente al probarla:
    /// a 46 se sentía gruesa flotando sobre el escritorio. Todo lo demás de la
    /// píldora se deriva de esta altura.
    static let pillHeight: CGFloat = 38
    static let pillPadding: CGFloat = 14
    static let pillGap: CGFloat = 9
    /// Alto de la barra más alta de la onda. Deja ~8 px de aire arriba y abajo.
    static let waveMaxHeight: CGFloat = 22

    /// Ancho útil de una fila dentro del menú, descontando el padding lateral.
    static var menuContentWidth: CGFloat { menuWidth - menuPadding * 2 }
}
