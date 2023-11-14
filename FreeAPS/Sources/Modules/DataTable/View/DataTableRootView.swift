import CoreData
import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var isRemoveHistoryItemAlertPresented: Bool = false // Ny
        @State private var alertTitle: String = "" // Ny
        @State private var alertMessage: String = "" // Ny
        @State private var alertTreatmentToDelete: Treatment? // Ny
        @State private var alertGlucoseToDelete: Glucose? // Ny
        @State private var showManualGlucose: Bool = false
        @State private var showNonPumpInsulin: Bool = false
        @State private var showFutureEntries: Bool = false
        @State private var isAmountUnconfirmed: Bool = true

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
                trailing: HStack {
                    Button("Close", action: state.hideModal)
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
                            .font(.title3)
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
                .navigationBarItems(trailing: Button("Close", action: { showManualGlucose = false
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
                                    "...",
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
                                        .font(.title3)
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
                .navigationBarItems(trailing: Button("Close", action: { showNonPumpInsulin = false
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
                        Text("Insulin")
                            .font(.subheadline)
                    })
                        .buttonStyle(.borderless)

                    Spacer()

                    if state.treatments.contains(where: { $0.date > Date() }) {
                        Button(action: { showFutureEntries.toggle() }, label: {
                            Text(showFutureEntries ? "Dölj kommande" : "Visa kommande")
                                .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                                .font(.footnote)
                            Image(
                                systemName: showFutureEntries ? "chevron.up.circle" : "chevron.down.circle"
                            )
                            .foregroundColor(colorScheme == .dark ? .secondary : .secondary)
                            .font(.footnote)

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
                    } else {
                        ForEach(state.treatments) { item in
                            treatmentView(item)
                                .listRowBackground(
                                    item.date > Date() ? Color(.systemGray4) : Color(.systemGray5)
                                )
                        }
                    }
                } else {
                    HStack {
                        Text("Ingen data.")
                    }
                }
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
        }

        private var glucoseList: some View {
            List {
                HStack {
                    Button(action: { showManualGlucose = true }, label: {
                        Image(systemName: "plus.circle.fill")
                        Text("Fingerstick")
                            .font(.subheadline)
                    })
                        .buttonStyle(.borderless)
                }
                .listRowBackground(Color(.tertiarySystemBackground))

                if !state.glucose.isEmpty {
                    ForEach(state.glucose) { item in
                        glucoseView(item, isManual: item.glucose)
                    }
                } else {
                    HStack {
                        Text("Ingen data.")
                    }
                }
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
                    "Radera",
                    systemImage: "trash.fill",
                    role: .none,
                    action: {
                        alertTreatmentToDelete = item
                        if item.type == .carbs {
                            alertTitle = "Radera kolhydrater?"
                            alertMessage = dateFormatter.string(from: item.date) + " • " + item.amountText
                        } else if item.type == .fpus {
                            alertTitle = "Radera Fett & Protein?"
                            alertMessage = "All registrerad fett och protein i måltiden kommer att raderas."
                        } else {
                            // item is insulin treatment; item.type == .bolus
                            alertTitle = "Radera insulin?"
                            alertMessage = dateFormatter.string(from: item.date) + " • " + item.amountText
                            if item.isSMB ?? false {
                                // Add text snippet, so that alert message is more descriptive for SMBs
                                alertMessage += "• SMB"
                            }
                        }
                        isRemoveHistoryItemAlertPresented = true
                    }
                ).tint(.red)
            }
            .disabled(item.type == .tempBasal || item.type == .tempTarget || item.type == .resume || item.type == .suspend)
            .alert(
                Text(alertTitle),
                isPresented: $isRemoveHistoryItemAlertPresented
            ) {
                Button("Avbryt", role: .cancel) {}
                Button("Radera", role: .destructive) {
                    // gracefully unwrap value here.
                    // value cannot ever really be nil because it is an existing(!) table entry
                    // but just to be sure.
                    guard let treatmentToDelete = alertTreatmentToDelete else {
                        print("Cannot gracefully unwrap alertTreatmentToDelete!")
                        return
                    }

                    if treatmentToDelete.type == .carbs || treatmentToDelete.type == .fpus {
                        state.deleteCarbs(treatmentToDelete)
                    } else {
                        state.deleteInsulin(treatmentToDelete)
                    }
                }
            } message: {
                Text("\n" + alertMessage)
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
                if isManual.type == GlucoseType.manual.rawValue {
                    Image(systemName: "drop.fill").symbolRenderingMode(.monochrome).foregroundStyle(.red)
                } else {
                    Text(item.glucose.direction?.symbol ?? "--")
                }
                Spacer()

                Text(dateFormatter.string(from: item.glucose.dateString))
            }
            .swipeActions {
                Button(
                    "Radera",
                    systemImage: "trash.fill",
                    role: .none,
                    action: {
                        alertGlucoseToDelete = item

                        let valueText = glucoseFormatter.string(from: Double(
                            state.units == .mmolL ? Double(item.glucose.value.asMmolL) : item.glucose.value
                        ) as NSNumber)! + " " + state.units.rawValue

                        alertTitle = "Radera glukosvärde?"
                        alertMessage = dateFormatter.string(from: item.glucose.dateString) + " • " + valueText

                        isRemoveHistoryItemAlertPresented = true
                    }
                ).tint(.red)
            }
            .alert(
                Text(alertTitle),
                isPresented: $isRemoveHistoryItemAlertPresented
            ) {
                Button("Avbryt", role: .cancel) {}
                Button("Radera", role: .destructive) {
                    // gracefully unwrap value here.
                    // value cannot ever really be nil because it is an existing(!) table entry
                    // but just to be sure.
                    guard let glucoseToDelete = alertGlucoseToDelete else {
                        print("Cannot gracefully unwrap alertTreatmentToDelete!")
                        return
                    }
                    state.deleteGlucose(glucoseToDelete)
                }
            } message: {
                Text("\n" + alertMessage)
            }
        }
    }
}
