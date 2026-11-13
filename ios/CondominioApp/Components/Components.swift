import SwiftUI
import UIKit

struct UsuarioHeader: View {
    let usuario: Usuario
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(AppColors.accent.opacity(0.18)).frame(width: 52, height: 52)
                Image(systemName: "person.crop.circle.fill").foregroundStyle(AppColors.accent).font(.title3)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(usuario.nome).font(.headline).foregroundStyle(AppColors.textPrimary)
                Text([usuario.unidade, usuario.perfil.titulo].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
        }
    }
}

struct FeatureCard: View {
    let funcionalidade: Funcionalidade
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            IconeBadge(funcionalidade, tamanho: 40)
            Text(funcionalidade.nome).font(.subheadline.weight(.semibold)).foregroundStyle(AppColors.textPrimary)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading).cartao().sombraSutil()
    }
}

struct CategoryFilter: View {
    let opcoes: [(id: String, titulo: String)]
    @Binding var selecionada: String?
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Todos", nil)
                ForEach(opcoes, id: \.id) { chip($0.titulo, $0.id) }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
    private func chip(_ t: String, _ id: String?) -> some View {
        let ativo = selecionada == id
        return Button { selecionada = id } label: {
            Text(t).font(.subheadline.weight(.medium))
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ativo ? AppColors.accent : AppColors.card)
                .foregroundStyle(ativo ? Color.white : AppColors.textSecondary)
                .clipShape(Capsule())
                .sombraSutil()
        }.buttonStyle(.plain)
    }
}

struct CampoBusca: View {
    let prompt: String
    @Binding var texto: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(AppColors.textSecondary)
            TextField(prompt, text: $texto)
                .foregroundStyle(AppColors.textPrimary)
                .autocorrectionDisabled()
            if !texto.isEmpty {
                Button { texto = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Limpar busca")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(AppColors.card, in: Capsule())
        .sombraSutil()
        .padding(.horizontal)
    }
}

struct EmptyStateView: View {
    let icone: String; let texto: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icone).font(.largeTitle).foregroundStyle(AppColors.textSecondary)
            Text(texto).foregroundStyle(AppColors.textSecondary).multilineTextAlignment(.center)
        }.frame(maxWidth: .infinity).padding(40)
    }
}

struct ComunicadoCard: View {
    let c: Comunicado
    var umaColuna: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CategoriaComunicadoPill(categoria: c.categoria)

            Text(c.titulo)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2)

            Text(c.descricao)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(umaColuna ? 4 : 2)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(c.autorNome)
                Text(c.dataExibicao)
            }
            .font(.caption)
            .foregroundStyle(AppColors.textSecondary)
            .lineLimit(1)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cartao()
    }
}

struct CategoriaComunicadoPill: View {
    let categoria: String

    private var titulo: String {
        CategoriaComunicado(rawValue: categoria)?.titulo ?? categoria.capitalized
    }

    private var cor: Color {
        switch categoria {
        case "avisos": return .blue
        case "manutencao": return .orange
        case "obras": return .purple
        case "limpeza": return .green
        case "assembleias": return .pink
        case "seguranca": return .red
        case "outro": return .gray
        default: return AppColors.accent
        }
    }

    var body: some View {
        Label(titulo, systemImage: "megaphone.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(cor)
            .background(cor.opacity(0.14), in: Capsule())
    }
}

enum DataHora {
    static func formatar(_ valor: String) -> String {
        let v = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        if v.count == 10 {
            let p = v.split(separator: "-")
            if p.count == 3, p[0].count == 4 { return "\(p[2])/\(p[1])/\(p[0])" }
        }
        let comFracao = ISO8601DateFormatter()
        comFracao.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let data = comFracao.date(from: v) ?? ISO8601DateFormatter().date(from: v) else { return v }
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = .current
        f.dateFormat = "dd/MM/yyyy 'às' HH:mm"
        return f.string(from: data)
    }

