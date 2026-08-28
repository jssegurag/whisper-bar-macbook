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
    /// Desplazamiento acumulado del arrastre, en coordenadas de pantalla.
    var onDrag: (CGSize) -> Void = { _ in }
    var onDragEnded: () -> Void = {}
    /// Tamaño real del contenido, para que el panel se ajuste.
    var onSizeChange: (CGSize) -> Void = { _ in }

    @State private var breathing = false
    @State private var spin = false
    @State private var dragDistance: CGFloat = 0

    private let height: CGFloat = 46

    var body: some View {
        HStack(spacing: 11) {
            switch model.state {
            case .idle:        idleContent
            case .recording:   recordingContent
            case .transcribing: processingContent
            }
        }
        .padding(.horizontal, 16)
        .frame(height: height)
        .background(background)
        .overlay(
            Capsule().stroke(Theme.brand.opacity(0.4), lineWidth: 1)
        )
        .overlay(breathRing)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 8)
        .fixedSize()
        .background(sizeReporter)
        .contentShape(Capsule())
        .onTapGesture { onTap() }
        .gesture(dragGesture)
        .onAppear {
            breathing = true
            spin = true
        }
    }

    // MARK: - Estados

    private var idleContent: some View {
        HStack(spacing: 11) {
            GluffiMarkView(size: 20, color: Theme.brand)
            Text(model.idleWord)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.92))
                .transition(.opacity)
                .id(model.idleWord)          // fuerza el cruce al cambiar
            Text("⌘⌥")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.38))
        }
        .animation(.easeInOut(duration: 0.45), value: model.idleWord)
    }

    private var recordingContent: some View {
        HStack(spacing: 11) {
            // El logo sigue visible mientras graba: el estado lo comunica el
            // punto rojo y la onda, no la desaparición de la marca.
            GluffiMarkView(size: 20, color: Theme.brand)
            Circle()
                .fill(Theme.danger)
                .frame(width: 6, height: 6)
                .opacity(breathing ? 0.45 : 1)
                .scaleEffect(breathing ? 0.82 : 1)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: breathing)
            VoiceWaveView(level: model.micLevel)
            cancelButton
        }
    }

    private var processingContent: some View {
        HStack(spacing: 11) {
            ZStack {
                GluffiMarkView(size: 20, color: Theme.brand.opacity(0.55))
                Circle()
                    .trim(from: 0, to: 0.22)
                    .stroke(Theme.brand, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 0.85).repeatForever(autoreverses: false), value: spin)
            }
            Text(model.processingLabel)
                .font(.system(size: 13.5, weight: .semibold))
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
    private var breathRing: some View {
        if model.state == .idle {
            Capsule()
                .stroke(Theme.brand.opacity(breathing ? 0.35 : 0.0), lineWidth: 3)
                .blur(radius: 3)
                .animation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true), value: breathing)
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
        DragGesture(minimumDistance: 4, coordinateSpace: .global)
            .onChanged { value in
                dragDistance = abs(value.translation.width) + abs(value.translation.height)
                onDrag(value.translation)
            }
            .onEnded { _ in
                dragDistance = 0
                onDragEnded()
            }
    }
}

/// Onda de voz: siete barras que crecen simétricamente desde el centro.
///
/// Cada barra es un halo translúcido con un núcleo sólido más estrecho, que es lo
/// que le da cuerpo sin necesidad de sombras.
struct VoiceWaveView: View {
    /// 0…1 del micrófono. Con señal la altura la manda la voz; sin señal queda la
    /// animación como respaldo, para que la píldora no parezca congelada.
    var level: CGFloat

    private let heights: [CGFloat] = [14, 20, 26, 30, 26, 20, 14]
    private let cores:   [CGFloat] = [6, 9, 11, 13, 11, 9, 6]
    private let offsets: [Double]  = [0, 0.14, 0.28, 0.42, 0.28, 0.14, 0]

    @State private var animating = false

    var body: some View {
        HStack(spacing: 4) {
            ForEach(heights.indices, id: \.self) { i in
                bar(index: i)
            }
        }
        .frame(height: 30)
        .onAppear { animating = true }
    }

    private func bar(index: Int) -> some View {
        let amplitude = max(0.25, level)
        let full = heights[index]
        let core = cores[index]
        return ZStack {
            Capsule()
                .fill(Theme.brand.opacity(0.28))
                .frame(width: 5, height: full)
            Capsule()
                .fill(Theme.brand)
                .frame(width: 5, height: core)
        }
        .scaleEffect(y: animating ? amplitude : 0.38, anchor: .center)
        .animation(
            .easeInOut(duration: 1.25)
                .repeatForever(autoreverses: true)
                .delay(offsets[index]),
            value: animating)
        .animation(.easeOut(duration: 0.12), value: level)
    }
}
