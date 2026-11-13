import SwiftUI

@MainActor
@Observable
final class AlertaViewModel {
    private(set) var dados = DadosAlertasDemo()
    private(set) var ocupado = false
    private(set) var erro: String?
    private(set) var feedback: String?
    var aberto: Alerta?
    var avisoRoteamento: String?
    private var falhaCarregamento = false
    private var jaExibidos: Set<UUID> = []
    private let persistence: AlertaPersistence
    let notificacoes: NotificationService

    init(persistence: AlertaPersistence = AlertaPersistence(), notificacoes: NotificationService = .shared) {
        self.persistence = persistence
        self.notificacoes = notificacoes
        do { dados = try persistence.carregar() }
        catch { falhaCarregamento = true; erro = "Não foi possível carregar os alertas. Os dados não foram sobrescritos. \(error.localizedDescription)" }
    }

    private func ehDestinatario(_ alerta: Alerta, _ usuario: Usuario) -> Bool {
        usuario.perfil == .morador && usuario.bloco == alerta.blocoEfetivo && usuario.apartamento == alerta.unidadeDestino
    }

    func visiveis(para usuario: Usuario) -> [Alerta] {
        guard APIConfig.alertasDemo else { return [] }
        return dados.alertas.filter { usuario.perfil == .sindico || ehDestinatario($0, usuario) }
            .sorted { $0.criadoEm > $1.criadoEm }
    }

    func podeLer(_ alerta: Alerta, usuario: Usuario) -> Bool {
        APIConfig.alertasDemo && ehDestinatario(alerta, usuario)
    }

    func limparFeedback() { feedback = nil; if !falhaCarregamento { erro = nil } }

    @discardableResult
    private func salvar(_ novos: DadosAlertasDemo, redefinir: Bool = false) -> Bool {
        guard !falhaCarregamento || redefinir else { return false }
        do {
            try persistence.salvar(novos)
            dados = novos; erro = nil; falhaCarregamento = false
            return true
        } catch { erro = "Não foi possível salvar. Tente novamente. \(error.localizedDescription)"; return false }
    }

    func enviarLembrete(usuario: Usuario, bloco: String, apartamento: String, mensagem: String,
                        ocorrenciaRef: String?, envioID: UUID) async -> Bool {
        let b = bloco.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let a = apartamento.trimmingCharacters(in: .whitespacesAndNewlines)
        let texto = mensagem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !ocupado, APIConfig.alertasDemo, usuario.perfil == .sindico, !b.isEmpty, !a.isEmpty, !texto.isEmpty else {
            erro = "Informe bloco, apartamento e a mensagem do lembrete."; return false
        }
        if dados.alertas.contains(where: { $0.envioID == envioID }) { return true }
        ocupado = true
        defer { ocupado = false }
        let alerta = Alerta(id: UUID(), ocorrenciaID: UUID(), unidadeDestino: a, titulo: Alerta.tituloPadrao, mensagem: texto,
                            criadoEm: Date(), envioID: envioID, blocoDestino: b, ocorrenciaRef: ocorrenciaRef)
        var novos = dados; novos.alertas.append(alerta)
        guard salvar(novos) else { return false }
        feedback = "Lembrete enviado à unidade \(alerta.unidadeDescricao)."
        do {
            let agendada = try await notificacoes.agendar(alerta, em: Date().addingTimeInterval(5))
            if !agendada { feedback = "Lembrete salvo. Notificações desativadas; ele aparece quando o morador abrir o app." }
        } catch { feedback = "Lembrete salvo, mas a notificação não pôde ser agendada: \(error.localizedDescription)" }
        return true
    }

    func ler(_ id: UUID, usuario: Usuario) -> Bool {
        guard !ocupado, let i = dados.alertas.firstIndex(where: { $0.id == id }), podeLer(dados.alertas[i], usuario: usuario) else { return false }
        if dados.alertas[i].status == .lido { aberto = nil; return true }
        var novos = dados
        novos.alertas[i].status = .lido; novos.alertas[i].lidoEm = Date(); novos.alertas[i].adiadoAte = nil
        guard salvar(novos) else { return false }
        notificacoes.cancelar([id]); aberto = nil
        return true
    }

    func adiar(_ id: UUID, usuario: Usuario) async -> Bool {
        guard !ocupado, let i = dados.alertas.firstIndex(where: { $0.id == id }),
              podeLer(dados.alertas[i], usuario: usuario), dados.alertas[i].status != .lido else { return false }
        ocupado = true
        defer { ocupado = false }
        var novos = dados
        let prazo = Date().addingTimeInterval(600)
        novos.alertas[i].status = .adiado; novos.alertas[i].adiadoAte = prazo
        guard salvar(novos) else { return false }
        notificacoes.cancelar([id])
        do {
            let agendada = try await notificacoes.agendar(novos.alertas[i], em: prazo)
            feedback = agendada ? "Lembrete adiado por 10 minutos." : "Adiado por 10 minutos. Sem permissão de notificação, o lembrete reaparece dentro do app."
        } catch { feedback = "Adiado. A notificação falhou; o lembrete continua no app." }
        aberto = nil
        return true
    }

    func atualizar(usuario: Usuario) {
        guard APIConfig.alertasDemo else { aberto = nil; notificacoes.unidadeAtiva = nil; return }
        if usuario.perfil == .morador, let b = usuario.bloco, let a = usuario.apartamento {
            notificacoes.unidadeAtiva = "\(b)-\(a)"
        } else {
            notificacoes.unidadeAtiva = nil
        }
        if let aberto, !podeLer(aberto, usuario: usuario) { self.aberto = nil }
        guard !ocupado else { return }
        var novos = dados
        let vencidos = novos.alertas.indices.filter {
            novos.alertas[$0].status == .adiado && (novos.alertas[$0].adiadoAte ?? .distantFuture) <= Date()
        }
        if !vencidos.isEmpty {
            for i in vencidos {
                novos.alertas[i].status = .pendente; novos.alertas[i].adiadoAte = nil
                jaExibidos.remove(novos.alertas[i].id)
            }
            salvar(novos)
        }
        if aberto == nil, let pendente = dados.alertas
            .filter({ $0.status == .pendente && !jaExibidos.contains($0.id) && podeLer($0, usuario: usuario) })
            .sorted(by: { $0.criadoEm < $1.criadoEm }).first {
            jaExibidos.insert(pendente.id)
            aberto = pendente
        }
        if let id = notificacoes.alertaSolicitado {
            guard let alerta = dados.alertas.first(where: { $0.id == id }) else {
                notificacoes.alertaSolicitado = nil; return
            }
            if podeLer(alerta, usuario: usuario) {
                aberto = alerta; notificacoes.alertaSolicitado = nil; avisoRoteamento = nil
            } else {
                avisoRoteamento = "A notificação pertence a outro perfil de teste. Troque para o morador destinatário para abrir a mensagem."
            }
        }
    }

    func redefinir() {
        guard APIConfig.alertasDemo, !ocupado else { return }
        let ids = dados.alertas.map(\.id)
        guard salvar(DadosAlertasDemo(), redefinir: true) else { return }
        notificacoes.cancelar(ids); notificacoes.alertaSolicitado = nil
        aberto = nil; feedback = nil; avisoRoteamento = nil; jaExibidos = []
    }
}
