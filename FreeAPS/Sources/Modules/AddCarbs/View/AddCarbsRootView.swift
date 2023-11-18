import CoreData
import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        let editMode: Bool
        @StateObject var state = StateModel()
        @State var dish: String = ""
        @State var isPromptPresented = false
        @State private var note: String = ""
        @State var saved = false
        @State var pushed = false
        @State private var showAlert = false
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
                if let carbsReq = state.carbsRequired {
                    Section {
                        HStack {
                            Text("Carbs required").foregroundColor(.orange)
                            Spacer()
                            Text(formatter.string(from: carbsReq as NSNumber)! + " gram").foregroundColor(.orange)
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
                                    Text($0).foregroundStyle(Color.randomGreen()).font(.footnote)
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
                    .listRowBackground(Color(.loopYellow).opacity(0.3))

                    if state.useFPUconversion {
                        proteinAndFat()
                    }

                    mealPresets

                    HStack {
                        Button {
                            isPromptPresented = true
                        }
                        label: {
                            Text("Spara ny favorit  ") }
                            // .frame(maxWidth: .infinity, alignment: .leading)
                            .controlSize(.mini)
                            .buttonStyle(BorderlessButtonStyle())
                            .foregroundColor(
                                (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                    (
                                        (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                            .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) == state
                                            .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) ==
                                            state
                                            .protein
                                    ) ? Color(.systemGray2) : Color(.systemBlue)
                            )
                            .disabled(
                                (state.carbs <= 0 && state.fat <= 0 && state.protein <= 0) ||
                                    (
                                        (((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal) == state
                                            .carbs && (((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal) == state
                                            .fat && (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) == state
                                            .protein
                                    )
                            )
                        if state.selection != nil && state.useFPUconversion {
                            Button { showAlert.toggle() }

                            label: {
                                // Image(systemName: "trash")
                                // .offset(x: 5, y: 0)
                                Text("Radera favorit")
                                    .offset(x: 14, y: 0)
                            }
                            // .frame(maxWidth: .infinity, alignment: .leading)
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
                        }
                        Spacer()
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
                            state.add()
                        }
                    } label: {
                        HStack {
                            if state.carbs > state.maxCarbs || state.fat > state.maxCarbs || state.protein > state.maxCarbs {
                                Image(systemName: "x.circle.fill")
                                    .foregroundColor(.loopRed)
                            }
                            Text(
                                state.skipBolus ? "Save" :
                                    (
                                        (
                                            state.carbs <= state.maxCarbs && state.fat <= state.maxCarbs && state.protein <= state
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
                            .fat > state.maxCarbs || state.protein > state.maxCarbs ? Color(.systemGray4) : Color(.systemBlue)
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
            .navigationBarItems(trailing: Button("Close", action: state.hideModal))
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

        var mealPresets: some View {
            Section {
                HStack {
                    Text("")
                    Picker("Förval", selection: $state.selection) {
                        Text("Välj favorit").tag(nil as Presets?)
                        ForEach(carbPresets, id: \.self) { (preset: Presets) in
                            Text(preset.dish ?? "").tag(preset as Presets?)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // .pickerStyle(.automatic)
                    .foregroundColor(.primary)
                    .offset(x: -20, y: 0)
                    ._onBindingChange($state.selection) { _ in
                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal
                        state.note = state.selection?.note ?? "" // Set state.note to the selected note
                        state.addToSummation()
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
                    Button { state.date = state.date.addingTimeInterval(-10.minutes.timeInterval) }
                    label: { Image(systemName: "minus") }.tint(.blue).buttonStyle(.borderless)
                    DatePicker(
                        "Tid",
                        selection: $state.date,
                        displayedComponents: [.hourAndMinute]
                    ).controlSize(.mini)
                        .labelsHidden()
                    Button {
                        state.date = state.date.addingTimeInterval(10.minutes.timeInterval)
                    }
                    label: { Image(systemName: "plus") }.tint(.blue).buttonStyle(.borderless)
                }
            }
        }
    }
}

public extension Color {
    static func randomGreen(randomOpacity: Bool = false) -> Color {
        Color(
            red: .random(in: 0 ... 1),
            green: .random(in: 0.4 ... 0.7),
            blue: .random(in: 0.2 ... 1),
            opacity: randomOpacity ? .random(in: 0.8 ... 1) : 1
        )
    }
}
