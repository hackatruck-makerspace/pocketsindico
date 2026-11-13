import Foundation

struct AlertaPersistence {
    private let url: URL

    init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CondominioDemo/alertas-v1.json")
    }

    func carregar() throws -> DadosAlertasDemo {
        guard FileManager.default.fileExists(atPath: url.path) else { return DadosAlertasDemo() }
        return try JSONDecoder().decode(DadosAlertasDemo.self, from: Data(contentsOf: url))
    }

    func salvar(_ dados: DadosAlertasDemo) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(dados).write(to: url, options: .atomic)
    }
}
