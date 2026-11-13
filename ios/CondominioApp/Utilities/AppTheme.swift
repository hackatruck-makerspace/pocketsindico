import SwiftUI

enum AppColors {
    private static func dyn(_ dark: UIColor, _ light: UIColor) -> Color {
        Color(UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
    static let background = dyn(UIColor(red: 0.04, green: 0.06, blue: 0.10, alpha: 1), UIColor(red: 0.95, green: 0.96, blue: 0.98, alpha: 1))
    static let card       = dyn(UIColor(red: 0.08, green: 0.11, blue: 0.18, alpha: 1), .white)
    static let accent     = Color(red: 1 / 255, green: 108 / 255, blue: 225 / 255)
    static let textPrimary = dyn(.white, UIColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1))
    static let textSecondary = dyn(UIColor(white: 1, alpha: 0.6), UIColor(white: 0, alpha: 0.55))
    static let sombra = dyn(UIColor(white: 0, alpha: 0.45), UIColor(red: 0, green: 0.09, blue: 0.25, alpha: 0.10))
}

enum AppTheme {
    static func colorScheme(for tema: String) -> ColorScheme? {
        switch tema { case "claro": .light; case "escuro": .dark; default: nil }
    }
    static let raio: CGFloat = 18
}

enum AparenciaApp {
    @MainActor
    static func aplicar(_ tema: String) {
        let estilo: UIUserInterfaceStyle
        switch tema {
        case "claro": estilo = .light
        case "escuro": estilo = .dark
        default: estilo = .unspecified
        }
        for cena in UIApplication.shared.connectedScenes {
            guard let janela = cena as? UIWindowScene else { continue }
            for w in janela.windows { w.overrideUserInterfaceStyle = estilo }
        }
    }
}

extension View {
    func sombraSutil() -> some View {
        shadow(color: AppColors.sombra, radius: 3, x: 0, y: 1.5)
    }

    func cartao() -> some View {
        padding(16).background(AppColors.card).clipShape(RoundedRectangle(cornerRadius: AppTheme.raio, style: .continuous))
    }
    func telaPadrao() -> some View {
        background(AppColors.background.ignoresSafeArea()).scrollContentBackground(.hidden)
    }
}
