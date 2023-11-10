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
        @State private var isAmountUnconfirmed: Bool = true
        @State private var alertIsShown = false

        @Environment(\.colorScheme) var colorScheme

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
                formatter.roundingMode = .ceiling
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
            .onDisappear { state.apsManager.determineBasalSync()
            }

            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: HStack {
                    Button("Close", action: state.hideModal)
                },
                trailing: HStack {
                    /* if state.mode == .treatments {
                         Button(action: { showNonPumpInsulin = true }) {
                             Text("Insulin")
                             Image(systemName: "plus.circle.fill")
                                 .resizable()
                                 .frame(width: 24, height: 24)
                         }
                     } */

                    /* if state.mode == .glucose {
                         Button(action: { showManualGlucose = true }) {
                             Text("Fingerstick")
                             Image(systemName: "plus.circle.fill")
                                 .resizable()
                                 .frame(width: 24, height: 24)
                         }
                     } */
                }
            )
            .sheet(isPresented: $showManualGlucose, onDismiss: { if isAmountUnconfirmed { state.manualGlucose = 0 } }) {
                addManualGlucoseView
            }
            .sheet(isPresented: $showNonPumpInsulin, onDismiss: { if isAmountUnconfirmed { state.nonPumpInsulinAmount = 0 } }) {
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
                                    .fontWeight(.semibold)
                                DecimalTextField(
                                    " ... ",
                                    value: $state.manualGlucose,
                                    formatter: glucoseFormatter,
                                    autofocus: true
                                )
                                Text(state.units.rawValue).foregroundStyle(.primary)
                                    .fontWeight(.semibold)
                            }
                        }

                        Section {
                            DatePicker(
                                "Date",
                                selection: $state.manualGlucoseDate,
                                in: ...Date() // Disable selecting future dates
                            )
                        }

                        Section {
                            let limitLow: Decimal = state.units == .mmolL ? 1 : 18
                            let limitHigh: Decimal = state.units == .mmolL ? 40 : 720
                            HStack {
                                Button {
                                    state.addManualGlucose()
                                    isAmountUnconfirmed = false
                                    showManualGlucose = false
                                }
                                label: { Text("Logga värde från fingerstick") }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fontWeight(.semibold)
                            .listRowBackground(
                                state.manualGlucose < limitLow || state
                                    .manualGlucose > limitHigh ? Color(.systemGray4) : Color(.systemBlue)
                            )
                            .tint(.white)
                            .disabled(
                                state.manualGlucose < limitLow || state
                                    .manualGlucose > limitHigh
                            )
                        }
                    }
                }
                .onAppear(perform: configureView)
                .navigationTitle("Fingerstick")
                .navigationBarTitleDisplayMode(.inline)
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
                                    .fontWeight(.semibold)
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
                            DatePicker(
                                "Date",
                                selection: $state.nonPumpInsulinDate,
                                in: ...Date() // Disable selecting future dates
                            )
                        }

                        Section {
                            let maxamountbolus = Double(state.maxBolus)
                            let formattedMaxAmountBolus = String(maxamountbolus)
                            HStack {
                                Button {
                                    state.addNonPumpInsulin()
                                    isAmountUnconfirmed = false
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
                                        .fontWeight(.semibold)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .disabled(
                                state.nonPumpInsulinAmount <= 0 || state.nonPumpInsulinAmount > state
                                    .maxBolus * 3
                            )
                            .listRowBackground(
                                state.nonPumpInsulinAmount <= 0 || state.nonPumpInsulinAmount > state
                                    .maxBolus * 3 ? Color(.systemGray4) : Color(.systemBlue)
                            )
                            .tint(.white)
                        }
                    }
                }
                .onAppear(perform: configureView)
                .navigationTitle("Insulinpenna")
                .navigationBarTitleDisplayMode(.inline)
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
                HStack {
                    Button(action: { showNonPumpInsulin = true }, label: {
                        Image(systemName: "plus.circle.fill")
                        // .foregroundColor(colorScheme == .dark ? .primary : .primary)
                        Text("Insulin")
                            // .foregroundColor(colorScheme == .dark ? .primary : .primary)
                            .font(.subheadline)
                    })
                        .buttonStyle(.borderless)

                    Spacer()

                    if state.treatments.contains(where: { $0.date > Date() }) {
                        Button(action: { showFutureEntries.toggle() }, label: {
                            Text(showFutureEntries ? "Dölj kommande" : "Visa kommande")
                                .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                                .font(.subheadline)
                            Image(
                                systemName: showFutureEntries ? "chevron.down.circle" : "chevron.right.circle"
                            )
                            .foregroundColor(colorScheme == .dark ? .secondary : .secondary)

                        })
                            .buttonStyle(.borderless)
                    }
                }
                .listRowBackground(Color(.tertiarySystemBackground))

                if !state.treatments.isEmpty {
                    if !showFutureEntries {
                        ForEach(state.treatments.filter { item in
                            item.date <= Date()
                        }) { item in
                            treatmentView(item)
                                .listRowBackground(
                                    item.date > Date() ? Color(.tertiarySystemBackground) : Color(.secondarySystemBackground)
                                )
                        }
                        // .onDelete(perform: deleteTreatments)
                    } else {
                        ForEach(state.treatments) { item in
                            treatmentView(item)
                                .listRowBackground(
                                    item.date > Date() ? Color(.systemGray4) : Color(.systemGray5)
                                )
                        }
                        // .onDelete(perform: deleteTreatments)
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
                HStack {
                    Button(action: { showManualGlucose = true }, label: {
                        Image(systemName: "plus.circle.fill")
                        // .foregroundColor(colorScheme == .dark ? .primary : .primary)
                        Text("Fingerstick")
                            // .foregroundColor(colorScheme == .dark ? .primary : .primary)
                            .font(.subheadline)
                    })
                        .buttonStyle(.borderless)
                }
                .listRowBackground(Color(.tertiarySystemBackground))

                if !state.glucose.isEmpty {
                    ForEach(state.glucose) { item in
                        glucoseView(item, isManual: item.glucose)
                    }
                    // .onDelete(perform: deleteGlucose)
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
                if item.isSMB ?? false { Image(systemName: "bolt.circle.fill").foregroundColor(item.color) }
                else { Image(systemName: "circle.fill").foregroundColor(item.color)
                }

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
            .swipeActions {
                Button(
                    "Delete",
                    systemImage: "trash.fill",
                    role: .none,
                    action: {
                        if let index = state.treatments.firstIndex(of: item) {
                            deleteTreatments(at: IndexSet([index]))
                        }
                    }
                )
                .tint(.red)
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

        @ViewBuilder private func glucoseView(_ item: Glucose, isManual: BloodGlucose) -> some View {
            HStack {
                Text(item.glucose.glucose.map {
                    glucoseFormatter.string(from: Double(
                        state.units == .mmolL ? $0.asMmolL : Decimal($0)
                    ) as NSNumber)!
                } ?? "--")
                Text(state.units.rawValue)
                if isManual.type == GlucoseType.manual.rawValue {
                    Image(systemName: "drop.fill").symbolRenderingMode(.monochrome).foregroundStyle(.red)
                } else {
                    Text(item.glucose.direction?.symbol ?? "--")
                        .foregroundColor(item.glucose.direction?.symbol != nil ? .secondary : .orange)
                }
                Spacer()

                Text(dateFormatter.string(from: item.glucose.dateString))
            }
            .swipeActions {
                Button(
                    "Delete",
                    systemImage: "trash.fill",
                    role: .none,
                    action: {
                        if let index = state.glucose.firstIndex(of: item) {
                            deleteGlucose(at: IndexSet([index]))
                        }
                    }
                )
                .tint(.red)
            }
        }

        private func deleteTreatments(at offsets: IndexSet) {
            if let indexToDelete = offsets.first {
                let item = showFutureEntries ?
                    state.treatments[indexToDelete] :
                    state.treatments.filter { $0.date <= Date() }[indexToDelete]

                var alertTitle = Text("Radera insulin?")
                var alertMessage = Text(item.amountText)
                var primaryButtonText = "Radera"
                var primaryAction: () -> Void = {
                    state.deleteInsulin(item)
                }

                if item.type == .carbs {
                    alertTitle = Text("Radera kolhydrater?")
                    primaryButtonText = "Radera"
                    primaryAction = {
                        state.deleteCarbs(item)
                    }
                } else if item.type == .tempTarget {
                    alertTitle = Text("Tillfälligt mål")
                    alertMessage = Text("Kan inte raderas!")
                    primaryButtonText = ""
                    primaryAction = {}
                } else if item.type == .suspend {
                    alertTitle = Text("Pumphändelse")
                    alertMessage = Text("Kan inte raderas!")
                    primaryButtonText = ""
                    primaryAction = {}
                } else if item.type == .resume {
                    alertTitle = Text("Pumphändelse")
                    alertMessage = Text("Kan inte raderas!")
                    primaryButtonText = ""
                    primaryAction = {}
                } else if item.type == .fpus {
                    let carbEquivalents = fpuFormatter.string(from: Double(
                        state.treatments.filter { $0.type == .fpus && $0.fpuID == item.fpuID }
                            .map { $0.amount ?? 0 }
                            .reduce(0, +)
                    ) as NSNumber)!

                    alertTitle = Text("Radera Protein/Fett?")
                    alertMessage = Text(carbEquivalents + NSLocalizedString(" g", comment: "gram of carbs"))
                    primaryButtonText = "Radera"
                    primaryAction = {
                        state.deleteCarbs(item)
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
                    action: { state.deleteGlucose(at: offsets[offsets.startIndex]) }
                ),
                secondaryButton: .cancel()
            )

            isRemoveGlucoseAlertPresented = true
        }
    }
}
