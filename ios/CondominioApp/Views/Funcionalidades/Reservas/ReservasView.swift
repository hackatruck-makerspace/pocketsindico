import SwiftUI

struct ReservasView: View {
    @Environment(AppSession.self) private var session

    @State private var espacoSelecionado: EspacoReserva = .churrasqueira

    @State private var mesExibido = Calendar.current.dateInterval(
        of: .month,
        for: Date()
    )?.start ?? Date()

    @State private var dataSelecionada: Date? = nil
    @State private var horarioSelecionado: String? = nil

    @State private var ocupadas: [Reserva] = []
    @State private var minhas: [Reserva] = []
    @State private var verTodas = false

    @State private var carregandoHorarios = false
    @State private var carregandoMinhas = false
    @State private var enviando = false
    @State private var erro: String?

    @State private var mostrarConfirmacao = false
    @State private var reservaParaCancelar: Reserva? = nil

    private let azul = AppColors.accent

    private let horarios = EspacoReserva.horarios

    private let diasSemana = [
        "D", "S", "T", "Q", "Q", "S", "S"
    ]

    private let colunas = Array(
        repeating: GridItem(.flexible(), spacing: 5),
        count: 7
    )

    private var podeReservar: Bool { session.usuario.perfil != .guarda }

    private var chaveConsulta: String {
        "\(espacoSelecionado.rawValue)|\(dataSelecionada.map(ReservaData.texto) ?? "")"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                cabecalho

                selecaoEspaco

                calendario

                selecaoHorario

                resumoReserva

                botaoConfirmar

                minhasReservas
            }
            .padding()
        }
        .telaPadrao()
        .navigationTitle("Reservas").barraMarca()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await carregarOcupadas()
            await carregarMinhas()
        }
        .task { await carregarMinhas() }
        .task(id: chaveConsulta) { await carregarOcupadas() }

        .alert(
            "Confirmar reserva?",
            isPresented: $mostrarConfirmacao
        ) {
            Button("Voltar", role: .cancel) {}

            Button("Confirmar") {
                Task { await registrarReserva() }
            }
        } message: {
            Text(mensagemConfirmacao)
        }

        .alert(
            "Cancelar reserva?",
            isPresented: Binding(
                get: {
                    reservaParaCancelar != nil
                },
                set: {
                    if !$0 {
                        reservaParaCancelar = nil
                    }
                }
            ),
            presenting: reservaParaCancelar
        ) { reserva in

            Button("Sim, cancelar reserva", role: .destructive) {
                Task { await cancelarReserva(reserva) }
            }

            Button("Não, manter reserva", role: .cancel) {
                reservaParaCancelar = nil
            }
        } message: { reserva in
            Text(
                "\(reserva.nomeEspaco)\n\(dataFormatada(reserva.data)) às \(reserva.horario)"
            )
        }

        .alert(
            "Não foi possível concluir",
            isPresented: Binding(get: { erro != nil }, set: { if !$0 { erro = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(erro ?? "")
        }
    }

    private var cabecalho: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Reservas")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(AppColors.textPrimary)

            Text(podeReservar
                 ? "Escolha um espaço, uma data e um horário disponível."
                 : "Consulte os horários reservados dos espaços do condomínio.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var selecaoEspaco: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Escolha o espaço")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EspacoReserva.allCases) { espaco in
                        botaoEspaco(espaco)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 2)
            }
            .onChange(of: espacoSelecionado) { _, _ in
                horarioSelecionado = nil
            }
        }
    }

    private func botaoEspaco(_ espaco: EspacoReserva) -> some View {
        let selecionado = espaco == espacoSelecionado

        return Button {
            espacoSelecionado = espaco
        } label: {
            VStack(spacing: 8) {
                IconeBadge(espaco, tamanho: 44)
                Text(espaco.nome)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 84)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 6)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(selecionado ? azul : Color.clear, lineWidth: 2)
            }
            .sombraSutil()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(espaco.nome)
        .accessibilityAddTraits(selecionado ? .isSelected : [])
    }

    private var calendario: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Escolha a data")
                .font(.headline)
                .foregroundStyle(AppColors.textPrimary)

            HStack {
                Button {
                    alterarMes(-1)
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                }
                .disabled(!podeVoltarMes)

                Spacer()

                Text(mesFormatado)
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    alterarMes(1)
                } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.bold)
                }
            }
            .foregroundStyle(azul)

            LazyVGrid(columns: colunas, spacing: 12) {
                ForEach(
                    Array(diasSemana.enumerated()),
                    id: \.offset
                ) { item in

                    Text(item.element)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(AppColors.textSecondary)
                }

                ForEach(0..<diasVazios, id: \.self) { _ in

                    Color.clear
                        .frame(height: 38)
                }

                ForEach(diasDoMes, id: \.self) { dia in
                    botaoDia(dia)
                }
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(azul)
                    .frame(width: 9, height: 9)

                Text("Data selecionada")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding()
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func botaoDia(_ dia: Date) -> some View {
        let selecionado = diaEstaSelecionado(dia)
        let passado = ehPassado(dia)

        return Button {
            dataSelecionada = dia
            horarioSelecionado = nil
        } label: {
            Text(
                String(
                    Calendar.current.component(.day, from: dia)
                )
            )
            .font(.subheadline)
            .fontWeight(.medium)
            .frame(maxWidth: .infinity)
            .frame(height: 38)
            .background(
                selecionado ? azul : Color.clear
            )
            .foregroundStyle(
                selecionado ? Color.white : AppColors.textPrimary
            )
            .clipShape(Circle())
            .opacity(passado ? 0.35 : 1.0)
        }
        .disabled(passado)
    }

    private var selecaoHorario: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(podeReservar ? "Horários disponíveis" : "Horários")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                if carregandoHorarios {
                    Spacer()
                    ProgressView()
                }
            }

            if dataSelecionada == nil {
                Text("Selecione uma data no calendário.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ],
                    spacing: 10
                ) {
                    ForEach(horarios, id: \.self) { horario in
                        botaoHorario(horario)
                    }
                }

                legendaHorarios

                if !podeReservar {
                    ForEach(ocupadas) { r in
                        Label("\(r.horario) · \([r.moradorNome, r.unidade].compactMap { $0 }.joined(separator: " · "))", systemImage: "person.fill")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
        }
    }

    private func botaoHorario(_ horario: String) -> some View {
        let ocupado = horarioEstaOcupado(horario)
        let meu = reservaDoHorario(horario)?.ehMinha ?? false

        return Button {
            horarioSelecionado = horario
        } label: {
            Text(meu ? "\(horario) · Sua" : horario)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    corHorario(horario, ocupado: ocupado, meu: meu)
                )
                .foregroundStyle(
                    textoHorario(horario, ocupado: ocupado, meu: meu)
                )
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .sombraSutil()
        }
        .disabled(ocupado || !podeReservar)
    }

    private func corHorario(
        _ horario: String,
        ocupado: Bool,
        meu: Bool
    ) -> Color {
        if meu {
            return Color.green.opacity(0.25)
        }

        if ocupado {
            return Color.gray.opacity(0.20)
        }

        if horarioSelecionado == horario {
            return azul
        }

        return AppColors.card
    }

    private func textoHorario(
        _ horario: String,
        ocupado: Bool,
        meu: Bool
    ) -> Color {
        if meu {
            return .green
        }

        if ocupado {
            return AppColors.textSecondary
        }

        if horarioSelecionado == horario {
            return .white
        }

        return AppColors.textPrimary
    }

    private var legendaHorarios: some View {
        HStack(spacing: 12) {
            legenda(cor: .gray.opacity(0.4), texto: "Ocupado")

            legenda(cor: .green.opacity(0.5), texto: "Sua reserva")

            legenda(cor: azul, texto: "Selecionado")

            legenda(
                cor: AppColors.card,
                texto: "Disponível"
            )
        }
        .padding(.top, 5)
    }

    private func legenda(
        cor: Color,
        texto: String
    ) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 3)
                .fill(cor)
                .frame(width: 10, height: 10)

            Text(texto)
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    @ViewBuilder
    private var resumoReserva: some View {
        if let data = dataSelecionada, podeReservar {
            VStack(alignment: .leading, spacing: 10) {
                Text("Resumo da reserva")
                    .font(.headline)

                Label {
                    Text(espacoSelecionado.nome)
                } icon: {
                    IconeBadge(espacoSelecionado, tamanho: 24)
                }

                Label(
                    dataFormatada(data),
                    systemImage: "calendar"
                )

                if let horario = horarioSelecionado {
                    Label(
                        horario,
                        systemImage: "clock"
                    )
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppColors.textPrimary)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private var botaoConfirmar: some View {
        if podeReservar {
            Button {
                mostrarConfirmacao = true
            } label: {
                HStack {
                    if enviando { ProgressView().tint(.white) }
                    Text("Confirmar reserva")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    podeConfirmar ? azul : Color.gray
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .sombraSutil()
            }
            .disabled(!podeConfirmar)
        } else {
            Label("A portaria pode consultar as reservas, mas não reservar.", systemImage: "info.circle")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var minhasReservas: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(verTodas ? "Reservas do condomínio" : "Minhas reservas")
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if carregandoMinhas { ProgressView() }

                Text("\(minhas.count)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(azul)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(azul.opacity(0.10))
                    .clipShape(Capsule())
            }

            if minhas.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.largeTitle)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(verTodas ? "Nenhuma reserva nos próximos dias." : "Você ainda não possui reservas.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
                .background(AppColors.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                ForEach(minhas) { reserva in
                    cartaoReserva(reserva)
                }
            }
        }
    }

    private func cartaoReserva(
        _ reserva: Reserva
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let espaco = reserva.espaco {
                    IconeBadge(espaco, tamanho: 30)
                } else {
                    Image(systemName: "building.2.fill").foregroundStyle(azul)
                }

                Text(reserva.nomeEspaco)
                    .fontWeight(.semibold)

                Spacer()

                Text("Confirmada")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Divider()

            Label(
                dataFormatada(reserva.data),
                systemImage: "calendar"
            )

            Label(
                reserva.horario,
                systemImage: "clock"
            )

            if verTodas, !reserva.ehMinha {
                Label(
                    [reserva.moradorNome, reserva.unidade].compactMap { $0 }.joined(separator: " · "),
                    systemImage: "person.fill"
                )
                .foregroundStyle(AppColors.textSecondary)
            }

            Button(role: .destructive) {
                reservaParaCancelar = reserva
            } label: {
                Label(
                    "Cancelar reserva",
                    systemImage: "xmark.circle"
                )
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 5)
            .disabled(enviando)
        }
        .font(.subheadline)
        .foregroundStyle(AppColors.textPrimary)
        .padding()
        .background(AppColors.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var diasDoMes: [Date] {
        guard let intervalo = Calendar.current.range(
            of: .day,
            in: .month,
            for: mesExibido
        ) else {
            return []
        }

        return intervalo.compactMap { numeroDia in

            Calendar.current.date(
                byAdding: .day,
                value: numeroDia - 1,
                to: mesExibido
            )
        }
    }

    private var diasVazios: Int {
        let weekday = Calendar.current.component(
            .weekday,
            from: mesExibido
        )

        let primeiroDia = Calendar.current.firstWeekday

        return (weekday - primeiroDia + 7) % 7
    }

    private var mesFormatado: String {
        mesExibido.formatted(
            .dateTime
                .month(.wide)
                .year()
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private var podeVoltarMes: Bool {
        let mesAtual = Calendar.current.dateInterval(
            of: .month,
            for: Date()
        )?.start ?? Date()

        return mesExibido > mesAtual
    }

    private func alterarMes(_ quantidade: Int) {
        guard let novoMes = Calendar.current.date(
            byAdding: .month,
            value: quantidade,
            to: mesExibido
        ) else {
            return
        }

        let mesAtual = Calendar.current.dateInterval(
            of: .month,
            for: Date()
        )?.start ?? Date()

        if novoMes >= mesAtual {
            mesExibido = novoMes
            dataSelecionada = nil
            horarioSelecionado = nil
        }
    }

    private func diaEstaSelecionado(_ dia: Date) -> Bool {
        guard let selecionada = dataSelecionada else {
            return false
        }

        return Calendar.current.isDate(
            dia,
            inSameDayAs: selecionada
        )
    }

    private func ehPassado(_ dia: Date) -> Bool {
        return Calendar.current.startOfDay(for: dia) <
            Calendar.current.startOfDay(for: Date())
    }

    private var podeConfirmar: Bool {
        guard podeReservar,
              !enviando,
              let horario = horarioSelecionado,
              dataSelecionada != nil else {
            return false
        }

        return !horarioEstaOcupado(horario)
    }

    private func reservaDoHorario(_ horario: String) -> Reserva? {
        ocupadas.first { $0.horario == horario }
    }

    private func horarioEstaOcupado(
        _ horario: String
    ) -> Bool {
        guard let data = dataSelecionada else {
            return false
        }

        if reservaDoHorario(horario) != nil {
            return true
        }

        if Calendar.current.isDateInToday(data),
           let hora = Int(horario.prefix(2)) {
            return hora <= Calendar.current.component(.hour, from: Date())
        }

        return false
    }

    private func carregarOcupadas() async {
        guard let data = dataSelecionada else {
            ocupadas = []
            return
        }

        carregandoHorarios = true
        defer { carregandoHorarios = false }

        do {
            ocupadas = try await APIService.shared.reservas(espaco: espacoSelecionado, data: ReservaData.texto(data))
            if let h = horarioSelecionado, horarioEstaOcupado(h) { horarioSelecionado = nil }
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            erro = error.localizedDescription
        }
    }

    private func carregarMinhas() async {
        carregandoMinhas = true
        defer { carregandoMinhas = false }

        do {
            let resposta = try await APIService.shared.minhasReservas()
            minhas = resposta.reservas
            verTodas = resposta.todas ?? false
        } catch is CancellationError {
        } catch let e as URLError where e.code == .cancelled {
        } catch {
            erro = error.localizedDescription
        }
    }

    private func registrarReserva() async {
        guard let data = dataSelecionada,
              let horario = horarioSelecionado,
              !horarioEstaOcupado(horario) else {
            return
        }

        enviando = true
        defer { enviando = false }

        do {
            _ = try await APIService.shared.criarReserva(espaco: espacoSelecionado, data: ReservaData.texto(data), horario: horario)
            horarioSelecionado = nil
        } catch {
            erro = error.localizedDescription
        }

        await carregarOcupadas()
        await carregarMinhas()
    }

    private func cancelarReserva(
        _ reserva: Reserva
    ) async {
        reservaParaCancelar = nil
        enviando = true
        defer { enviando = false }

        do {
            try await APIService.shared.cancelarReserva(id: reserva.id)
        } catch {
            erro = error.localizedDescription
        }

        horarioSelecionado = nil
        await carregarOcupadas()
        await carregarMinhas()
    }

    private func dataFormatada(_ data: Date) -> String {
        return data.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
                .locale(Locale(identifier: "pt_BR"))
        )
    }

    private func dataFormatada(_ texto: String) -> String {
        ReservaData.date(texto).map { dataFormatada($0) } ?? texto
    }

    private var mensagemConfirmacao: String {
        let data = dataSelecionada.map {
            dataFormatada($0)
        } ?? ""

        let horario = horarioSelecionado ?? ""

        return "\(espacoSelecionado.nome) reservado para \(data) às \(horario)."
    }
}

#Preview {
    APIConfig.usarMock = true
    return NavigationStack {
        ReservasView()
    }
    .environment(AppSession())
}
