import SwiftUI
import UIKit

struct LigarSindicoButton: View {
    @State private var vm = ContatosViewModel()
    @State private var numeroSemLigacao: String?

    var body: some View {
        Button {
            Task { await ligar() }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.green, in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ligar para o síndico")
                        .font(.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Text(subtitulo)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if vm.carregando {
                    ProgressView()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .cartao()
        }
        .buttonStyle(.plain)
        .disabled(vm.carregando)
        .task {
            if !vm.jaCarregou { await vm.carregar() }
        }
        .alert("Não foi possível ligar daqui", isPresented: mostrandoAlerta) {
            Button("Copiar número") {
                UIPasteboard.general.string = numeroSemLigacao
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("Este aparelho não faz ligações (no Simulador isso é normal). Número do síndico: \(numeroSemLigacao ?? "")")
        }
    }

    private var subtitulo: String {
        if vm.carregando && !vm.jaCarregou { return "Buscando contato…" }
        if let erro = vm.erro { return erro }
        guard let sindico = vm.sindico else { return "Síndico não cadastrado" }
        if let telefone = sindico.telefone { return "\(sindico.nome) · \(telefone)" }
        return "\(sindico.nome) · sem telefone cadastrado"
    }

    private var mostrandoAlerta: Binding<Bool> {
        Binding(
            get: { numeroSemLigacao != nil },
            set: { if !$0 { numeroSemLigacao = nil } }
        )
    }

    private func ligar() async {
        if vm.sindico?.telefone == nil {
            await vm.carregar()
        }
        guard let telefone = vm.sindico?.telefone else { return }
        let abriu = await Ligacao.ligar(para: telefone)
        if !abriu {
            numeroSemLigacao = telefone
        }
    }
}

#Preview("Botão ligar") {
    APIConfig.usarMock = true
    return LigarSindicoButton()
        .padding()
}
