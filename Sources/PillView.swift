import SwiftUI

/// Estado visual de la píldora flotante.
enum PillState {
    case idle
    case recording
    case transcribing
}

/// View model observable. Único punto de cambio de estado para la UI.
final class PillViewModel: ObservableObject {
    @Published var state: PillState = .idle
    /// «Transcribiendo» o «Corrigiendo»: la píldora dice en qué va, no solo que
    /// está ocupada.
    @Published var processingLabel: String = "Transcribiendo"
    /// Nivel de voz 0…1 que alimenta la onda. Lo empuja AppDelegate mientras graba.
    @Published var micLevel: CGFloat = 0
    /// Palabra en reposo. Solo cambia al volver a reposo tras un dictado.
    @Published var idleWord: String = IdleWord.word(at: Config.shared.idleWordIndex)
}

/// Píldora flotante.
///
/// El rediseño quita los tres neones —cian, magenta y púrpura— que eran el
/// lenguaje visual de la app por accidente. Ahora hay un solo acento, el verde de
/// marca, y el logo está presente en los tres estados: la píldora es Gluffi, no
/// un widget genérico de micrófono.
///
/// También desaparecen la palabra «REC» y el cronómetro: ninguno de los dos
/// aportaba, y el cronómetro además obligaba a una tipografía monoespaciada que
/// no pertenece a nada más de la app.
struct PillView: View {
    @ObservedObject var model: PillViewModel
    var onTap: () -> Void
    var onCancel: () -> Void
    /// Aviso de que el arrastre está en curso. No lleva desplazamiento a
    /// propósito: el de DragGesture es relativo a esta vista, que viaja con la
    /// ventana, así que usarlo para mover la ventana se realimenta. Quien mueve
    /// lee la posición del ratón en pantalla, que es absoluta.
    var onDrag: () -> Void = {}
    var onDragEnded: () -> Void = {}
    /// Tamaño real del contenido, para que el panel se ajuste.
    var onSizeChange: (CGSize) -> Void = { _ in }

    private let height: CGFloat = Theme.pillHeight

    /// Todo el movimiento cuelga de un solo reloj.
    ///
    /// Antes cada animación era un `repeatForever` atado a un `@State`, y eso
    /// falla de dos maneras que se vieron al probar: el nivel del micrófono
    /// cambia 30 veces por segundo, así que reiniciaba la animación de la onda y
    /// las barras perdían la fase; y el anillo dependía de un booleano puesto en
    /// `onAppear`, que al recrearse la vista ya venía en `true`, sin cambio de
    /// valor y por tanto sin animación.
    ///
    /// Con un reloj, cada cuadro se calcula desde el tiempo. No hay estado que
    /// reiniciar ni fases que descuadrar.
    var body: some View {
        // En reposo basta con 12 cuadros por segundo: lo único que se mueve es un
        // halo con periodo de 3.4 s. La píldora está siempre a la vista, así que
        // gastar 30 cuadros ahí sería quemar batería por nada.
        TimelineView(.animation(minimumInterval: model.state == .idle ? 1.0 / 12.0 : 1.0 / 30.0)) { timeline in
            content(at: timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    private func content(at time: TimeInterval) -> some View {
        HStack(spacing: Theme.pillGap) {
            switch model.state {
            case .idle:        idleContent(time)
            case .recording:   recordingContent(time)
            case .transcribing: processingContent(time)
            }
        }
        .padding(.horizontal, Theme.pillPadding)
        .frame(height: height)
        .background(background)
        .overlay(
            Capsule().stroke(Theme.brand.opacity(0.4), lineWidth: 1)
        )
        .overlay(breathRing(time))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
        .fixedSize()
        .background(sizeReporter)
        .contentShape(Capsule())
        .onTapGesture { onTap() }
        .gesture(dragGesture)
    }

    /// Onda de 0 a 1 con el periodo dado. Es la base de todo el movimiento.
    private func wave(_ time: TimeInterval, period: Double, offset: Double = 0) -> Double {
        0.5 + 0.5 * sin(2 * .pi * (time / period - offset))
    }

    // MARK: - Estados

    private func idleContent(_ time: TimeInterval) -> some View {
        HStack(spacing: Theme.pillGap) {
            GluffiMarkView(size: 17, color: Theme.brand)
            Text(model.idleWord)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .transition(.opacity)
                .id(model.idleWord)          // fuerza el cruce al cambiar
            Text("⌘⌥")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.38))
        }
        .animation(.easeInOut(duration: 0.45), value: model.idleWord)
    }

    private func recordingContent(_ time: TimeInterval) -> some View {
        let pulse = wave(time, period: 1.1)
        return HStack(spacing: Theme.pillGap) {
            // El logo sigue visible mientras graba: el estado lo comunica el
            // punto rojo y la onda, no la desaparición de la marca.
            GluffiMarkView(size: 17, color: Theme.brand)
            Circle()
                .fill(Theme.danger)
                .frame(width: 6, height: 6)
                .opacity(0.45 + 0.55 * pulse)
                .scaleEffect(0.82 + 0.18 * pulse)
            VoiceWaveView(time: time, level: model.micLevel)
            cancelButton
        }
    }

    private func processingContent(_ time: TimeInterval) -> some View {
        // Una vuelta cada 0.85 s, calculada desde el reloj: no hay animación que
        // pueda quedarse sin arrancar.
        let angle = (time / 0.85).truncatingRemainder(dividingBy: 1) * 360
        return HStack(spacing: Theme.pillGap) {
            ZStack {
                GluffiMarkView(size: 17, color: Theme.brand.opacity(0.55))
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(Theme.brand, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 21, height: 21)
                    .rotationEffect(.degrees(angle))
            }
            Text(model.processingLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
            cancelButton
        }
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Image(systemName: "xmark")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.55))
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Cancelar sin pegar (Esc)")
    }

