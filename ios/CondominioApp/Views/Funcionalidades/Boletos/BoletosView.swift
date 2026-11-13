import SwiftUI

@Observable
@MainActor
final class BoletosViewModel {
    enum Filtro: String, CaseIterable, Identifiable {
        case emAberto = "Em aberto"
        case pagos = "Pagos"
        case todos = "Todos"
        var id: String { rawValue }
    }

    var boletos: [Boleto] = []
    var filtro: Filtro = .emAberto
    var carregando = false
    var jaCarregou = false
    var erro: String?

    var filtrados: [Boleto] {
        switch filtro {
        case .emAberto: boletos.filter { !$0.estaPago }
        case .pagos: boletos.filter(\.estaPago)
        case .todos: boletos
        }
    }

    var totalEmAberto: Double {
        boletos.filter { !$0.estaPago }.reduce(0) { $0 + $1.valor }
    }

    var quantidadeEmAberto: Int {
        boletos.filter { !$0.estaPago }.count
    }

    var variosMoradores: Bool {
        Set(boletos.compactMap(\.moradorNome)).count > 1
    }

    func carregar() async {
        carregando = true
        erro = nil
        defer {
            carregando = false
            jaCarregou = true
        }
        do {
            boletos = try await APIService.shared.boletos().boletos
        } catch {
            self.erro = error.localizedDescription
        }
    }

    func gerarBoletosDeExemplo() async {
        carregando = true
        erro = nil
        do {
            try await APIService.shared.gerarBoletosDemo()
            carregando = false
            await carregar()
        } catch {
            carregando = false
            self.erro = error.localizedDescription
        }
    }
}

struct BoletosView: View {
    @State private var vm = BoletosViewModel()

    var body: some View {
        List {
            if !vm.boletos.isEmpty {
                Section {
                    ResumoBoletosCard(total: vm.totalEmAberto, quantidade: vm.quantidadeEmAberto)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                Section {
                    Picker("Filtro", selection: $vm.filtro) {
                        ForEach(BoletosViewModel.Filtro.allCases) { filtro in
                            Text(filtro.rawValue).tag(filtro)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                Section {
                    if vm.filtrados.isEmpty {
                        Text(vm.filtro == .emAberto ? "Nenhum boleto em aberto. Tudo em dia!" : "Nenhum boleto aqui.")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    ForEach(vm.filtrados) { boleto in
                        NavigationLink {
                            BoletoDetalheView(boleto: boleto)
                        } label: {
                            BoletoLinha(boleto: boleto, mostrarMorador: vm.variosMoradores)
                        }
                    }
                }
                .listRowBackground(AppColors.card)
            }
        }
        .telaPadrao()
        .navigationTitle("Boletos").barraMarca()
        .overlay {
            if vm.boletos.isEmpty {
                if vm.carregando || !vm.jaCarregou {
                    ProgressView("Buscando boletos…")
                } else if let erro = vm.erro {
                    ContentUnavailableView {
                        Label("Não foi possível carregar", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(erro)
                    } actions: {
                        Button("Tentar de novo") { Task { await vm.carregar() } }
                            .buttonStyle(.borderedProminent).sombraSutil()
                    }
                } else {
                    ContentUnavailableView {
                        Label("Nenhum boleto", systemImage: "doc.text")
                    } description: {
                        Text("Quando a administração emitir seus boletos, eles aparecem aqui.")
                    } actions: {
                        Button("Gerar boletos de exemplo") { Task { await vm.gerarBoletosDeExemplo() } }
                            .buttonStyle(.bordered).sombraSutil()
                    }
                }
            }
        }
        .task {
            if !vm.jaCarregou { await vm.carregar() }
        }
        .refreshable { await vm.carregar() }
    }
}

private struct ResumoBoletosCard: View {
    let total: Double
    let quantidade: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Total em aberto", systemImage: "doc.text.fill")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text(total.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR"))))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(quantidade == 0 ? "Nenhum boleto pendente"
                 : quantidade == 1 ? "1 boleto pendente" : "\(quantidade) boletos pendentes")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(AppColors.accent.gradient, in: RoundedRectangle(cornerRadius: AppTheme.raio, style: .continuous))
    }
}

struct BoletoLinha: View {
    let boleto: Boleto
    var mostrarMorador = false

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.text.fill")
                .font(.title3)
                .foregroundStyle(boleto.situacao.cor)
                .frame(width: 40, height: 40)
                .background(boleto.situacao.cor.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(boleto.competenciaFormatada)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                Text(boleto.estaPago ? "Pago em \(boleto.pagoEmFormatado ?? "-")" : "Vence em \(boleto.vencimentoFormatado)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                if mostrarMorador, let nome = boleto.moradorNome {
                    Text([nome, boleto.unidade].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(boleto.valorFormatado)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                StatusBoletoBadge(situacao: boleto.situacao)
            }
        }
        .padding(.vertical, 4)
    }
}

struct StatusBoletoBadge: View {
    let situacao: Boleto.Situacao

    var body: some View {
        Text(situacao.titulo)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(situacao.cor)
            .background(situacao.cor.opacity(0.15), in: Capsule())
    }
}

#Preview("Boletos") {
    APIConfig.usarMock = true
    return NavigationStack {
        BoletosView()
    }
}
