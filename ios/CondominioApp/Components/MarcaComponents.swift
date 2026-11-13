import SwiftUI

struct LogoMarca: View {
    var tamanho: CGFloat = 58

    var body: some View {
        RoundedRectangle(cornerRadius: tamanho * 0.26, style: .continuous)
            .fill(.white)
            .frame(width: tamanho, height: tamanho)
            .overlay {
                Image("LogoPocketSindico")
                    .resizable()
                    .scaledToFit()
                    .padding(tamanho * 0.12)
            }
            .shadow(color: .black.opacity(0.25), radius: 6, y: 3)
            .accessibilityLabel("PocketSindico")
    }
}

struct CabecalhoMarca<Conteudo: View>: View {
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            conteudo
                .frame(maxWidth: .infinity, alignment: .leading)
            LogoMarca()
        }
        .padding(.horizontal, 20)
        .padding(.top, 2)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Identidade.azulMarinho
                    .ignoresSafeArea(edges: .top)
                Identidade.degradeCabecalho
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
    }
}

private struct SemEfeitoDeBordaNoTopo: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

extension View {
    func barraMarca() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Identidade.azulMarinho, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }

    func barraAzulMarinho() -> some View {
        self
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Identidade.azulMarinho, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .modifier(SemEfeitoDeBordaNoTopo())
    }
}

struct CabecalhoInicio: View {
    let usuario: Usuario

    var body: some View {
        CabecalhoMarca {
            Text(usuario.nome)
                .font(.title2.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
    }
}

struct CabecalhoPerfil: View {
    let usuario: Usuario

    var body: some View {
        CabecalhoMarca {
            VStack(alignment: .leading, spacing: 8) {
                Text(usuario.nome)
                    .font(.title2.bold())
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                HStack(spacing: 16) {
                    info("Bloco", usuario.bloco ?? "—")
                    info("Apartamento", usuario.apartamento ?? "—")
                }
                Text(usuario.perfil.titulo)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.16), in: Capsule())
            }
        }
    }

    private func info(_ titulo: String, _ valor: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(titulo)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.65))
            Text(valor)
                .font(.subheadline.weight(.semibold))
        }
    }
}

enum AbaPrincipal: Int, CaseIterable, Identifiable {
    case inicio, mural, perfil
    var id: Int { rawValue }

    var titulo: String {
        switch self {
        case .inicio: "Início"
        case .mural: "Mural"
        case .perfil: "Perfil"
        }
    }

    var icone: String {
        switch self {
        case .inicio: "house.fill"
        case .mural: "newspaper.fill"
        case .perfil: "person.crop.circle.fill"
        }
    }
}

struct RodapeNavegacao: View {
    @Binding var aba: AbaPrincipal

    var body: some View {
        VStack(spacing: 0) {
            LinearGradient(stops: [
                .init(color: AppColors.background.opacity(0), location: 0),
                .init(color: AppColors.background.opacity(0.9), location: 0.45),
                .init(color: Identidade.azulMarinhoClaro, location: 1)
            ], startPoint: .top, endPoint: .bottom)
                .frame(height: 22)
                .allowsHitTesting(false)
            barra
        }
    }

    private var barra: some View {
        HStack(spacing: 0) {
            ForEach(AbaPrincipal.allCases) { item in
                let ativo = item == aba
                Button {
                    aba = item
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: item.icone)
                            .font(.system(size: 21, weight: .semibold))
                        Text(item.titulo)
                            .font(.system(size: 11, weight: ativo ? .bold : .medium))
                    }
                    .foregroundStyle(ativo ? Color.white : Color.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
                    .frame(height: 49)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.titulo)
                .accessibilityAddTraits(ativo ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Identidade.degradeRodape
                .ignoresSafeArea(edges: .bottom)
        }
    }
}