    static func data(_ valor: String?) -> Date? {
        guard let v = valor?.trimmingCharacters(in: .whitespacesAndNewlines), !v.isEmpty else { return nil }
        let comFracao = ISO8601DateFormatter()
        comFracao.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return comFracao.date(from: v) ?? ISO8601DateFormatter().date(from: v)
    }

    private static func formatador(_ formato: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "pt_BR")
        f.timeZone = .current
        f.dateFormat = formato
        return f
    }

    static func dia(_ d: Date) -> String { formatador("dd/MM/yyyy").string(from: d) }
    static func hora(_ d: Date) -> String { formatador("HH:mm").string(from: d) }

    static func partes(_ valor: String?) -> (data: String, hora: String?)? {
        guard let valor else { return nil }
        if let d = data(valor) { return (dia(d), hora(d)) }
        let v = valor.trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : (formatar(v), nil)
    }
}

struct DataHoraLinhas: View {
    let data: String
    let hora: String?
    var titulo: String? = nil

    init(_ date: Date, titulo: String? = nil) {
        data = DataHora.dia(date); hora = DataHora.hora(date); self.titulo = titulo
    }
    init?(iso: String?, titulo: String? = nil) {
        guard let p = DataHora.partes(iso) else { return nil }
        data = p.data; hora = p.hora; self.titulo = titulo
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let titulo { Text(titulo).fontWeight(.semibold) }
            Text("Data: \(data)")
            if let hora { Text("Horário: \(hora)") }
        }
        .font(.caption)
        .foregroundStyle(AppColors.textSecondary)
    }
}

enum ImagemUtil {
    static let limiteDocumento = 980_000
    static let limiteFotosAnuncio = 940_000

    nonisolated static func base64(de data: Data, limiteCaracteres: Int, maxLado: CGFloat = 2000) -> String? {
        guard let original = UIImage(data: data) else { return nil }
        let maior = max(original.size.width, original.size.height)
        guard maior > 0 else { return nil }
        var lado = min(maxLado, maior)
        for _ in 0..<7 {
            let escala = min(1, lado / maior)
            let alvo = CGSize(width: max(1, (original.size.width * escala).rounded()),
                              height: max(1, (original.size.height * escala).rounded()))
            let formato = UIGraphicsImageRendererFormat()
            formato.scale = 1
            let reduzida = UIGraphicsImageRenderer(size: alvo, format: formato).image { _ in
                UIColor.white.setFill()
                UIRectFill(CGRect(origin: .zero, size: alvo))
                original.draw(in: CGRect(origin: .zero, size: alvo))
            }
            for qualidade in [0.85, 0.75, 0.65, 0.55, 0.45, 0.35] as [CGFloat] {
                if let jpeg = reduzida.jpegData(compressionQuality: qualidade) {
                    let b64 = jpeg.base64EncodedString()
                    if b64.count <= limiteCaracteres { return b64 }
                }
            }
            lado *= 0.75
        }
        return nil
    }

    nonisolated static func base64Async(de data: Data, limiteCaracteres: Int) async -> String? {
        await Task.detached(priority: .userInitiated) {
            ImagemUtil.base64(de: data, limiteCaracteres: limiteCaracteres)
        }.value
    }

    nonisolated static let limiteFotoUnica = 350_000
    nonisolated static func base64FotoUnica(de data: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            ImagemUtil.base64(de: data, limiteCaracteres: ImagemUtil.limiteFotoUnica, maxLado: 1400)
        }.value
    }
}

struct FotoAnuncioView: View {
    let base64: String

    var body: some View {
        if let data = Data(base64Encoded: base64), let imagem = UIImage(data: data) {
            Image(uiImage: imagem)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(AppColors.accent.opacity(0.12))
        }
    }
}

