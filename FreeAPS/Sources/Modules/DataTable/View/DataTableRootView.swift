import CoreData
import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var isRemoveTreatmentsAlertPresented = false
        @State private var removeTreatmentsAlert: Alert?
        @State private var isRemoveGlucoseAlertPresented = false
        @State private var isInsulinAmountAlertPresented = false
        @State private var removeGlucoseAlert: Alert?
        @State private var showManualGlucose: Bool = false
        @State private var showNonPumpInsulin: Bool = false
        @State private var showFutureEntries: Bool = false

        @Environment(\.colorScheme) var colorScheme

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.minimumFractionDigits = 1
                formatter.maximumFractionDigits = 1
            }
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var dateFormatter: DateFormatter {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter
        }

        private var fpuFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.roundingMode = .halfUp
            return formatter
        }

        private var insulinFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 2
            return formatter
        }

        var futureEntryBtn: some View {
            Button(action: { showFutureEntries.toggle() }, label: {
                Text((showFutureEntries ? "Hide" : "Show") + " Future Entries").foregroundColor(Color.white)
                    .font(.caption)
                Image(systemName: showFutureEntries ? "calendar.badge.minus" : "calendar.badge.plus")
                    .resizable()
                    .frame(width: 18, height: 18)
                    .foregroundColor(Color.white)
            })
                .padding(.trailing, 20)
                .offset(x: 0, y: -50)
        }

        var body: some View {
            VStack {
                Picker("Mode", selection: $state.mode) {
                    ForEach(Mode.allCases.indexed(), id: \.1) { index, item in
                        Text(item.name)
                            .tag(index)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                historyContentView
            }
            .onAppear(perform: configureView)
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.automatic)
            .navigationBarItems(
                leading: HStack {
                    Button("Close", action: state.hideModal)
                    if state.mode == .treatments {
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Spacer()
                        Button(action: { showFutureEntries.toggle() }, label: {
                            Text((showFutureEntries ? "Dölj" : "Visa") + " framtida")
                                .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                                .font(.caption)
                            Image(
                                systemName: showFutureEntries ? "calendar.badge.minus" :
                                    "calendar.badge.plus"
                            )
                            .resizable()
                            .frame(width: 16, height: 16)
                            .foregroundColor(colorScheme == .dark ? Color.white : Color.black)
                        }).buttonStyle(.bordered)
                    }
                },
                trailing: HStack {
                    if state.mode == .treatments && !showNonPumpInsulin {
                        Button(action: { showNonPumpInsulin = true }) {
                            Text("Insulin")
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    }

                    if state.mode == .glucose && !showManualGlucose {
                        Button(action: { showManualGlucose = true }) {
                            Text("Blodsocker")
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            )
            .sheet(isPresented: $showManualGlucose) {
                addManualGlucoseView
            }
            .sheet(isPresented: $showNonPumpInsulin) {
                addNonPumpInsulinView
            }
        }

        var addManualGlucoseView: some View {
            NavigationView {
                VStack {
                    Form {
                        Section {
                            HStack {
                                Text("Blodsocker")
                                    .font(.title3.weight(.semibold))
                                DecimalTextField(
                                    " ... ",
                                    value: $state.manualGlucose,
                                    formatter: glucoseFormatter,
                                    autofocus: true
                                )
                                Text(state.units.rawValue).foregroundStyle(.secondary)
                                    .font(.title3.weight(.semibold))
                            }
                        }

                        Section {
                            DatePicker("Date", selection: $state.manualGlucoseDate)
                        }
                        Section {
                            HStack {
                                let limitLow: Decimal = state.units == .mmolL ? 2.2 : 40
                                let limitHigh: Decimal = state.units == .mmolL ? 22 : 400

                                Button {
                                    state.addManualGlucose()
                                    showManualGlucose = false
                                }
                                label: { Text("Logga BG från fingerstick") }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .font(.title3.weight(.semibold))
                                    .disabled(
                                        state.manualGlucose < limitLow || state
                                            .manualGlucose > limitHigh
                                    )
                            }
                        }
                    }
                }
                .onAppear(perform: configureView)
                .navigationTitle("Fingerstick")
                .navigationBarTitleDisplayMode(.automatic)
                .navigationBarItems(leading: Button("Close", action: { showManualGlucose = false
                    state.manualGlucose = 0 }))
            }
        }

        var addNonPumpInsulinView: some View {
            NavigationView {
                VStack {
                    Form {
                        Section {
                            HStack {
                                Text("Dos")
                                    .font(.title3.weight(.semibold))
                                Spacer()
                                DecimalTextField(
                                    "0,0",
                                    value: $state.nonPumpInsulinAmount,
                                    formatter: insulinFormatter,
                                    autofocus: true,
                                    cleanInput: true
                                )
                                Text(!(state.nonPumpInsulinAmount > state.maxBolus * 3) ? "U" : "☠️").fontWeight(.semibold)
                            }
                        }

                        Section {
                            DatePicker("Date", selection: $state.nonPumpInsulinDate)
                        }

                        Section {
                            let maxamountbolus = Double(state.maxBolus)
                            let formattedMaxAmountBolus = String(maxamountbolus)
                            HStack {
                                Button {
                                    state.addNonPumpInsulin()
                                    showNonPumpInsulin = false
                                }
                                label: {
                                    HStack {
                                        if state.nonPumpInsulinAmount > state.maxBolus {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundColor(.orange)
                                        }
                                        Text(
                                            !(state.nonPumpInsulinAmount > state.maxBolus) ? "Logga dos från insulinpenna" :
                                                "Inställd maxbolus: \(formattedMaxAmountBolus)E   "
                                        )
                                    }

                                    .font(.title3.weight(.semibold))
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .disabled(
                                        state.nonPumpInsulinAmount <= 0 || state.nonPumpInsulinAmount > state
                                            .maxBolus * 3
                                    )
                                }
                            }
                        }
                    }
                }
                .onAppear(perform: configureView)
                .navigationTitle("Insulinpenna")
                .navigationBarTitleDisplayMode(.automatic)
                .navigationBarItems(leading: Button("Close", action: { showNonPumpInsulin = false
                    state.nonPumpInsulinAmount = 0 }))
            }
        }

        private var historyContentView: some View {
            Form {
                switch state.mode {
                case .treatments: treatmentsList
                case .basals: basalsList
                case .glucose: glucoseList
                }
            }
        }

        private var treatmentsList: some View {
            List {
                if !state.treatments.isEmpty {
                    if !showFutureEntries {
                        ForEach(state.treatments.filter { item in
                            item.date <= Date()
                        }) { item in

                            treatmentView(item)
                        }
                        .onDelete(perform: deleteTreatments)
                    } else {
                        ForEach(state.treatments) { item in
                            treatmentView(item)
                        }
                        .onDelete(perform: deleteTreatments)
                    }
                } else {
                    HStack {
                        Text("Ingen data.")
                    }
                }
            }
            .alert(isPresented: $isRemoveTreatmentsAlertPresented) {
                removeTreatmentsAlert!
            }
        }

        private var basalsList: some View {
            List {
                if !state.basals.isEmpty {
                    ForEach(state.basals) { item in
                        basalView(item)
                    }

                } else {
                    HStack {
                        Text("Ingen data.")
                    }
                }
            }
            .alert(isPresented: $isRemoveTreatmentsAlertPresented) {
                removeTreatmentsAlert!
            }
        }

        private var glucoseList: some View {
            List {
                if !state.glucose.isEmpty {
                    ForEach(state.glucose) { item in
                        glucoseView(item)
                    }
                    .onDelete(perform: deleteGlucose)
                } else {
                    HStack {
                        Text("Ingen data.")
                    }
                }
            }
            .alert(isPresented: $isRemoveGlucoseAlertPresented) {
                removeGlucoseAlert!
            }
        }

        @ViewBuilder private func treatmentView(_ item: Treatment) -> some View {
            HStack {
                Image(systemName: "circle.fill").foregroundColor(item.color)
                Text((item.isSMB ?? false) ? "SMB" : item.type.name)
                Text(item.amountText).foregroundColor(.secondary)

                if let duration = item.durationText {
                    Text(duration).foregroundColor(.secondary)
                }

                if item.type == .carbs {
                    if item.note != "" {
                        Text(item.note ?? "").foregroundColor(.brown)
                    }
                }
                Spacer()

                Text(dateFormatter.string(from: item.date))
                    .moveDisabled(true)
            }
        }

        @ViewBuilder private func basalView(_ tempBasal: Treatment) -> some View {
            HStack {
                Text(tempBasal.type.name)
                Text(tempBasal.amountText).foregroundColor(.secondary)

                if let duration = tempBasal.durationText {
                    Text(duration).foregroundColor(.secondary)
                }

                Spacer()

                Text(dateFormatter.string(from: tempBasal.date))
                    .moveDisabled(true)
            }
        }

        @ViewBuilder private func glucoseView(_ item: Glucose) -> some View {
            HStack {
                Text(item.glucose.glucose.map {
                    glucoseFormatter.string(from: Double(
                        state.units == .mmolL ? $0.asMmolL : Decimal($0)
                    ) as NSNumber)!
                } ?? "--")
                Text(state.units.rawValue)
                Text(item.glucose.direction?.symbol ?? "Fingerstick")
                    .foregroundColor(
                        item.glucose.direction?.symbol != nil ? .secondary : .orange
                    )

                Spacer()

                Text(dateFormatter.string(from: item.glucose.dateString))
            }
        }

        private func deleteTreatments(at offsets: IndexSet) {
            let treatment = state.treatments[offsets[offsets.startIndex]]
            var alertTitle = Text("Radera Insulin?")
            var alertMessage = Text(treatment.amountText)
            var primaryButtonText = "Radera"
            var primaryAction: () -> Void = {
                state.deleteInsulin(treatment)
            }

            if treatment.type == .carbs {
                alertTitle = Text("Radera kolhydrater?")
                alertMessage = Text(treatment.amountText)
                primaryButtonText = "Radera"
                primaryAction = {
                    state.deleteCarbs(treatment)
                }
            }

            if treatment.type == .tempTarget {
                alertTitle = Text("Tillfälligt mål")
                alertMessage = Text("Kan inte raderas!")
                primaryButtonText = ""
                primaryAction = {}
            }

            if treatment.type == .suspend {
                alertTitle = Text("Pumphändelse")
                alertMessage = Text("Kan inte raderas!")
                primaryButtonText = ""
                primaryAction = {}
            }

            if treatment.type == .resume {
                alertTitle = Text("Pumphändelse")
                alertMessage = Text("Kan inte raderas!")
                primaryButtonText = ""
                primaryAction = {}
            }

            if treatment.type == .fpus {
                let fpus = state.treatments
                let carbEquivalents = fpuFormatter.string(from: Double(
                    fpus.filter { fpu in
                        fpu.fpuID == treatment.fpuID
                    }
                    .map { fpu in
                        fpu.amount ?? 0 }
                    .reduce(0, +)
                ) as NSNumber)!

                alertTitle = Text("Radera Protein/Fett?")
                alertMessage = Text(carbEquivalents + NSLocalizedString(" g", comment: "gram of carbs"))
                primaryButtonText = "Radera"
                primaryAction = {
                    state.deleteCarbs(treatment)
                }
            }

            removeTreatmentsAlert = Alert(
                title: alertTitle,
                message: alertMessage,
                primaryButton: .destructive(
                    Text(primaryButtonText),
                    action: primaryAction
                ),
                secondaryButton: .cancel()
            )

            isRemoveTreatmentsAlertPresented = true
        }

        private func deleteGlucose(at offsets: IndexSet) {
            let glucose = state.glucose[offsets[offsets.startIndex]]
            let glucoseValue = glucoseFormatter.string(from: Double(
                state.units == .mmolL ? Double(glucose.glucose.value.asMmolL) : glucose.glucose.value
            ) as NSNumber)! + " " + state.units.rawValue

            removeGlucoseAlert = Alert(
                title: Text("Radera blodsockervärde?"),
                message: Text(glucoseValue),
                primaryButton: .destructive(
                    Text("Radera"),
                    action: { state.deleteGlucose(glucose) }
                ),
                secondaryButton: .cancel()
            )

            isRemoveGlucoseAlertPresented = true
        }
    }
}
