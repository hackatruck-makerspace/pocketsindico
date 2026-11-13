import SwiftUI

struct OcorrenciaDetalheView: View {
    @Environment(AppSession.self) private var session
    let store: OcorrenciasStore
    let ocorrenciaId: String

    @State private var copia: Ocorrencia?
    @State private var mostrarFormulario = false

    private var o: Ocorrencia? { store.atual(ocorrenciaId) ?? copia }
    private var ehSindico: Bool { session.usuario.perfil == .sindico }

    var body: some View {
        if let o {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    cabecalho(o)
                    if ehSindico { remetente(o) }
                    motivo(o)
                    if let r = o.resposta { resposta(r) }
                    if !o.historico.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Histórico").font(.headline).foregroundStyle(AppColors.textPrimary)
                            HistoricoOcorrenciaView(eventos: o.historico)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cartao()
                    }
                    if ehSindico {
                        if o.respondida && !mostrarFormulario {
                            Button { withAnimation { mostrarFormulario = true } } label: {
                                Label("Enviar nova resposta", systemImage: "arrowshape.turn.up.left").frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered).sombraSutil()
                            .controlSize(.large)
                        } else {
                            ResponderOcorrenciaForm(ocorrencia: o) { atualizada in
                                store.substituir(atualizada)
                                copia = atualizada
                                withAnimation { mostrarFormulario = false }
                            }
                        }
                    }
                }
                .padding()
            }
            .telaPadrao()
            .navigationTitle("Ocorrência").barraMarca()
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { copia = o }
            .task { if ehSindico { await store.marcarRecebida(ocorrenciaId) } }
        } else {
            EmptyStateView(icone: "exclamationmark.bubble", texto: "Ocorrência não encontrada.")
                .frame(maxHeight: .infinity).telaPadrao()
        }
    }

    private func cabecalho(_ o: Ocorrencia) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                CategoriaOcorrenciaPill(categoria: o.categoriaEnum)
                StatusOcorrenciaPill(ocorrencia: o)
            }
            Text(o.titulo)
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            HStack(alignment: .top, spacing: 24) {
                if let d = DataHoraLinhas(iso: o.criadoEm, titulo: "Enviada") { d }
                if let d = DataHoraLinhas(iso: o.recebidaEm, titulo: "Recebida pelo síndico") { d }
            }
        }
    }

    private func remetente(_ o: Ocorrencia) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Enviada por", systemImage: "person.crop.circle.fill")
                .font(.headline).foregroundStyle(AppColors.textPrimary)
            LinhaDetalhe(titulo: "Nome", valor: o.autorNome)
            HStack(spacing: 24) {
                LinhaDetalhe(titulo: "Bloco", valor: o.bloco ?? "—")
                LinhaDetalhe(titulo: "Apartamento", valor: o.apartamento ?? "—")
            }
            if o.autorPerfil == "guarda" {
                Text("Enviada pela portaria").font(.caption).foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    private func motivo(_ o: Ocorrencia) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Motivo da reclamação").font(.headline).foregroundStyle(AppColors.textPrimary)
            Text(o.descricao)
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
            if let local = o.local {
                Label(local, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            if let foto = o.foto { FotoDetalhe(foto: foto, altura: 200) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }

    private func resposta(_ r: RespostaDoSindico) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(r.ehLembrete ? "Lembrete de convivência enviado" : "Resposta do síndico",
                  systemImage: r.ehLembrete ? "bell.badge.fill" : "checkmark.bubble.fill")
                .font(.headline)
                .foregroundStyle(.green)
            Text(r.texto)
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
            if r.ehLembrete, let u = r.unidadeEnvolvida, ehSindico {
                Text("Unidade envolvida: \(u)").font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            if r.ehLembrete, let msg = r.mensagemLembrete, ehSindico {
                Text("Mensagem do lembrete:").font(.caption.weight(.semibold)).foregroundStyle(AppColors.textSecondary)
                Text(msg).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            HStack(alignment: .bottom) {
                if let quem = r.autorNome { Text(quem).font(.caption).foregroundStyle(AppColors.textSecondary) }
                Spacer()
                if let d = DataHoraLinhas(iso: r.respondidoEm) { d }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: AppTheme.raio, style: .continuous))
    }
}

struct ResponderOcorrenciaForm: View {
    let ocorrencia: Ocorrencia
    var aoResponder: (Ocorrencia) -> Void

    @Environment(AppSession.self) private var session
    @State private var tipo: TipoRespostaOcorrencia = .resposta
    @State private var texto = ""
    @State private var bloco = ""
    @State private var apartamento = ""
    @State private var mensagemLembrete = Alerta.mensagemPadrao
    @State private var enviando = false
    @State private var erro: String?
    @State private var envioID = UUID()

    private var invalido: Bool {
        let semTexto = texto.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if tipo == .lembrete {
            return semTexto || bloco.trimmingCharacters(in: .whitespaces).isEmpty || apartamento.trimmingCharacters(in: .whitespaces).isEmpty
                || mensagemLembrete.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return semTexto
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(ocorrencia.respondida ? "Nova resposta" : "Responder ao morador", systemImage: "square.and.pencil")
                .font(.headline).foregroundStyle(AppColors.textPrimary)

            Picker("Tipo", selection: $tipo) {
                ForEach(TipoRespostaOcorrencia.allCases) { Text($0 == .lembrete ? "Lembrete" : "Resposta").tag($0) }
            }
            .pickerStyle(.segmented)

            campoTexto("Resposta para \(ocorrencia.autorNome)", texto: $texto,
                       dica: tipo == .lembrete ? "Ex.: Enviamos um lembrete cordial à unidade envolvida." : "Ex.: Obrigado pelo aviso. A manutenção vai verificar amanhã.")

            if tipo == .lembrete {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unidade envolvida").font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                    HStack {
                        TextField("Bloco", text: $bloco)
                            .textInputAutocapitalization(.characters)
                            .padding(10).background(AppColors.background, in: RoundedRectangle(cornerRadius: 10))
                        TextField("Apartamento", text: $apartamento)
                            .keyboardType(.numberPad)
                            .padding(10).background(AppColors.background, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                campoTexto("Mensagem do lembrete", texto: $mensagemLembrete, dica: "")
                Text("O lembrete não tem caráter punitivo. O morador da unidade recebe a mensagem em tela cheia e confirma a leitura.")
                    .font(.caption).foregroundStyle(AppColors.textSecondary)
            }

            if let erro { Text(erro).font(.footnote).foregroundStyle(.red) }

            Button {
                Task { await enviar() }
            } label: {
                HStack {
                    if enviando { ProgressView().tint(.white) }
                    Text(tipo == .lembrete ? "Enviar lembrete e responder" : "Enviar resposta").bold()
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).sombraSutil()
            .controlSize(.large)
            .disabled(invalido || enviando)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
        .onChange(of: tipo) { _, novo in
            if novo == .lembrete && texto.isEmpty { texto = "Olá, \(primeiroNome)! Enviamos um lembrete de convivência à unidade envolvida. Obrigado por avisar." }
        }
    }

    private var primeiroNome: String { ocorrencia.autorNome.split(separator: " ").first.map(String.init) ?? ocorrencia.autorNome }

    private func campoTexto(_ titulo: String, texto: Binding<String>, dica: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titulo).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
            ZStack(alignment: .topLeading) {
                if texto.wrappedValue.isEmpty && !dica.isEmpty {
                    Text(dica).foregroundStyle(AppColors.textSecondary.opacity(0.7)).padding(.horizontal, 14).padding(.vertical, 16)
                }
                TextEditor(text: texto)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(8)
            }
            .background(AppColors.background, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private func enviar() async {
        enviando = true
        erro = nil
        defer { enviando = false }
        let unidade = tipo == .lembrete ? "Bloco \(bloco.trimmingCharacters(in: .whitespaces).uppercased()) · Apto \(apartamento.trimmingCharacters(in: .whitespaces))" : nil
        do {
            let atualizada = try await APIService.shared.responderOcorrencia(
                id: ocorrencia.id, tipo: tipo, texto: texto, unidadeEnvolvida: unidade,
                mensagemLembrete: tipo == .lembrete ? mensagemLembrete : nil)
            if tipo == .lembrete && APIConfig.alertasDemo {
                _ = await session.alertas.enviarLembrete(usuario: session.usuario, bloco: bloco, apartamento: apartamento,
                                                         mensagem: mensagemLembrete, ocorrenciaRef: ocorrencia.id, envioID: envioID)
            }
            envioID = UUID()
            texto = ""
            aoResponder(atualizada)
        } catch {
            self.erro = error.localizedDescription
        }
    }
}
