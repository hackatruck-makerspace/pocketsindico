import SwiftUI

@main
struct CondominioApp: App {
    @UIApplicationDelegateAdaptor(AlertaAppDelegate.self) private var appDelegate
    @State private var session = AppSession()
    @AppStorage("tema") private var tema = "escuro"

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(session)
                .onAppear { AparenciaApp.aplicar(tema) }
                .onChange(of: tema) { _, novo in AparenciaApp.aplicar(novo) }
                .tint(AppColors.accent)
                .task { await session.carregarTudo() }
        }
    }
}

#Preview("Modo Mock Interativo") {
    APIConfig.usarMock = true
    let session = AppSession()
    return MainTabView()
        .environment(session)
        .preferredColorScheme(.dark)
        .tint(AppColors.accent)
        .task { await session.carregarTudo() }
}
