import SwiftUI
import UIKit

struct ContatosView: View {
    @Environment(AppSession.self) private var session
    @State private var vm = ContatosViewModel()
    @State private var numeroSemLigacao: String?

    var body: some View {
        List {
            if session.usuario.perfil != .sindico {
                Section {
                    LigarSindicoButton()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
            }
            Section {
                ForEach(vm.contatos) { contato in
                    linha(contato)
                }
                .listRowBackground(AppColors.card)
            }
        }
        .telaPadrao()
        .navigationTitle("Contatos").barraMarca()
        .overlay {
            if vm.contatos.isEmpty {
                if vm.carregando || !vm.jaCarregou {
                    ProgressView()
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
                    ContentUnavailableView("Nenhum contato cadastrado", systemImage: "phone.badge.waveform")
                }
            }
        }
        .task {
            if !vm.jaCarregou { await vm.carregar() }
        }
        .refreshable { await vm.carregar() }
        .alert("Não foi possível ligar daqui", isPresented: Binding(
            get: { numeroSemLigacao != nil },
            set: { if !$0 { numeroSemLigacao = nil } }
        )) {
            Button("Copiar número") { UIPasteboard.general.string = numeroSemLigacao }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Este aparelho não faz ligações (no Simulador isso é normal). Número: \(numeroSemLigacao ?? "")")
        }
    }

    private func linha(_ contato: ContatoCondominio) -> some View {
        let souEu = contato.id == session.usuario.id
        return HStack(spacing: 14) {
            Image(systemName: contato.icone)
                .font(.title2)
                .foregroundStyle(AppColors.accent)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(contato.nome).font(.headline).foregroundStyle(AppColors.textPrimary)
                Text(contato.cargo).font(.subheadline).foregroundStyle(AppColors.textSecondary)
                if let telefone = contato.telefone, souEu {
                    Text(telefone).font(.caption).foregroundStyle(AppColors.textSecondary)
                } else if let telefone = contato.telefone {
                    Button(telefone) { ligar(telefone) }
                        .font(.caption)
                        .buttonStyle(.borderless)
                } else {
                    Text("Sem telefone cadastrado").font(.caption).foregroundStyle(AppColors.textSecondary)
                }
            }

            Spacer()

            if souEu {
                Text("Você")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .foregroundStyle(AppColors.accent)
                    .background(AppColors.accent.opacity(0.15), in: Capsule())
            } else if let telefone = contato.telefone {
                Button { ligar(telefone) } label: {
                    Image(systemName: "phone.fill")
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.green, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Ligar para \(contato.nome)")
            }
        }
        .padding(.vertical, 4)
    }

    private func ligar(_ telefone: String) {
        Task {
            if !(await Ligacao.ligar(para: telefone)) {
                numeroSemLigacao = telefone
            }
        }
    }
}

#Preview("Contatos") {
    APIConfig.usarMock = true
    return NavigationStack {
        ContatosView()
    }
    .environment(AppSession())
}
