import SwiftUI
import UIKit

struct MainTabView: View {
    @Environment(AppSession.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var aba: AbaPrincipal = .inicio
    @State private var tecladoVisivel = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                pagina(.inicio) { NavigationStack { HomeView() } }
                pagina(.mural) { NavigationStack { MuralView() } }
                pagina(.perfil) { NavigationStack { PerfilView() } }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            if !tecladoVisivel {
                RodapeNavegacao(aba: $aba)
            }
        }
        .background(AppColors.background.ignoresSafeArea())
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            tecladoVisivel = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            tecladoVisivel = false
        }
        .fullScreenCover(item: Binding(get: { session.alertas.aberto }, set: { session.alertas.aberto = $0 })) { alerta in
            AlertaConvivenciaView(alertaID: alerta.id)
        }
        .onChange(of: aba) { _, nova in
            if nova == .inicio { Task { await session.atualizarHome() } }
        }
        .onChange(of: session.usuario) { _, _ in session.alertas.atualizar(usuario: session.usuario) }
        .onChange(of: session.alertas.notificacoes.alertaSolicitado) { _, _ in
            session.alertas.atualizar(usuario: session.usuario)
        }
        .onChange(of: scenePhase) { _, fase in
            if fase == .active { session.alertas.atualizar(usuario: session.usuario) }
        }
        .task {
            while !Task.isCancelled {
                if scenePhase == .active { session.alertas.atualizar(usuario: session.usuario) }
                do { try await Task.sleep(for: .seconds(2)) } catch { break }
            }
        }
    }

    private func pagina<Conteudo: View>(_ item: AbaPrincipal, @ViewBuilder _ conteudo: () -> Conteudo) -> some View {
        let ativa = item == aba
        return conteudo()
            .opacity(ativa ? 1 : 0)
            .allowsHitTesting(ativa)
            .accessibilityHidden(!ativa)
            .zIndex(ativa ? 1 : 0)
    }
}
