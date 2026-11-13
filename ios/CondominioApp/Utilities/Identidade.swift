import SwiftUI
import UIKit

enum Identidade {
    static let azul = AppColors.accent
    static let azulMarinho = Color(red: 0, green: 36 / 255, blue: 98 / 255)
    static let azulMarinhoEscuro = Color(red: 0, green: 18 / 255, blue: 52 / 255)
    static let azulMarinhoClaro = Color(red: 0.27, green: 0.38, blue: 0.58)
    static let degradeCabecalho = LinearGradient(
        stops: [
            .init(color: azulMarinho, location: 0),
            .init(color: azulMarinho, location: 0.55),
            .init(color: azulMarinhoClaro, location: 1)
        ],
        startPoint: .top, endPoint: .bottom
    )
    static let degradeRodape = LinearGradient(
        stops: [
            .init(color: azulMarinhoClaro, location: 0),
            .init(color: azulMarinho, location: 0.45),
            .init(color: azulMarinho, location: 1)
        ],
        startPoint: .top, endPoint: .bottom
    )

    static func cor(_ id: String) -> Color {
        switch id {
        case "encomendas": Color(red: 0.96, green: 0.62, blue: 0.07)
        case "boletos": Color(red: 0.13, green: 0.66, blue: 0.40)
        case "reservas": Color(red: 0.40, green: 0.38, blue: 0.95)
        case "ocorrencias": Color(red: 0.92, green: 0.30, blue: 0.29)
        case "comunicados": AppColors.accent
        case "meus_anuncios": Color(red: 0.91, green: 0.30, blue: 0.58)
        case "achados": Color(red: 0.07, green: 0.65, blue: 0.62)
        case "contatos": Color(red: 0.05, green: 0.60, blue: 0.86)
        default: azulMarinho
        }
    }

    static func simbolo(_ id: String, padrao: String = "square.grid.2x2.fill") -> String {
        switch id {
        case "encomendas": "shippingbox.fill"
        case "boletos": "barcode"
        case "reservas": "calendar.badge.clock"
        case "ocorrencias": "exclamationmark.bubble.fill"
        case "comunicados": "megaphone.fill"
        case "meus_anuncios": "tag.fill"
        case "achados": "binoculars.fill"
        case "contatos": "phone.fill"
        default: padrao
        }
    }
}

extension Funcionalidade {
    var cor: Color { Identidade.cor(id) }
    var simbolo: String { Identidade.simbolo(id, padrao: icone) }
}

extension EspacoReserva {
    var cor: Color {
        switch self {
        case .churrasqueira: .red
        case .salaoFestas: Color(red: 0.69, green: 0.30, blue: 0.86)
        case .quadraBasquete: .orange
        case .campoFutebol: .black
        case .academia: .gray
        }
    }
}

struct IconeBadge: View {
    let simbolo: String
    let cor: Color
    var tamanho: CGFloat = 32

    var body: some View {
        RoundedRectangle(cornerRadius: tamanho * 0.28, style: .continuous)
            .fill(cor.gradient)
            .overlay {
                Image(systemName: simbolo)
                    .font(.system(size: tamanho * 0.48, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: tamanho * 0.28, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
            }
            .frame(width: tamanho, height: tamanho)
            .accessibilityHidden(true)
    }
}

extension IconeBadge {
    init(_ f: Funcionalidade, tamanho: CGFloat = 32) {
        self.init(simbolo: f.simbolo, cor: f.cor, tamanho: tamanho)
    }
    init(_ e: EspacoReserva, tamanho: CGFloat = 32) {
        self.init(simbolo: e.icone, cor: e.cor, tamanho: tamanho)
    }
}

struct LinhaFuncionalidade: View {
    let funcionalidade: Funcionalidade
    var body: some View {
        Label {
            Text(funcionalidade.nome).foregroundStyle(AppColors.textPrimary)
        } icon: {
            IconeBadge(funcionalidade, tamanho: 28)
        }
    }
}