struct AnnouncementCard: View {
    let a: Anuncio
    let umaColuna: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let f = a.fotos.first {
                FotoAnuncioView(base64: f)
                    .frame(maxWidth: .infinity)
                    .frame(height: umaColuna ? 145 : 64)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            CategoriaAnuncioPill(categoria: a.categoria)

            Text(a.titulo)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(umaColuna ? 2 : 1)

            if let preco = a.preco, !preco.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(preco)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            HStack(spacing: 14) {
                Label("\(a.totalFavoritos)", systemImage: a.favoritado ? "heart.fill" : "heart")
                    .foregroundStyle(a.favoritado ? Color.red : AppColors.textSecondary)
                Label("\(a.totalComentarios)", systemImage: "bubble.left")
                    .foregroundStyle(AppColors.textSecondary)
            }
            .font(.caption)
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .aspectRatio(1, contentMode: .fit)
        .cartao()
    }
}

struct CategoriaAnuncioPill: View {
    let categoria: String

    private var titulo: String {
        CategoriaAnuncio(rawValue: categoria)?.titulo ?? categoria.capitalized
    }

    private var cor: Color {
        switch categoria {
        case "venda": return .blue
        case "comida": return .orange
        case "roupas": return .purple
        case "pets": return .green
        case "servicos": return .teal
        case "doacoes": return .pink
        case "outro": return .gray
        default: return AppColors.accent
        }
    }

    var body: some View {
        Label(titulo, systemImage: "tag.fill")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(cor)
            .background(cor.opacity(0.14), in: Capsule())
    }
}

struct BotaoFlutuanteMais: View {
    let rotulo: String
    let acao: () -> Void
    var body: some View {
        Button(action: acao) {
            Image(systemName: "plus").font(.title2.weight(.semibold)).foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(AppColors.accent, in: Circle())
                .sombraSutil()
        }
        .accessibilityLabel(rotulo)
    }
}

extension View {
    func botaoFlutuante(visivel: Bool = true, rotulo: String, acao: @escaping () -> Void) -> some View {
        overlay(alignment: .bottomTrailing) {
            if visivel { BotaoFlutuanteMais(rotulo: rotulo, acao: acao).padding(.trailing, 20).padding(.bottom, 16) }
        }
    }
}

struct BotaoAlternarGrid: View {
    @Binding var umaColuna: Bool
    var body: some View {
        Button { withAnimation(.snappy) { umaColuna.toggle() } } label: {
            Image(systemName: umaColuna ? "rectangle.grid.2x2" : "rectangle")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .background(AppColors.accent, in: Circle())
                .sombraSutil()
        }
        .accessibilityLabel(umaColuna ? "Mostrar dois por linha" : "Mostrar um por linha")
    }
}

enum PrecoMascara {
    static func formatar(centavos: Int) -> String {
        let reais = String(centavos / 100)
        let cts = centavos % 100
        var milhar = ""
        for (i, ch) in reais.reversed().enumerated() {
            if i > 0 && i % 3 == 0 { milhar.append(".") }
            milhar.append(ch)
        }
        return "R$ \(String(milhar.reversed())),\(cts < 10 ? "0" : "")\(cts)"
    }

    static func normalizar(_ texto: String?) -> String {
        guard let texto else { return "" }
        let limpo = texto.trimmingCharacters(in: .whitespacesAndNewlines)
        if limpo.lowercased() == "a combinar" { return "A combinar" }
        if limpo.lowercased() == "sem preço" { return "" }
        let numeros = String(limpo.filter(\.isNumber).prefix(9))
        let centavos = Int(numeros) ?? 0
        return centavos == 0 ? "" : formatar(centavos: centavos)
    }
}

struct CampoPreco: View {
    @Binding var preco: String
    var desabilitado: Bool = false

    private var texto: Binding<String> {
        Binding(
            get: { preco },
            set: { novo in
                let numeros = String(novo.filter(\.isNumber).prefix(9))
                let centavos = Int(numeros) ?? 0
                preco = centavos == 0 ? "" : PrecoMascara.formatar(centavos: centavos)
            }
        )
    }

