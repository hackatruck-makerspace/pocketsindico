import SwiftUI

struct AlertaConvivenciaView: View {
    let alertaID: UUID
    @Environment(AppSession.self) private var session
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduzirMovimento
    @State private var apareceu = false
    private let petroleo = Color(red: 0.035, green: 0.19, blue: 0.23)
    private var store: AlertaViewModel { session.alertas }
    private var alerta: Alerta? { store.visiveis(para: session.usuario).first { $0.id == alertaID } }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let alerta, store.podeLer(alerta, usuario: session.usuario) {
                    Image(systemName: "bell.fill").font(.system(size: 48))
                        .foregroundStyle(Color.cyan.opacity(0.85)).accessibilityHidden(true)
                    Text(alerta.titulo).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text("Data: \(DataHora.dia(alerta.criadoEm))   Horário: \(DataHora.hora(alerta.criadoEm))")
                        .font(.footnote).foregroundStyle(.white.opacity(0.8))
                    VStack(alignment: .leading, spacing: 20) {
                        Text(alerta.mensagem).font(.body).lineSpacing(5)
                        Text(Alerta.rodape).font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(24)
                    .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: AppTheme.raio))
                    Text("Confirmar a leitura significa apenas ciência da mensagem, nunca admissão de responsabilidade.")
                        .font(.footnote).foregroundStyle(.white.opacity(0.85))
                    if alerta.status != .lido {
                        Button {
                            if store.ler(alerta.id, usuario: session.usuario) { dismiss() }
                        } label: { Text("Li e entendi").bold().frame(maxWidth: .infinity).padding(8) }
                        .buttonStyle(.borderedProminent).sombraSutil().tint(AppColors.accent)
                        Button("Lembrar depois (10 min)") {
                            Task { @MainActor in
                                if await store.adiar(alerta.id, usuario: session.usuario) { dismiss() }
                            }
                        }.buttonStyle(.bordered).sombraSutil().tint(.white)
                    } else if let data = alerta.lidoEm {
                        VStack(spacing: 4) {
                            Label("Leitura confirmada", systemImage: "checkmark.circle.fill")
                            Text("Data: \(DataHora.dia(data))   Horário: \(DataHora.hora(data))").font(.footnote)
                        }
                    }
                    if let erro = store.erro { Text(erro).font(.footnote) }
                    Button("Voltar sem alterar leitura") { store.aberto = nil; dismiss() }
                        .font(.footnote).underline()
                } else {
                    Text("Mensagem indisponível neste perfil.")
                    Button("Voltar") { dismiss() }
                }
            }
            .padding(24).frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .opacity(apareceu ? 1 : 0)
            .disabled(store.ocupado)
        }
        .foregroundStyle(.white)
        .background(petroleo.ignoresSafeArea())
        .interactiveDismissDisabled()
        .onAppear { withAnimation(reduzirMovimento ? nil : .easeOut(duration: 0.3)) { apareceu = true } }
    }
}
