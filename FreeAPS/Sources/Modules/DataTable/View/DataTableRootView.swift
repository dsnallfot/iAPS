import CoreData
import SwiftUI
import Swinject

extension DataTable {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()

        @State private var isRemoveHistoryItemAlertPresented: Bool = false
        @State private var alertTitle: String = ""
        @State private var alertMessage: String = ""
        @State private var alertTreatmentToDelete: Treatment?
        @State private var alertGlucoseToDelete: Glucose?
        @State private var showManualGlucose: Bool = false
        @State private var showNonPumpInsulin: Bool = false
        @State private var showFutureEntries: Bool = false
        @State private var isAmountUnconfirmed: Bool = true
        @State private var isEditSheetPresented: Bool = false
        @State var pushed = false
        @State private var selectedCarbAmount: Decimal = 0.0
        @State private var selectedDate = Date()
        @State private var selectedNote: String = ""
        @State private var selectedFat: Decimal = 0.0
        @State private var selectedProtein: Decimal = 0.0
        @State private var isFatProteinEnabled: Bool = false
        @State private var connectedFpus: [Treatment] = []
        // @State private var smbCount: Int = 0
        // @State private var smbGrams: Decimal = 0.0

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

        // Computed property to check if any value exceeds maxCarbs
        private var exceedsMaxCarbs: Bool {
            selectedCarbAmount > state.maxCarbs || selectedFat > state.maxCarbs || selectedProtein > state.maxCarbs
        }

        // Helper function to format maxCarbs
        private func formattedMaxCarbs() -> String {
            let numberFormatter = NumberFormatter()
            numberFormatter.maximumFractionDigits = 1
            numberFormatter.minimumFractionDigits = 1
            numberFormatter.numberStyle = .decimal
            return numberFormatter.string(from: state.maxCarbs as NSDecimalNumber) ?? "0.0"
        }

        /* // Helper function to format smbGrams
         private func formattedSmbGrams() -> String {
             let numberFormatter = NumberFormatter()
             numberFormatter.maximumFractionDigits = 1
             numberFormatter.minimumFractionDigits = 1
             numberFormatter.numberStyle = .decimal
             return numberFormatter.string(from: smbGrams as NSDecimalNumber) ?? "0.0"
         } */

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
            .onAppear {
                configureView()
            }
            .onDisappear {
                state.apsManager
                    .determineBasalSync()
                state.uploadEditedCarbs()
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
            }
        }

        /* var toggleText: String {
             smbCount > 0 ? "Ändra fett och protein?" : "Lägg till fett och protein?"
         } */

        var editPresetPopover: some View {
            NavigationView {
                VStack {
                    Form {
                        Section {
                            HStack {
                                Text("Kolhydrater")
                                Spacer()
                                DecimalTextField("0", value: $selectedCarbAmount, formatter: formatter, cleanInput: true)
                                Text("g")
                            }
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

                            HStack {
                                Text("Notering")
                                TextField("...", text: $selectedNote)
                                    .multilineTextAlignment(.trailing)
                                    .padding(.leading)
                            }
                            HStack {
                                Text("Tid")
                                Spacer()
                                DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                            }
                        }
                        Section {
                            if exceedsMaxCarbs {
                                HStack {
                                    Spacer()
                                    Image(systemName: "x.circle.fill")
                                        .foregroundColor(.red)
                                    Text("Inställd maxgräns: \(formattedMaxCarbs()) g")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                            } else {
                                HStack {
                                    Spacer()
                                    Button("Spara ändringar") {
                                        if let treatmentToDelete = alertTreatmentToDelete {
                                            state.deleteCarbs(treatmentToDelete)
                                            alertTreatmentToDelete = nil
                                        }
                                        let updatedNote = "✩" + selectedNote
                                        state.addCarbsEntry(
                                            amount: selectedCarbAmount,
                                            date: selectedDate,
                                            fat: selectedFat,
                                            protein: selectedProtein,
                                            note: updatedNote
                                        )
                                        state.deleteFpus(connectedFpus)
                                        isEditSheetPresented = false
                                    }
                                    Spacer()
                                }
                                .listRowBackground(
                                    AnyView(LinearGradient(
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
                        .fontWeight(.semibold)
                        .font(.title3)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
                .onAppear {
                    if let treatmentToDelete = alertTreatmentToDelete {
                        selectedDate = treatmentToDelete.date
                        selectedNote = treatmentToDelete.note ?? ""
                        selectedFat = treatmentToDelete.fat ?? 0.0
                        selectedProtein = treatmentToDelete.protein ?? 0.0
                        connectedFpus = state.fetchConnectedFpus(forDate: selectedDate)
                        // smbCount = connectedFpus.count
                        // smbGrams = connectedFpus.reduce(0) { $0 + ($1.amount ?? 0.0) }
                    }
                }
                .onDisappear {
                    selectedFat = 0.0
                    selectedProtein = 0.0
                    isFatProteinEnabled = false
                    // smbCount = 0
                    // smbGrams = 0.0
                }
                .navigationTitle("Ändra måltid")
                .navigationBarTitleDisplayMode(.inline)
                .navigationBarItems(trailing: Button("Cancel", action: { isEditSheetPresented = false }))
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
                                in: ...Date()
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
                                in: ...Date()
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
                            Text(showFutureEntries ? "Dölj kommande" : "Visa kommande")
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
            .swipeActions(edge: .trailing) {
                if item.type == .bolus || item.type == .carbs || item.type == .fpus {
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
                                alertTitle = "Radera insulin?"
                                if item.isSMB ?? false {
                                    alertMessage = item.amountText + " • SMB • " + dateFormatter.string(from: item.date)
                                } else {
                                    alertMessage = item.amountText + " • " + dateFormatter.string(from: item.date)
                                }
                            }
                            isRemoveHistoryItemAlertPresented = true
                        }
                    ).tint(.red)
                }
            }
            .swipeActions(edge: .leading) {
                if item.type == .carbs {
                    Button(
                        "Redigera",
                        systemImage: "square.and.pencil",
                        action: {
                            isEditSheetPresented = true
                            selectedCarbAmount = item.amount ?? 0.0
                            alertTreatmentToDelete = item
                            selectedDate = item.date
                            selectedNote = item.note ?? ""
                            // Fetch connected .fpus entries
                            connectedFpus = state.fetchConnectedFpus(forDate: item.date)
                            // smbCount = connectedFpus.count
                            // smbGrams = connectedFpus.reduce(0) { $0 + ($1.amount ?? 0.0) }
                        }
                    ).tint(.blue)
                }
            }
            // .disabled(item.type == .tempBasal || item.type == .tempTarget || item.type == .resume || item.type == .suspend)
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
