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
        @State private var newGlucose = false
        @State private var nonPumpInsulin = false

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
                leading: Button("Close", action: state.hideModal),
                trailing: HStack {
                    if state.mode == .treatments && !nonPumpInsulin {
                        Button(action: { nonPumpInsulin = true }) {
                            Text("Insulinpenna")
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                    }

                    if state.mode == .glucose && !newGlucose {
                        Button(action: { newGlucose = true }) {
                            Text("Fingerstick")
                            Image(systemName: "plus.circle.fill")
                                .resizable()
                                .frame(width: 24, height: 24)
                        }
                        Spacer()
                    }
                }
            )
            .sheet(isPresented: $newGlucose) {
                addManualGlucoseView
            }
            .sheet(isPresented: $nonPumpInsulin) {
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
                                    newGlucose = false
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
                .navigationBarItems(leading: Button("Close", action: { newGlucose = false
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
                                    nonPumpInsulin = false
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
                .navigationBarItems(leading: Button("Close", action: { nonPumpInsulin = false
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
                ForEach(state.treatments) { item in
                    treatmentView(item)
                }
                .onDelete(perform: deleteTreatments)
            }
            .alert(isPresented: $isRemoveTreatmentsAlertPresented) {
                removeTreatmentsAlert!
            }
        }

        private var basalsList: some View {
            List {
                ForEach(state.basals) { item in
                    basalView(item)
                }
            }
        }

        private var glucoseList: some View {
            List {
                ForEach(state.glucose) { item in
                    glucoseView(item)
                }
                .onDelete(perform: deleteGlucose)
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
                Text(item.glucose.direction?.symbol ?? "Finger")
                    .foregroundColor(
                        item.glucose.direction?.symbol != nil ? .secondary : .red
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
