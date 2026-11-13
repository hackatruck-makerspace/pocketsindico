import SwiftUI
import PhotosUI

struct SeletorFotoUnica: View {
    @Binding var foto: String?
    var titulo = "Foto"
    var dica = "Opcional. A imagem é reduzida automaticamente."
    @State private var item: PhotosPickerItem?
    @State private var processando = false
    @State private var erro: String?

    var body: some View {
        Section {
            if let foto {
                ZStack(alignment: .topTrailing) {
                    FotoAnuncioView(base64: foto)
                        .frame(maxWidth: .infinity)
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Button { self.foto = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.black.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                    .padding(6)
                    .accessibilityLabel("Remover foto")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }
            PhotosPicker(selection: $item, matching: .images) {
                HStack {
                    Label(foto == nil ? "Adicionar foto" : "Trocar foto", systemImage: "photo.on.rectangle")
                    if processando { Spacer(); ProgressView() }
                }
            }
            .disabled(processando)
            if let erro { Text(erro).font(.footnote).foregroundStyle(.red) }
        } header: {
            Text(titulo)
        } footer: {
            Text(dica)
        }
        .onChange(of: item) { _, novo in
            guard let novo else { return }
            processando = true
            erro = nil
            Task {
                defer { processando = false; item = nil }
                guard let data = try? await novo.loadTransferable(type: Data.self),
                      let b64 = await ImagemUtil.base64FotoUnica(de: data) else {
                    erro = "Não foi possível usar essa imagem. Tente outra."
                    return
                }
                foto = b64
            }
        }
    }
}

struct FotoDetalhe: View {
    let foto: String?
    var icone = "photo"
    var altura: CGFloat = 220

    var body: some View {
        Group {
            if let foto {
                FotoAnuncioView(base64: foto)
            } else {
                ZStack {
                    AppColors.card
                    Image(systemName: icone)
                        .font(.system(size: 54))
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: altura)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct PilulaInfo: View {
    let texto: String
    let icone: String
    let cor: Color

    var body: some View {
        Label(texto, systemImage: icone)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(cor)
            .background(cor.opacity(0.14), in: Capsule())
            .lineLimit(1)
    }
}

struct LinhaDetalhe: View {
    let titulo: String
    let valor: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(titulo)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            Text(valor)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
