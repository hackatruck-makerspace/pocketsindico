import SwiftUI

@Observable
@MainActor
final class OcorrenciasStore {
    var itens: [Ocorrencia] = []
    var carregando = false
    var jaCarregou = false
    var erro: String?

    var aguardando: [Ocorrencia] { itens.filter { !$0.recebido } }
    var recebidas: [Ocorrencia] {
        itens.filter(\.recebido).sorted { $0.dataUltimaEtapa > $1.dataUltimaEtapa }
    }

    func carregar() async {
        carregando = true
        erro = nil
        defer { carregando = false; jaCarregou = true }
        do { itens = try await APIService.shared.ocorrencias() }
        catch is CancellationError {}
        catch let e as URLError where e.code == .cancelled {}
        catch { erro = error.localizedDescription }
    }

    func atualizarEmSegundoPlano() async {
        guard !carregando, let novos = try? await APIService.shared.ocorrencias() else { return }
        itens = novos
    }

    func marcarRecebida(_ id: String) async {
        guard let o = atual(id), !o.recebido else { return }
        if let atualizada = try? await APIService.shared.receberOcorrencia(id: id) { substituir(atualizada) }
    }

    func substituir(_ o: Ocorrencia) {
        if let i = itens.firstIndex(where: { $0.id == o.id }) { itens[i] = o } else { itens.insert(o, at: 0) }
    }

    func atual(_ id: String) -> Ocorrencia? { itens.first { $0.id == id } }
}

struct OcorrenciaRota: Hashable { let id: String }

struct OcorrenciasView: View {
    @Environment(AppSession.self) private var session
    @State private var store = OcorrenciasStore()

    var body: some View {
        Group {
            if session.usuario.perfil == .sindico {
                OcorrenciasSindicoView(store: store)
            } else {
                MinhasOcorrenciasView(store: store)
            }
        }
        .task(id: session.usuario.id) { await store.carregar() }
        .navigationDestination(for: OcorrenciaRota.self) { rota in
            OcorrenciaDetalheView(store: store, ocorrenciaId: rota.id)
        }
    }
}

enum EtapaOcorrencia {
    static func cor(_ status: String) -> Color {
        switch status {
        case "respondida": .green
        case "recebida": AppColors.accent
        default: .orange
        }
    }
    static func icone(_ status: String) -> String {
        switch status {
        case "respondida": "checkmark.bubble.fill"
        case "recebida": "tray.and.arrow.down.fill"
        default: "clock.fill"
        }
    }
}

struct StatusOcorrenciaPill: View {
    let ocorrencia: Ocorrencia
    var body: some View {
        PilulaInfo(texto: ocorrencia.statusTitulo, icone: EtapaOcorrencia.icone(ocorrencia.status), cor: EtapaOcorrencia.cor(ocorrencia.status))
    }
}

enum AbaOcorrencias: String, CaseIterable, Identifiable {
    case aguardando = "Aguardando", recebido = "Recebido"
    var id: String { rawValue }
}

struct SeletorAbasOcorrencias: View {
    @Binding var aba: AbaOcorrencias
    let store: OcorrenciasStore
    var body: some View {
        Picker("Aba", selection: $aba) {
            Text("Aguardando (\(store.aguardando.count))").tag(AbaOcorrencias.aguardando)
            Text("Recebido (\(store.recebidas.count))").tag(AbaOcorrencias.recebido)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
}

struct ListaOcorrencias: View {
    let store: OcorrenciasStore
    let itens: [Ocorrencia]
    let vazio: String
    let icone: String
    var mostrarAutor = false

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if let erro = store.erro, store.itens.isEmpty {
                    EmptyStateView(icone: "wifi.exclamationmark", texto: "Não foi possível carregar.\n\(erro)")
                } else if store.jaCarregou && itens.isEmpty {
                    EmptyStateView(icone: icone, texto: vazio)
                }
                ForEach(itens) { o in
                    NavigationLink(value: OcorrenciaRota(id: o.id)) {
                        OcorrenciaCard(ocorrencia: o, mostrarAutor: mostrarAutor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .contentMargins(.bottom, 80, for: .scrollContent)
        .refreshable { await store.carregar() }
    }
}

struct CategoriaOcorrenciaPill: View {
    let categoria: CategoriaOcorrencia
    var body: some View { PilulaInfo(texto: categoria.titulo, icone: categoria.icone, cor: categoria.cor) }
}

struct OcorrenciaCard: View {
    let ocorrencia: Ocorrencia
    var mostrarAutor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                CategoriaOcorrenciaPill(categoria: ocorrencia.categoriaEnum)
                Spacer(minLength: 4)
                StatusOcorrenciaPill(ocorrencia: ocorrencia)
            }
            Text(ocorrencia.titulo)
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)
            Text(ocorrencia.descricao)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
            HStack(alignment: .bottom) {
                if mostrarAutor {
                    Label("\(ocorrencia.autorNome) · \(ocorrencia.unidade)", systemImage: "person.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if let d = DataHoraLinhas(iso: ocorrencia.criadoEm) { d }
            }
            if ocorrencia.foto != nil {
                Label("Com foto", systemImage: "photo").font(.caption2).foregroundStyle(AppColors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cartao()
    }
}

struct HistoricoOcorrenciaView: View {
    let eventos: [EventoOcorrencia]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(eventos.enumerated()), id: \.offset) { i, e in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(EtapaOcorrencia.cor(e.status))
                            .frame(width: 12, height: 12)
                            .padding(.top, 4)
                        if i < eventos.count - 1 {
                            Rectangle().fill(AppColors.textSecondary.opacity(0.3)).frame(width: 2).frame(minHeight: 30)
                        }
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(e.descricao).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                        if let quem = e.autorNome { Text(quem).font(.caption).foregroundStyle(AppColors.textSecondary) }
                        if let d = DataHoraLinhas(iso: e.em) { d }
                    }
                    .padding(.bottom, 12)
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
