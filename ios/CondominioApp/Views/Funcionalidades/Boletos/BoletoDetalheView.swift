import SwiftUI
import UIKit

struct BoletoDetalheView: View {
    @State private var boleto: Boleto
    @State private var copiado = false
    @State private var copias = 0

    init(boleto: Boleto) {
        _boleto = State(initialValue: boleto)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                cabecalho
                informacoes
                if let linha = boleto.linhaDigitavel {
                    codigoDeBarras(linha)
                }
                if let link = boleto.pdfUrl, let url = URL(string: link) {
                    Link(destination: url) {
                        Label("Abrir PDF do boleto", systemImage: "arrow.down.doc.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered).sombraSutil()
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .telaPadrao()
        .navigationTitle(boleto.competenciaFormatada).barraMarca()
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: copias)
        .task { await atualizar() }
    }

    private var cabecalho: some View {
        VStack(spacing: 8) {
            Label(boleto.situacao.titulo, systemImage: boleto.situacao.icone)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(boleto.situacao.cor)
            Text(boleto.valorFormatado)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
            Text(boleto.descricao)
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var informacoes: some View {
        VStack(spacing: 0) {
            linhaInfo("Competência", boleto.competenciaFormatada)
            Divider()
            linhaInfo("Vencimento", boleto.vencimentoFormatado)
            if let pago = boleto.pagoEmFormatado {
                Divider()
                linhaInfo("Pago em", pago)
            }
            if let unidade = boleto.unidade {
                Divider()
                linhaInfo("Unidade", unidade)
            }
            if let nome = boleto.moradorNome {
                Divider()
                linhaInfo("Morador", nome)
            }
        }
        .padding(.horizontal)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func linhaInfo(_ titulo: String, _ valor: String) -> some View {
        HStack {
            Text(titulo).foregroundStyle(AppColors.textSecondary)
            Spacer()
            Text(valor).fontWeight(.medium).foregroundStyle(AppColors.textPrimary)
        }
        .padding(.vertical, 12)
    }

    private func codigoDeBarras(_ linha: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linha digitável")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)
            Text(linha)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(AppColors.background, in: RoundedRectangle(cornerRadius: 10))

            if !boleto.estaPago {
                Button {
                    copiar()
                } label: {
                    Label(copiado ? "Código copiado!" : "Copiar código do boleto",
                          systemImage: copiado ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).sombraSutil()
                .controlSize(.large)
                .tint(copiado ? Color.green : AppColors.accent)

                Text("Cole o código no app do seu banco, na opção “Pagar boleto”.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            ShareLink(item: textoParaCompartilhar) {
                Label("Compartilhar boleto", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered).sombraSutil()
            .controlSize(.large)
        }
        .padding()
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var textoParaCompartilhar: String {
        """
        Boleto do condomínio – \(boleto.competenciaFormatada)
        Valor: \(boleto.valorFormatado)
        Vencimento: \(boleto.vencimentoFormatado)
        Linha digitável: \(boleto.linhaDigitavel ?? "-")
        """
    }

    private func copiar() {
        guard let codigo = boleto.codigoSomenteNumeros else { return }
        UIPasteboard.general.string = codigo
        copias += 1
        withAnimation { copiado = true }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { copiado = false }
        }
    }

    private func atualizar() async {
        if let novo = try? await APIService.shared.boleto(id: boleto.id) {
            boleto = novo
        }
    }
}

#Preview("Detalhe do boleto") {
    NavigationStack {
        BoletoDetalheView(boleto: DemoData.boletos[0])
    }
}
