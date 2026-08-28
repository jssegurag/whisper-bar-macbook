import AppKit

/// Vistas del menú de la barra.
///
/// Se dibujan a mano en lugar de usar filas nativas por una razón concreta del
/// handoff: el resaltado tiene que ser **verde de marca con texto oscuro**, y el
/// resaltado de `NSMenu` usa el color de acento del sistema, que ninguna app
/// puede sobrescribir. Con `NSMenuItem.view` sí se controla.
///
/// Coste asumido: al dibujar nosotros, hay que replicar el hover y el resaltado
/// por teclado a mano (ver `isActiveRow`).

// MARK: - Fila

class MenuRowView: NSView {

    /// Lo que va a la izquierda del título: un símbolo, o un punto de estado.
    enum Leading {
        case symbol(String)
        case dot(NSColor)
        case none
    }

    private let leading: Leading
    private let title: String
    private let shortcut: String?
    /// Chevron a la derecha: la fila lleva a otra ventana.
    private let showsChevron: Bool
    private var hovering = false

    init(leading: Leading, title: String, shortcut: String? = nil, showsChevron: Bool = false) {
        self.leading = leading
        self.title = title
        self.shortcut = shortcut
        self.showsChevron = showsChevron
        super.init(frame: NSRect(x: 0, y: 0,
                                width: Theme.menuContentWidth,
                                height: Theme.menuRowHeight))
    }

    required init?(coder: NSCoder) { fatalError("no se usa desde xib") }

    /// El hover propio o el resaltado que pone el teclado.
    private var isActiveRow: Bool {
        hovering || (enclosingMenuItem?.isHighlighted ?? false)
    }

    private var isEnabledRow: Bool {
        enclosingMenuItem?.isEnabled ?? true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseEnteredAndExited, .activeInActiveApp],
                                      owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { hovering = true;  needsDisplay = true }
    override func mouseExited(with event: NSEvent)  { hovering = false; needsDisplay = true }

    override func mouseUp(with event: NSEvent) {
        guard isEnabledRow, let item = enclosingMenuItem else { return }
        // Una fila con submenú no ejecuta ni cierra: el submenú lo abre NSMenu al
        // resaltarla.
        guard item.submenu == nil else { return }
        item.menu?.cancelTracking()
        if let action = item.action {
            NSApp.sendAction(action, to: item.target, from: item)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let active = isActiveRow && isEnabledRow
        let textColor: NSColor = !isEnabledRow ? .tertiaryLabelColor
                              : active ? Theme.onBrandNS : .labelColor

        if active {
            Theme.brandNS.setFill()
            NSBezierPath(roundedRect: bounds.insetBy(dx: 0, dy: 0.5),
                         xRadius: Theme.menuRowRadius,
                         yRadius: Theme.menuRowRadius).fill()
        }

        // Ancho reservado a la izquierda: 16 px, para que todos los títulos
        // arranquen alineados aunque una fila no tenga icono.
        let iconBox = NSRect(x: 8, y: (bounds.height - 16) / 2, width: 16, height: 16)
        switch leading {
        case .symbol(let name):
            if let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
                let sized = symbol.withSymbolConfiguration(config) ?? symbol
                tinted(sized, textColor).draw(in: iconBox)
            }
        case .dot(let color):
            let d: CGFloat = 7
            let dot = NSRect(x: iconBox.midX - d / 2, y: iconBox.midY - d / 2, width: d, height: d)
            (active ? Theme.onBrandNS : color).setFill()
            NSBezierPath(ovalIn: dot).fill()
        case .none:
            break
        }

        let titleFont = NSFont.systemFont(ofSize: 13.5)
        let titleX = iconBox.maxX + 8
        draw(title, font: titleFont, color: textColor,
             at: NSRect(x: titleX, y: 0, width: bounds.width - titleX - 40, height: bounds.height),
             alignment: .left)

        if let shortcut {
            draw(shortcut, font: NSFont.systemFont(ofSize: 13),
                 color: textColor.withAlphaComponent(active ? 0.65 : 0.5),
                 at: NSRect(x: bounds.width - 46, y: 0, width: 38, height: bounds.height),
                 alignment: .right)
        } else if showsChevron {
            draw("›", font: NSFont.systemFont(ofSize: 14),
                 color: textColor.withAlphaComponent(active ? 0.7 : 0.35),
                 at: NSRect(x: bounds.width - 22, y: 0, width: 14, height: bounds.height),
                 alignment: .right)
        }
    }

    private func draw(_ text: String, font: NSFont, color: NSColor,
                      at rect: NSRect, alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font, .foregroundColor: color, .paragraphStyle: style,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let height = string.size().height
        string.draw(in: NSRect(x: rect.minX, y: (rect.height - height) / 2,
                              width: rect.width, height: height))
    }

    private func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
        NSImage(size: image.size, flipped: false) { rect in
            image.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
    }
}

// MARK: - Fila de tiles

/// Los tres accesos directos de arriba del menú: Grabar, En vivo, Píldora.
class MenuTilesView: NSView {

