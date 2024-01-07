import CoreData
import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        let editMode: Bool
        let override: Bool
        @StateObject var state = StateModel()
        @State var dish: String = ""
        @State var isPromptPresented = false
        @State private var note: String = ""
        @State var saved = false
        @State var pushed = false
        @State private var showAlert = false
        @State private var isTapped: Bool = false
        @FocusState private var isFocused: Bool

        @Environment(\.colorScheme) var colorScheme

        @FetchRequest(
            entity: Presets.entity(),
            sortDescriptors: [NSSortDescriptor(key: "dish", ascending: true)]
        ) var carbPresets: FetchedResults<Presets>

        @Environment(\.managedObjectContext) var moc

        private var formatter: NumberFormatter {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            return formatter
        }

        var body: some View {
            Form {
                if state.overrideActive {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .padding(.trailing, 8)
                            Text(
                                "En aktiv override modifierar just nu din insulinkänslighet och/eller kolhydratskvot. \nOm du inte vill att detta ska påverka hur insulindosen beräknas för måltiden bör du stänga av overriden innan du fortsätter."
                            )
                            .font(.caption).foregroundColor(.secondary)
                        }
                        .onTapGesture(perform: { state.showModal(for: .overrideProfilesConfig)
                        })
                    }
                }

                if let carbsReq = state.carbsRequired, state.carbs < carbsReq {
                    Section {
                        HStack {
                            Text("Carbs required").foregroundColor(.orange)
                            Spacer()
                            Text((formatter.string(from: carbsReq as NSNumber) ?? "") + " gram").foregroundColor(.orange)
                                .gesture(TapGesture().onEnded {
                                    self.isTapped.toggle()
                                    if isTapped {
                                        state.carbs = carbsReq
                                    }
                                })
                        }
                    }
                }

                // Summary when combining presets
                if state.waitersNotepad() != "" {
                    Section(header: Text("Valda favoriter")) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            let test = state.waitersNotepad().components(separatedBy: ", ").removeDublicates()
                            HStack(spacing: 0) {
                                ForEach(test, id: \.self) {
                                    Text($0).foregroundStyle(Color.randomVibrantColor()).font(.footnote)
                                    Text($0 == test[test.count - 1] ? "" : " • ")
                                }
                            }.frame(maxWidth: .infinity, alignment: .center)
                        }
                    }
                }

                Section {
                    HStack {
                        Text("Carbs").fontWeight(.semibold)
                        Spacer()
                        DecimalTextField(
                            "0",
                            value: $state.carbs,
                            formatter: formatter,
                            autofocus: true,
                            cleanInput: true
                        )
                        Text("grams").fontWeight(.semibold)
                    }
                    .listRowBackground(Color(.loopYellow).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 11) // Adjust the corner radius as needed
                            .stroke(lineWidth: 7)
                            .padding(.leading, -16)
                            .padding(.trailing, -16)
                            .padding(.top, -4)
                            .padding(.bottom, -4)
                            .foregroundColor(colorScheme == .dark ? .primary : .white)
                    )

                    if state.useFPUconversion {
                        proteinAndFat()
                    }
                }
                Section {
                    mealPresets

                    HStack {
                        if state.selection != nil && state.useFPUconversion {
                            Button { showAlert.toggle() }

                            label: {
                                // Image(systemName: "trash")
                                // .offset(x: 5, y: 0)
                                Text("Radera favorit")
                            }
                            .frame(alignment: .leading)
                            .disabled(state.selection == nil)
                            .accentColor(.loopRed)
                            .buttonStyle(BorderlessButtonStyle())
                            .controlSize(.mini)
                            .alert(
                                "Radera favorit '\(state.selection?.dish ?? "")'?",
                                isPresented: $showAlert,
                                actions: {
                                    Button("No", role: .cancel) {}
                                    Button("Yes", role: .destructive) {
                                        state.deletePreset()

                                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                                        // Handle note addition here
                                        state.note = state.selection?.note ?? "" // Set state.note to the selected note

                                        state.addPresetToNewMeal()
                                    }
                                }
                            )
                        } else
                        {
                            Button {
                                isPromptPresented = true
                            }
                            label: {
                                Text("Spara ny favorit") }
                                .frame(alignment: .leading)
                                .controlSize(.mini)
                                .buttonStyle(BorderlessButtonStyle())
                                .foregroundColor(
                                    (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                        (
                                            (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                                .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .protein
                                        ) ? Color(.systemGray2) : Color(.systemBlue)
                                )
                                .disabled(
                                    (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                        (
                                            (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                                .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) ==
                                                state
                                                .protein
                                        )
                                )
                        }
                        Spacer()
                        Button {
                            state.useFPUconversion.toggle()
                        }
                        label: {
                            Text(
                                state.useFPUconversion ? NSLocalizedString("Dölj", comment: "") :
                                    NSLocalizedString("Visa mer", comment: "")
                            )
                            .foregroundColor(.accentColor)
                            Image(
                                systemName: state.useFPUconversion ? "chevron.up.circle" : "chevron.down.circle"
                            )
                            .foregroundColor(.accentColor)
                        }
                        .controlSize(.mini)
                        .buttonStyle(BorderlessButtonStyle())
                    }
                    .popover(isPresented: $isPromptPresented) {
                        presetPopover
                    }
                }

                Section {
                    let maxamountcarbs = Double(state.maxCarbs)
                    let formattedMaxAmountCarbs = String(format: "%.0f", maxamountcarbs)
                    Button {
                        if state.carbs <= state.maxCarbs {
                            // Only allow button click if carbs are within maxCarbs
                            state.add(override, fetch: editMode)
                        }
                    } label: {
                        HStack {
                            if state.carbs > state.maxCarbs || state.fat > state.maxCarbs || state.protein > state.maxCarbs {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.loopRed)
                            }
                            Text(
                                (state.skipBolus && !override && !editMode) ? "Save" :
                                    (
                                        (
                                            state.carbs <= state.maxCarbs && state.fat <= state.maxCarbs && state
                                                .protein <= state
                                                .maxCarbs
                                        ) ?
                                            "Fortsätt" :
                                            "Inställd maxgräns: \(formattedMaxAmountCarbs)g"
                                    )
                            )
                            .fontWeight(.semibold)
                            .font(.title3)
                        }
                    }
                    .disabled(
                        state.carbs <= 0 && state.fat <= 0 && state.protein <= 0 || state.carbs > state.maxCarbs || state
                            .fat > state.maxCarbs || state.protein > state.maxCarbs
                    )
                    .listRowBackground(
                        state.carbs <= 0 && state.fat <= 0 && state.protein <= 0 || state.carbs > state.maxCarbs || state
                            .fat > state.maxCarbs || state.protein > state.maxCarbs ? Color(.systemGray4) : Color(.insulin)
                    )
                    .tint(.white)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }

            .onAppear {
                configureView {
                    state.loadEntries(editMode)
                }
            }
            .navigationTitle("Registrera måltid")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Cancel", action: state.hideModal))
        }

        var presetPopover: some View {
            Form {
                Section {
                    TextField("Name Of Dish", text: $dish)
                        .onAppear {
                            // Set initial text of the TextField
                            if !state.note.isEmpty {
                                dish = state.note
                            }
                        }

                    Button {
                        saved = true
                        if dish != "", saved {
                            let preset = Presets(context: moc)
                            preset.dish = dish
                            preset.fat = state.fat as NSDecimalNumber
                            preset.protein = state.protein as NSDecimalNumber
                            preset.carbs = state.carbs as NSDecimalNumber

                            // Set the note property
                            preset.note = state.note

                            try? moc.save()
                            state.addNewPresetToWaitersNotepad(dish)
                            saved = false
                            isPromptPresented = false
                        }
                    } label: {
                        Text("Save")
                    }

                    Button {
                        dish = ""
                        saved = false
                        isPromptPresented = false
                    } label: {
                        Text("Cancel")
                    }
                } header: {
                    Text("Spara ny favorit")
                }
            }
        }

        private var mealPresets: some View {
            Section {
                HStack {
                    Picker("", selection: $state.selection) {
                        Text("Välj favorit").tag(nil as Presets?)
                        ForEach(carbPresets, id: \.self) { (preset: Presets) in
                            Text(preset.dish ?? "").tag(preset as Presets?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // .pickerStyle(.automatic)
                    .foregroundColor(.primary)
                    .offset(x: -12, y: 0)
                    ._onBindingChange($state.selection) { _ in
                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal
                        state.note = state.selection?.note ?? "" // Set state.note to the selected note
                        state.addToSummation()
                    }
                    .onChange(of: state.carbs) { newValue in
                        // Check if the value is zero and update the selection accordingly
                        if newValue == 0 {
                            state.selection = nil
                        }
                    }
                    if state.selection != nil {
                        Button {
                            if state.carbs != 0,
                               (state.carbs - (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) as Decimal) >= 0
                            {
                                state.carbs -= (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.carbs = 0 }

                            if state.fat != 0,
                               (state.fat - (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) as Decimal) >= 0
                            {
                                state.fat -= (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.fat = 0 }

                            if state.protein != 0,
                               (
                                   state
                                       .protein - (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) as Decimal
                               ) >=
                               0
                            {
                                state.protein -= (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal)
                            } else { state.protein = 0 }

                            // Handle note removal here
                            state.note = "" // Reset state.note

                            state.removePresetFromNewMeal()
                            if state.carbs == 0, state.fat == 0, state.protein == 0 { state.summation = [] }
                        }
                        label: {
                            Image(systemName: "minus")
                        }
                        .disabled(
                            state
                                .selection == nil ||
                                (
                                    !state.summation
                                        .contains(state.selection?.dish ?? "") && (state.selection?.dish ?? "") != ""
                                )
                        )
                        .tint(.blue)
                        .buttonStyle(.borderless)
                        Text("   Antal    ")
                            .foregroundColor(.secondary)
                        Button {
                            state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                            state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                            state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                            // Handle note addition here
                            state.note = state.selection?.note ?? "" // Set state.note to the selected note

                            state.addPresetToNewMeal()
                        }
                        label: {
                            Image(systemName: "plus")
                        }
                        .disabled(state.selection == nil)
                        .tint(.blue)
                        .buttonStyle(.borderless)
                    }
                }
            }
        }

        @ViewBuilder private func proteinAndFat() -> some View {
            HStack {
                Text("Fat") // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.fat,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                )
                Text("grams")
            }.foregroundColor(.brown)
            HStack {
                Text("Protein") // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.protein,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                )
                Text("grams")
            }.foregroundColor(.brown)
            HStack {
                Text("Notering").foregroundColor(.primary)
                TextField("...", text: $state.note).multilineTextAlignment(.trailing)
                if state.note != "", isFocused {
                    Button { isFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down") }
                        .controlSize(.mini)
                }
            }.focused($isFocused)
            // Time
            HStack {
                Text("Tid")
                Spacer()
                if !pushed {
                    Button {
                        pushed = true
                    } label: { Text("Nu") }.buttonStyle(.borderless).foregroundColor(.secondary)
                        .padding(.trailing, 5)
                } else {
                    Button { state.date = state.date.addingTimeInterval(-15.minutes.timeInterval) }
                    label: { Image(systemName: "minus") }.tint(.blue).buttonStyle(.borderless)
                    DatePicker(
                        "Tid",
                        selection: $state.date,
                        displayedComponents: [.hourAndMinute]
                    ).controlSize(.mini)
                        .labelsHidden()
                    Button {
                        state.date = state.date.addingTimeInterval(15.minutes.timeInterval)
                    }
                    label: { Image(systemName: "plus") }.tint(.blue).buttonStyle(.borderless)
                }
            }
        }
    }
}

public extension Color {
    static func randomVibrantColor(randomOpacity: Bool = false) -> Color {
        let baseColor = Color(
            red: Double.random(in: 0.5 ... 1),
            green: Double.random(in: 0.4 ... 0.6),
            blue: Double.random(in: 0.4 ... 1),
            opacity: 1
        )

        let vibrantColor = baseColor.adjusted(by: 0.2)

        return randomOpacity ? vibrantColor.withRandomOpacity() : vibrantColor
    }
}

extension Color {
    func adjusted(by factor: Double) -> Color {
        guard let components = UIColor(self).rgbaComponents else {
            return self
        }

        return Color(
            red: min(components.red + CGFloat(factor), 1),
            green: min(components.green + CGFloat(factor), 1),
            blue: min(components.blue + CGFloat(factor), 1),
            opacity: components.alpha
        )
    }

    func withRandomOpacity() -> Color {
        Color(
            red: Double.random(in: 0 ... 1),
            green: Double.random(in: 0 ... 1),
            blue: Double.random(in: 0 ... 1),
            opacity: Double.random(in: 0.8 ... 1)
        )
    }
}

extension UIColor {
    var rgbaComponents: (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat)? {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return nil
        }

        return (red, green, blue, alpha)
    }
}
