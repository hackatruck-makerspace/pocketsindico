import SwiftUI

struct PerfilView: View {
    @Environment(AppSession.self) private var session

    var body: some View {
        VStack(spacing: 0) {
            CabecalhoPerfil(usuario: session.usuario)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    SecaoPerfil(titulo: "Funcionalidades") {
                        ForEach(Array(session.funcionalidades.enumerated()), id: \.element.id) { indice, f in
                            if indice > 0 { Divider().padding(.leading, 58) }
                            NavigationLink(value: f) {
                                LinhaPerfil { LinhaFuncionalidade(funcionalidade: f) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    SecaoPerfil(titulo: "Preferências") {
                        NavigationLink { ConfiguracoesView() } label: {
                            LinhaPerfil {
                                Label { Text("Configurações").foregroundStyle(AppColors.textPrimary) } icon: {
                                    IconeBadge(simbolo: "gearshape.fill", cor: .gray, tamanho: 28)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    SecaoPerfil(titulo: "Modo de demonstração") {
                        NavigationLink { TrocarPerfilView() } label: {
                            LinhaPerfil {
                                Label { Text("Trocar perfil").foregroundStyle(AppColors.textPrimary) } icon: {
                                    IconeBadge(simbolo: "arrow.triangle.2.circlepath", cor: Identidade.azulMarinho, tamanho: 28)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .background(AppColors.background.ignoresSafeArea())
        .barraAzulMarinho()
        .navigationDestination(for: Funcionalidade.self) { FuncionalidadeView(funcionalidade: $0) }
    }
}

struct SecaoPerfil<Conteudo: View>: View {
    let titulo: String
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titulo)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.leading, 6)
            VStack(spacing: 0) { conteudo }
                .background(AppColors.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .sombraSutil()
        }
    }
}

struct LinhaPerfil<Conteudo: View>: View {
    @ViewBuilder var conteudo: Conteudo

    var body: some View {
        HStack(spacing: 12) {
            conteudo
            Spacer(minLength: 8)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct TrocarPerfilView: View {
    @Environment(AppSession.self) private var session
    @State private var perfis = DemoData.perfis
    var body: some View {
        List(perfis) { p in
            Button { Task { await session.trocarPerfil(p) } } label: {
                HStack {
                    Label("\(p.nome) — \(p.perfil.titulo)", systemImage: "person.crop.circle.fill")
                    Spacer()
                    if p.id == session.usuario.id { Image(systemName: "checkmark").foregroundStyle(AppColors.accent) }
                }
            }
        }
        .telaPadrao().navigationTitle("Trocar perfil").barraMarca()
        .task { if let r = try? await APIService.shared.perfisDemo() { perfis = r } }
    }
}
