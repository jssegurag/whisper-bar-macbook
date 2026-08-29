import AppKit

/// El icono de la barra de menú: siempre el logo de Gluffi, nunca un emoji del
/// sistema.
///
/// Los seis estados de la app se comunican con **tres** tratamientos sobre el
/// mismo marco de 16×16, en vez de seis emoji distintos:
///
/// - reposo → el logo como imagen de plantilla, que macOS recolorea según el tema
///   y el estado destacado del menú;
/// - grabando → cinco barras verdes que crecen desde el centro;
/// - trabajando (transcribiendo, corrigiendo, traduciendo, ejecutando una acción)
///   → el logo atenuado con un anillo verde girando.
enum MenuBarIcon {

    /// Los tres tratamientos.
    enum Treatment: Equatable {
        case idle
        case recording
        case working
    }

    /// Estados de la app tal como los conoce AppDelegate.
    enum AppState: Equatable {
        case idle
        case recording
        case transcribing
        case translating
    }

    /// Seis estados → tres tratamientos. Separado del dibujo para poder probarlo.
    static func treatment(for state: AppState) -> Treatment {
        switch state {
        case .idle:                                            return .idle
        case .recording:                                       return .recording
        case .transcribing, .translating:                      return .working
        }
    }

    /// ¿El tratamiento necesita que algo se repinte en el tiempo?
    static func isAnimated(_ treatment: Treatment) -> Bool {
        treatment != .idle
    }

    static let size = NSSize(width: 16, height: 16)

    // MARK: - Imagen

    /// `phase` avanza con el temporizador de animación; `needsSetup` añade el
    /// punto ámbar, que es el único aviso permanente de que falta algo.
    static func image(treatment: Treatment,
                      phase: CGFloat = 0,
                      needsSetup: Bool = false) -> NSImage {
        switch treatment {
        case .idle:
            // Sin badge se devuelve la plantilla tal cual: es el único caso en el
            // que macOS puede invertir el icono al abrir el menú.
            guard needsSetup else { return markTemplate() }
            return badged(markTinted(NSColor.labelColor, alpha: 1))
        case .recording:
            return badged(bars(phase: phase), when: needsSetup)
        case .working:
            return badged(working(phase: phase), when: needsSetup)
        }
    }

    /// El logo como imagen de plantilla. macOS solo usa su canal alfa.
    static func markTemplate() -> NSImage {
        let image = loadMark() ?? fallbackMark()
        image.isTemplate = true
        image.size = size
        return image
    }

    // MARK: - Dibujo

    /// Cinco barras de 3 px, alturas 8/13/16/13/8, creciendo desde el centro.
    private static func bars(phase: CGFloat) -> NSImage {
        let heights: [CGFloat] = [8, 13, 16, 13, 8]
        let offsets: [CGFloat] = [0, 0.14, 0.28, 0.14, 0]   // simétrico
        let barWidth: CGFloat = 3, gap: CGFloat = 1.25, radius: CGFloat = 2
        let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
        let startX = (size.width - total) / 2

        return NSImage(size: size, flipped: false) { _ in
            Theme.brandNS.setFill()
            for i in heights.indices {
                // scaleY de .38 a 1 y vuelta, con desfase por barra
                let t = sin((phase + offsets[i] * .pi * 2)) * 0.5 + 0.5
                let scale = 0.38 + t * 0.62
                let h = heights[i] * scale
                let x = startX + CGFloat(i) * (barWidth + gap)
                let y = (size.height - h) / 2
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: barWidth, height: h),
                             xRadius: radius, yRadius: radius).fill()
            }
            return true
        }
    }

    /// Logo al 55 % con un anillo de 1.5 px girando: un tope verde sobre pista
    /// translúcida.
    private static func working(phase: CGFloat) -> NSImage {
        let mark = markTinted(Theme.brandNS, alpha: 0.55)
        return NSImage(size: size, flipped: false) { rect in
            mark.draw(in: rect.insetBy(dx: 3.2, dy: 3.2))

            let center = NSPoint(x: rect.midX, y: rect.midY)
            let r = rect.width / 2 - 0.9
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: r, startAngle: 0, endAngle: 360)
            track.lineWidth = 1.5
            Theme.brandNS.withAlphaComponent(0.25).setStroke()
            track.stroke()

            let start = -phase * 180 / .pi
            let cap = NSBezierPath()
            cap.appendArc(withCenter: center, radius: r,
                          startAngle: start, endAngle: start + 80)
            cap.lineWidth = 1.5
            cap.lineCapStyle = .round
            Theme.brandNS.setStroke()
            cap.stroke()
            return true
        }
    }

    /// Punto ámbar de 6 px con un hueco de 1.5 px alrededor, para que se separe
    /// del icono sin depender del color de la barra.
    private static func badged(_ base: NSImage, when apply: Bool = true) -> NSImage {
        guard apply else { return base }
        let canvas = NSImage(size: size, flipped: false) { rect in
            base.draw(in: rect)
            let d: CGFloat = 6, ring: CGFloat = 1.5
            let dot = NSRect(x: rect.maxX - d, y: rect.minY, width: d, height: d)

            // El hueco se hace borrando, no pintando el color de la barra: así
            // funciona igual en tema claro, oscuro y con la barra translúcida.
            NSGraphicsContext.current?.compositingOperation = .destinationOut
            NSBezierPath(ovalIn: dot.insetBy(dx: -ring, dy: -ring)).fill()
            NSGraphicsContext.current?.compositingOperation = .sourceOver

            Theme.warnNS.setFill()
            NSBezierPath(ovalIn: dot).fill()
            return true
        }
        canvas.isTemplate = false
        return canvas
    }

    /// El mark recoloreado. Se usa cuando el icono no puede ser plantilla, porque
    /// lleva verde o el punto ámbar.
    private static func markTinted(_ color: NSColor, alpha: CGFloat) -> NSImage {
        let mark = loadMark() ?? fallbackMark()
        return NSImage(size: size, flipped: false) { rect in
            mark.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)
            color.withAlphaComponent(alpha).set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }

    // MARK: - Carga del asset

    private static func loadMark() -> NSImage? {
        // Copiado a Contents/Resources por build.sh. Se busca por nombre para que
        // macOS elija automáticamente la variante @2x en pantallas Retina.
        if let named = NSImage(named: "GluffiMark") { return named.copy() as? NSImage }
        if let url = Bundle.main.url(forResource: "GluffiMark", withExtension: "png") {
            return NSImage(contentsOf: url)
        }
        return nil
    }

    /// Sin bundle —tests y arnés de UI— se dibuja un anillo con la silueta del
    /// mark: el código no debe caerse por un asset ausente.
    private static func fallbackMark() -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            NSColor.black.setStroke()
            let ring = NSBezierPath(ovalIn: rect.insetBy(dx: 2, dy: 2))
            ring.lineWidth = 3
            ring.stroke()
            return true
        }
    }
}
