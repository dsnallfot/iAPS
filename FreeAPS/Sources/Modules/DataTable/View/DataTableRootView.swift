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
        @State private var isEditSheetPresented: Bool = false
        @State var pushed = false
        @State private var selectedCarbAmount: Decimal = 0.0 // New
        @State private var selectedDate = Date() // New
        @State private var selectedNote: String = "" // New
        @State private var selectedFat: Decimal = 0.0 // New
        @State private var selectedProtein: Decimal = 0.0 // New
        @State private var isFatProteinEnabled: Bool = false // Add a state variable for the toggle

        @Environment(\.colorScheme) var colorScheme

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        private var glucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
                formatter.roundingMode = .halfUp
            } else {
                formatter.maximumFractionDigits = 0
            }
            return formatter
        }

        private var manualGlucoseFormatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            if state.units == .mmolL {
                formatter.maximumFractionDigits = 1
                formatter.roundingMode = .ceiling
            } else {
                formatter.maximumFractionDigits = 0
            }
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
            .onDisappear {
                state.apsManager
                    .determineBasalSync() // Daniel: Added to force update of COB/IOB etc in homeview/chart when leaving datatable view
            }

            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    switch state.mode {
                    case .treatments:
                        Button(
                            action: { showNonPumpInsulin = true
                                state.nonPumpInsulinDate = Date() },
                            label: {
                                Image(systemName: "plus.circle")
                                    .scaleEffect(0.61)
                                    .font(Font.title.weight(.regular))
                                    .offset(x: -11, y: 0)
                                Text("Insulin")
                                    .offset(x: -22, y: 0)
                            }
                        )
                    case .basals:
                        Button(
                            action: {},
                            label: {
                                Text("")
                            }
                        )
                    case .glucose:
                        Button(
                            action: { showManualGlucose = true
                                state.manualGlucose = 0 },
                            label: {
                                Image(systemName: "plus.circle")
                                    .scaleEffect(0.61)
                                    .font(Font.title.weight(.regular))
                                    .offset(x: -11, y: 0)
                                Text("Glukos")
                                    .offset(x: -22, y: 0)
                            }
                        )
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(
                        action: { state.hideModal() },
                        label: {
                            Text("Close")
                        }
                    )
                }
            }
            .sheet(isPresented: $showManualGlucose, onDismiss: { if isAmountUnconfirmed { state.manualGlucose = 0 } }) {
                addManualGlucoseView
            }
            .sheet(isPresented: $showNonPumpInsulin, onDismiss: { if isAmountUnconfirmed { state.nonPumpInsulinAmount = 0 } }) {
                addNonPumpInsulinView
            }
            .sheet(isPresented: $isEditSheetPresented) {
                editPresetPopover
                    .padding()
            }
        }

        var editPresetPopover: some View {
            Form {
                Section(
                    header: Text("Ändra måltid"),
                    footer: Text(
                        "Om du väljer att ändra fett och protein raderas tidigare registrerad fett och protein för den aktuella måltiden"
                    )
                ) {
                    HStack {
                        Text("Kolhydrater")
                        Spacer()
                        DecimalTextField("0", value: $selectedCarbAmount, formatter: formatter, cleanInput: true)
                        Text("g")
                    }

                    Toggle("Ändra fett och protein?", isOn: $isFatProteinEnabled) // Add the toggle

                    if isFatProteinEnabled { // Conditionally display the Fett and Protein fields
                        HStack {
                            Text("Fett")
                                .foregroundColor(.brown)
                            Spacer()
                            DecimalTextField("0", value: $selectedFat, formatter: formatter, cleanInput: true)
                            Text("g")
                                .foregroundColor(.brown)
                        }
                        HStack {
                            Text("Protein")
                                .foregroundColor(.brown)
                            Spacer()
                            DecimalTextField("0", value: $selectedProtein, formatter: formatter, cleanInput: true)
                            Text("g")
                                .foregroundColor(.brown)
                        }
                    }

                    HStack {
                        Text("Notering")
                        TextField("...", text: $selectedNote)
                            .multilineTextAlignment(.trailing) // Aligns the text within the TextField to the trailing edge
                            .padding(.leading) // Optional: Adds padding to the leading side of the TextField
                    }
                    HStack {
                        Text("Tid")
                        Spacer()
                        DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
                Section {
                    Button("Spara ändringar") {
                        if let treatmentToDelete = alertTreatmentToDelete {
                            // Delete the carb entry directly
                            state.deleteCarbs(treatmentToDelete)
                            alertTreatmentToDelete = nil // Reset the alert treatment
                        }
                        // Append "✩" to the note
                        let updatedNote = "✩" + selectedNote
                        // Call the addCarbsEntry function from DataTable.StateModel
                        state.addCarbsEntry(
                            amount: selectedCarbAmount,
                            date: selectedDate,
                            fat: selectedFat,
                            protein: selectedProtein,
                            note: updatedNote
                        ) // Updated
                        isEditSheetPresented = false
                    }

                    Button("Cancel") {
                        isEditSheetPresented = false
                    }
                    .tint(.red)
                }
            }
            .onAppear {
                if let treatmentToDelete = alertTreatmentToDelete {
                    selectedDate = treatmentToDelete.date // Set the initial date
                    selectedNote = treatmentToDelete.note ?? "" // Set the initial note
                    // selectedFat = treatmentToDelete.fat ?? 0.0 // Set the initial fat
                    // selectedProtein = treatmentToDelete.protein ?? 0.0 // Set the initial protein
                }
            }
            .onDisappear {}
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
                                    formatter: manualGlucoseFormatter,
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
                                label: { Text("Logga blodsockermätning") }
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .fontWeight(.semibold)
                            .font(.title3)
                            .listRowBackground(
                                state.manualGlucose < limitLow || state
                                    .manualGlucose > limitHigh ? AnyView(Color(.systemGray4))
                                    : AnyView(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                            Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                            Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                            Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                            Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .tint(.white)
                            .disabled(
                                state.manualGlucose < limitLow || state
                                    .manualGlucose > limitHigh
                            )
                        }
                    }
                }
                .onAppear {
                    // Set the manualGlucoseDate to the current date and time
                    state.manualGlucoseDate = Date()
                    configureView()
                }
                .navigationTitle("Blodsockermätning")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancel", action: { showManualGlucose = false
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
                                            !(state.nonPumpInsulinAmount > state.maxBolus) ? "Logga insulindos" :
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
                                    .maxBolus * 3 ? AnyView(Color(.systemGray4))
                                    : AnyView(LinearGradient(
                                        gradient: Gradient(colors: [
                                            Color(red: 0.7215686275, green: 0.3411764706, blue: 1),
                                            Color(red: 0.6235294118, green: 0.4235294118, blue: 0.9803921569),
                                            Color(red: 0.4862745098, green: 0.5450980392, blue: 0.9529411765),
                                            Color(red: 0.3411764706, green: 0.6666666667, blue: 0.9254901961),
                                            Color(red: 0.262745098, green: 0.7333333333, blue: 0.9137254902)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                            )
                            .tint(.white)
                        }
                    }
                }
                .onAppear {
                    // Set the nonPumpInsulinDate to the current date and time
                    state.nonPumpInsulinDate = Date()
                    configureView()
                }
                .navigationTitle("Externt insulin")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancel", action: { showNonPumpInsulin = false
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
                if state.treatments.contains(where: { $0.date > Date() }) {
                    HStack {
                        Button(action: { showFutureEntries.toggle() }, label: {
                            Text("")
                            Spacer()
                            Text(showFutureEntries ? "Dölj framtida" : "Visa framtida")
                                .foregroundColor(colorScheme == .dark ? .accentColor : .accentColor)
                                .font(.footnote)
                            Image(
                                systemName: showFutureEntries ? "chevron.up.circle" : "chevron.down.circle"
                            )
                            .foregroundColor(colorScheme == .dark ? .accentColor : .accentColor)
                            .font(.footnote)
                            Spacer()

                        })
                            .buttonStyle(.borderless)
                    }
                    // .listRowBackground(Color(.tertiarySystemFill))
                }

                if !state.treatments.isEmpty {
                    if !showFutureEntries {
                        ForEach(state.treatments.filter { item in
                            item.date <= Date()
                        }) { item in
                            treatmentView(item)
                        }
                    } else {
                        ForEach(state.treatments) { item in
                            treatmentView(item)
                        }
                    }
                } else {
                    HStack {
                        Text("Ingen data")
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
                    // .listRowBackground(Color(.tertiarySystemBackground))

                } else {
                    HStack {
                        Text("Ingen data")
                    }
                }
            }
        }

        private var glucoseList: some View {
            List {
                if !state.glucose.isEmpty {
                    ForEach(state.glucose) { item in
                        glucoseView(item, isManual: item.glucose)
                    }
                    // .listRowBackground(Color(.tertiarySystemBackground))
                } else {
                    HStack {
                        Text("Ingen data")
                    }
                }
            }
        }

        @ViewBuilder private func treatmentView(_ item: Treatment) -> some View {
            HStack {
                if item.isSMB ?? false { Image(systemName: "bolt.circle.fill").foregroundColor(item.color) }
                else { Image(systemName: "circle.fill").foregroundColor(item.color) }

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
                            alertMessage = item.amountText + " • " + dateFormatter.string(from: item.date)
                        } else if item.type == .fpus {
                            alertTitle = "Radera Fett & Protein?"
                            alertMessage = "All registrerad fett och protein i måltiden kommer att raderas."
                        } else {
                            // item is insulin treatment; item.type == .bolus
                            alertTitle = "Radera insulin?"
                            if item.isSMB ?? false {
                                // If it's an SMB, add SMB first and then the rest
                                alertMessage = item.amountText + " • SMB • " + dateFormatter.string(from: item.date)
                            } else {
                                // If it's not an SMB, add the rest as before
                                alertMessage = item.amountText + " • " + dateFormatter.string(from: item.date)
                            }
                        }
                        isRemoveHistoryItemAlertPresented = true
                    }
                ).tint(.red)
                if item.type == .carbs {
                    Button(
                        "Redigera",
                        systemImage: "square.and.pencil",
                        action: {
                            isEditSheetPresented = true
                            selectedCarbAmount = item.amount ?? 0.0
                            alertTreatmentToDelete = item // Ensure the treatment is set for deletion
                            print("Swipe for att ändra Kolhydrater")

                            // Fetch connected .fpus entries
                            let connectedFpus = state.fetchConnectedFpus(forDate: item.date)
                            print("Connected .fpus entries: \(connectedFpus)")
                        }
                    ).tint(.blue)
                }
            }
            .disabled(item.type == .tempBasal || item.type == .tempTarget || item.type == .resume || item.type == .suspend)
            .alert(
                Text(alertTitle),
                isPresented: $isRemoveHistoryItemAlertPresented
            ) {
                Button("Avbryt", role: .cancel) {}
                Button("Radera", role: .destructive) {
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
                    (
                        isManual.type == GlucoseType.manual.rawValue ?
                            manualGlucoseFormatter :
                            glucoseFormatter
                    )
                    .string(from: Double(
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

                        let valueText = (
                            isManual.type == GlucoseType.manual.rawValue ?
                                manualGlucoseFormatter :
                                glucoseFormatter
                        ).string(from: Double(
                            state.units == .mmolL ? Double(item.glucose.value.asMmolL) : item.glucose.value
                        ) as NSNumber)! + " " + state.units.rawValue

                        alertTitle = "Radera glukosvärde?"
                        alertMessage = valueText + " • " + dateFormatter.string(from: item.glucose.dateString)

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
                    guard let glucoseToDelete = alertGlucoseToDelete else {
                        print("Cannot unwrap alertTreatmentToDelete!")
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