    var body: some View {
        TextField("Preço — R$ 0,00", text: texto)
            .keyboardType(.numberPad)
            .disabled(desabilitado)
            .opacity(desabilitado ? 0.45 : 1)
    }
}

struct StatusPill: View {
    let texto: String
    var body: some View {
        Text(texto).font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Color.orange.opacity(0.18)).foregroundStyle(Color.orange)
            .clipShape(Capsule())
    }
}

enum AcaoAnuncio: Identifiable {
    case encerrar(Anuncio), reativar(Anuncio), excluir(Anuncio)
    var id: String {
        switch self {
        case .encerrar(let a): "encerrar-\(a.id)"
        case .reativar(let a): "reativar-\(a.id)"
        case .excluir(let a): "excluir-\(a.id)"
        }
    }
}

private struct ConfirmarAcoesAnuncio: ViewModifier {
    @Environment(AppSession.self) private var session
    @Binding var acao: AcaoAnuncio?
    @Binding var erro: String?
    var aoExcluir: () -> Void

    private var titulo: String {
        switch acao {
        case .encerrar: "Encerrar anúncio?"
        case .reativar: "Reativar anúncio?"
        case .excluir: "Excluir anúncio?"
        case nil: ""
        }
    }

    private func executar(_ operacao: @escaping () async throws -> Void) {
        Task { do { try await operacao() } catch { erro = error.localizedDescription } }
    }

    func body(content: Content) -> some View {
        content
            .confirmationDialog(titulo,
                isPresented: Binding(get: { acao != nil }, set: { if !$0 { acao = nil } }),
                titleVisibility: .visible, presenting: acao) { item in
                switch item {
                case .encerrar(let a):
                    Button("Encerrar anúncio") { executar { try await session.encerrarAnuncio(a) } }
                case .reativar(let a):
                    Button("Reativar anúncio") { executar { try await session.reativarAnuncio(a) } }
                case .excluir(let a):
                    Button("Excluir", role: .destructive) { executar { try await session.excluirAnuncio(a, aoApagar: aoExcluir) } }
                }
                Button("Cancelar", role: .cancel) {}
            } message: { item in
                switch item {
                case .encerrar: Text("Ele deixa de aparecer no Mural para os outros moradores. Você poderá vê-lo em Meus anúncios.")
                case .reativar: Text("O anúncio volta a aparecer no Mural com os mesmos dados, fotos, favoritos e comentários.")
                case .excluir: Text("O anúncio, os comentários e os favoritos serão apagados. Isso não pode ser desfeito.")
                }
            }
            .alert("Não foi possível concluir",
                isPresented: Binding(get: { erro != nil }, set: { if !$0 { erro = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(erro ?? "") }
    }
}

extension View {
    func confirmarAcoesAnuncio(acao: Binding<AcaoAnuncio?>, erro: Binding<String?>,
                               aoExcluir: @escaping () -> Void = {}) -> some View {
        modifier(ConfirmarAcoesAnuncio(acao: acao, erro: erro, aoExcluir: aoExcluir))
    }

    func botaoGrid(umaColuna: Binding<Bool>, acimaDoMais: Bool) -> some View {
        overlay(alignment: .bottomTrailing) {
            BotaoAlternarGrid(umaColuna: umaColuna)
                .padding(.trailing, 24).padding(.bottom, acimaDoMais ? 88 : 18)
        }
    }
}

private struct AtualizacaoAutomatica: ViewModifier {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var fase

    func body(content: Content) -> some View {
        content
            .task {
                await session.atualizarMural()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    if Task.isCancelled { break }
                    await session.atualizarMural()
                }
            }
            .onChange(of: fase) { _, nova in
                if nova == .active { Task { await session.atualizarMural() } }
            }
            .alert("Não foi possível atualizar",
                isPresented: Binding(get: { session.avisoMural != nil }, set: { if !$0 { session.avisoMural = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(session.avisoMural ?? "") }
    }
}

extension View {
    func atualizacaoAutomatica() -> some View { modifier(AtualizacaoAutomatica()) }
}