    // MARK: - Fondo

    private var background: some View {
        Group {
            if model.state == .recording {
                // Grabando no se pone roja: el handoff lo pide explícitamente.
                // El estado se lee por el punto y la onda, no por un semáforo.
                LinearGradient(colors: [Color(red: 0.11, green: 0.13, blue: 0.086),
                                        Color(red: 0.06, green: 0.07, blue: 0.043)],
                               startPoint: .top, endPoint: .bottom)
            } else {
                Color(red: 20/255, green: 23/255, blue: 18/255).opacity(0.90)
            }
        }
    }

    /// Anillo que respira en reposo. No aparece en los otros estados: ahí ya hay
    /// movimiento y sumar otro sería ruido.
    @ViewBuilder
    private func breathRing(_ time: TimeInterval) -> some View {
        if model.state == .idle {
            Capsule()
                .stroke(Theme.brand.opacity(0.35 * wave(time, period: 3.4)), lineWidth: 3)
                .blur(radius: 3)
        }
    }

    private var sizeReporter: some View {
        GeometryReader { proxy in
            Color.clear
                .onAppear { onSizeChange(proxy.size) }
                .onChange(of: proxy.size) { onSizeChange($0) }
        }
    }

    // MARK: - Arrastre

    /// Un clic sin movimiento sigue siendo «grabar». Solo a partir de 4 px de
    /// desplazamiento acumulado se considera arrastre, así que un pulso torpe no
    /// mueve la píldora en vez de grabar.
    private var dragGesture: some Gesture {
        // El umbral de 4 px lo aplica minimumDistance: un pulso torpe sigue siendo
        // «grabar», no un arrastre de un píxel.
        DragGesture(minimumDistance: 4)
            .onChanged { _ in onDrag() }
            .onEnded { _ in onDragEnded() }
    }
}

/// Onda de voz: siete barras que crecen simétricamente desde el centro.
///
/// Cada barra es un halo translúcido con un núcleo sólido más estrecho, que es lo
/// que le da cuerpo sin necesidad de sombras.
struct VoiceWaveView: View {
    /// Reloj compartido con la píldora: así las barras nunca pierden la fase
    /// entre ellas ni respecto al resto del movimiento.
    var time: TimeInterval
    /// 0…1 del micrófono.
    var level: CGFloat

    /// Proporciones del handoff, escaladas a la altura de la píldora.
    private let ratios: [CGFloat] = [14, 20, 26, 30, 26, 20, 14].map { $0 / 30 }
    private let coreRatios: [CGFloat] = [6, 9, 11, 13, 11, 9, 6].map { $0 / 30 }
    private let offsets: [Double] = [0, 0.14, 0.28, 0.42, 0.28, 0.14, 0]

    private var maxHeight: CGFloat { Theme.waveMaxHeight }

    /// Cuánto de la altura la decide la voz.
    ///
    /// La curva de 0.6 levanta la zona media: la voz de conversación se queda
    /// alrededor de un tercio de la escala y sin ella el movimiento se notaba
    /// apenas. El piso de 0.22 es lo que late en silencio.
    private var envelope: CGFloat {
        let curved = pow(max(0, min(1, level)), 0.6)
        return 0.22 + 0.78 * curved
    }

    /// Con voz, el vaivén solo da textura —la altura la manda el micrófono—; en
    /// silencio recupera todo el recorrido para que la onda siga viva.
    private var shapeDepth: CGFloat {
        level > 0.06 ? 0.30 : 0.62
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ratios.indices, id: \.self) { i in
                bar(index: i)
            }
        }
        // Altura fija: subir el volumen no puede hacer crecer la onda por encima
        // de la píldora.
        .frame(height: maxHeight)
    }

    private func bar(index: Int) -> some View {
        let vaiven = 0.5 + 0.5 * sin(2 * .pi * (time / 1.25 - offsets[index]))
        let shape = (1 - shapeDepth) + shapeDepth * CGFloat(vaiven)
        let scale = shape * envelope
        let full = maxHeight * ratios[index] * scale
        let core = maxHeight * coreRatios[index] * scale
        return ZStack {
            Capsule().fill(Theme.brand.opacity(0.28)).frame(width: 4, height: full)
            Capsule().fill(Theme.brand).frame(width: 4, height: max(core, 2))
        }
        .frame(width: 4, height: maxHeight)
    }
}