    struct Tile {
        let symbol: String
        let label: String
        let isActive: Bool
        let action: Selector
        /// El tile de grabar dibuja la onda en lugar del símbolo.
        var showsWave: Bool = false
    }

    private let tiles: [Tile]
    private let target: AnyObject?
    private var hoverIndex: Int?
    private var waveTimer: Timer?
    private var wavePhase: CGFloat = 0

    init(tiles: [Tile], target: AnyObject?) {
        self.tiles = tiles
        self.target = target
        super.init(frame: NSRect(x: 0, y: 0,
                                width: Theme.menuContentWidth,
                                height: Theme.tileHeight))
        if tiles.contains(where: { $0.showsWave }) { startWave() }
    }

    required init?(coder: NSCoder) { fatalError("no se usa desde xib") }

    deinit { waveTimer?.invalidate() }

    /// El temporizador se registra en `.common` a propósito: mientras un menú está
    /// abierto el run loop corre en modo de seguimiento de eventos, y un timer en
    /// modo `default` no dispararía.
    private func startWave() {
        let timer = Timer(timeInterval: 1 / 30.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.wavePhase += 0.22
            self.needsDisplay = true
        }
        RunLoop.current.add(timer, forMode: .common)
        waveTimer = timer
    }

    private var tileWidth: CGFloat {
        let gaps = CGFloat(tiles.count - 1) * Theme.menuPadding
        return (bounds.width - gaps) / CGFloat(tiles.count)
    }

    private func rect(at index: Int) -> NSRect {
        NSRect(x: CGFloat(index) * (tileWidth + Theme.menuPadding), y: 0,
               width: tileWidth, height: bounds.height)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: bounds,
                                      options: [.mouseMoved, .mouseEnteredAndExited, .activeInActiveApp],
                                      owner: self, userInfo: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let index = tiles.indices.first { rect(at: $0).contains(point) }
        if index != hoverIndex { hoverIndex = index; needsDisplay = true }
    }

    override func mouseExited(with event: NSEvent) { hoverIndex = nil; needsDisplay = true }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let index = tiles.indices.first(where: { rect(at: $0).contains(point) }) else { return }
        enclosingMenuItem?.menu?.cancelTracking()
        NSApp.sendAction(tiles[index].action, to: target, from: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        for index in tiles.indices {
            let tile = tiles[index]
            let box = rect(at: index)
            let hovered = hoverIndex == index

            let fill: NSColor = tile.isActive ? Theme.tileActiveFill : Theme.tileFill
            let stroke: NSColor = tile.isActive ? Theme.tileActiveStroke : Theme.tileStroke
            let path = NSBezierPath(roundedRect: box.insetBy(dx: 0.5, dy: 0.5),
                                    xRadius: Theme.tileRadius, yRadius: Theme.tileRadius)
            (hovered ? fill.blended(withFraction: 0.12, of: .white) ?? fill : fill).setFill()
            path.fill()
            stroke.setStroke()
            path.lineWidth = 1
            path.stroke()

            let contentColor: NSColor = tile.isActive ? Theme.brandNS : .labelColor
            let iconBox = NSRect(x: box.midX - 9.5, y: box.maxY - 30, width: 19, height: 19)

            if tile.showsWave {
                drawWave(in: iconBox)
            } else if let symbol = NSImage(systemSymbolName: tile.symbol, accessibilityDescription: nil) {
                let config = NSImage.SymbolConfiguration(pointSize: 15, weight: .regular)
                let sized = symbol.withSymbolConfiguration(config) ?? symbol
                NSImage(size: iconBox.size, flipped: false) { rect in
                    sized.draw(in: rect)
                    contentColor.set()
                    rect.fill(using: .sourceAtop)
                    return true
                }.draw(in: iconBox)
            }

            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.lineBreakMode = .byTruncatingTail
            NSAttributedString(string: tile.label, attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: tile.isActive ? Theme.brandNS : NSColor.secondaryLabelColor,
                .paragraphStyle: style,
            ]).draw(in: NSRect(x: box.minX, y: box.minY + 7, width: box.width, height: 14))
        }
    }

    /// La misma onda del icono de la barra: cinco barras creciendo desde el centro.
    private func drawWave(in box: NSRect) {
        let heights: [CGFloat] = [8, 13, 16, 13, 8]
        let offsets: [CGFloat] = [0, 0.14, 0.28, 0.14, 0]
        let barWidth: CGFloat = 2.5, gap: CGFloat = 1.5
        let total = CGFloat(heights.count) * barWidth + CGFloat(heights.count - 1) * gap
        let startX = box.midX - total / 2
        Theme.brandNS.setFill()
        for i in heights.indices {
            let t = sin(wavePhase + offsets[i] * .pi * 2) * 0.5 + 0.5
            let h = heights[i] * (0.38 + t * 0.62) * (box.height / 16)
            let x = startX + CGFloat(i) * (barWidth + gap)
            NSBezierPath(roundedRect: NSRect(x: x, y: box.midY - h / 2, width: barWidth, height: h),
                         xRadius: 1.25, yRadius: 1.25).fill()
        }
    }
}
