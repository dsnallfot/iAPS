import CoreData
import SwiftUI
import Swinject

extension AddCarbs {
    struct RootView: BaseView {
        let resolver: Resolver
        @StateObject var state = StateModel()
        @State var dish: String = ""
        @State var isPromtPresented = false
        @State var saved = false
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

                    if state.useFPUconversion {
                        proteinAndFat()
                    }

                    DatePicker("Date", selection: $state.date)

                    HStack {
                        Button {
                            state.useFPUconversion.toggle()
                        }
                        label: {
                            Text(
                                state
                                    .useFPUconversion ? NSLocalizedString("Dölj detaljerad vy", comment: "") :
                                    NSLocalizedString("Visa detaljerad vy", comment: "")
                            ) }
                            .controlSize(.mini)
                            .buttonStyle(BorderlessButtonStyle())
                        Button {
                            isPromtPresented = true
                        }
                        label: { Text("Save as Preset") }
                            .frame(maxWidth: .infinity, alignment: .trailing)
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
                                    ) ? .secondary : .primary
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
                    }
                    .popover(isPresented: $isPromtPresented) {
                        presetPopover
                    }
                }

                Section {
                    let maxamountcarbs = Double(state.maxCarbs)
                    let formattedMaxAmountCarbs = String(format: "%.0f", maxamountcarbs)
                    Button { state.add() }
                    label: {
                        Text(
                            !(state.carbs > state.maxCarbs) ? "Save and continue" :
                                "Mer än inställd maxmängd \(formattedMaxAmountCarbs)g!"
                        )
                        .font(.title3.weight(.semibold)) }
                        .disabled(state.carbs <= 0 && state.fat <= 0 && state.protein <= 0 || state.carbs > state.maxCarbs)
                        .frame(maxWidth: .infinity, alignment: .center)
                } footer: { Text(state.waitersNotepad().description) }
            }
            .onAppear(perform: configureView)
            .navigationTitle("Registrera måltid")
            .navigationBarItems(leading: Button("Close", action: state.hideModal))
        }

        var presetPopover: some View {
            Form {
                Section {
                    TextField("Name Of Dish", text: $dish)
                    Button {
                        saved = true
                        if dish != "", saved {
                            let preset = Presets(context: moc)
                            preset.dish = dish
                            preset.fat = state.fat as NSDecimalNumber
                            preset.protein = state.protein as NSDecimalNumber
                            preset.carbs = state.carbs as NSDecimalNumber
                            try? moc.save()
                            state.addNewPresetToWaitersNotepad(dish)
                            saved = false
                            isPromtPresented = false
                        }
                    }
                    label: { Text("Save") }
                    Button {
                        dish = ""
                        saved = false
                        isPromtPresented = false }
                    label: { Text("Cancel") }
                } header: { Text("Enter Meal Preset Name") }
            }
        }

        var mealPresets: some View {
            Section {
                VStack {
                    Picker("Meal Presets", selection: $state.selection) {
                        Text("Empty").tag(nil as Presets?)
                        ForEach(carbPresets, id: \.self) { (preset: Presets) in
                            Text(preset.dish ?? "").tag(preset as Presets?)
                        }
                    }
                    .pickerStyle(.automatic)
                    ._onBindingChange($state.selection) { _ in
                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal
                        state.addToSummation()
                    }
                }
                HStack {
                    Button("Delete Preset") {
                        showAlert.toggle()
                    }
                    .disabled(state.selection == nil)
                    .accentColor(.orange)
                    .buttonStyle(BorderlessButtonStyle())
                    .controlSize(.mini)
                    .alert(
                        "Delete preset '\(state.selection?.dish ?? "")'?",
                        isPresented: $showAlert,
                        actions: {
                            Button("No", role: .cancel) {}
                            Button("Yes", role: .destructive) {
                                state.deletePreset()

                                state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                                state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                                state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                                state.addPresetToNewMeal()
                            }
                        }
                    )
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
                           (state.protein - (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal) as Decimal) >= 0
                        {
                            state.protein -= (((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal)
                        } else { state.protein = 0 }

                        state.removePresetFromNewMeal()
                        if state.carbs == 0, state.fat == 0, state.protein == 0 { state.summation = [] }
                    }
                    label: { Text("[ -1 ]") }
                        .disabled(
                            state
                                .selection == nil ||
                                (
                                    !state.summation.contains(state.selection?.dish ?? "") && (state.selection?.dish ?? "") != ""
                                )
                        )
                        .buttonStyle(BorderlessButtonStyle())
                        .controlSize(.mini)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .accentColor(.minus)
                    Button {
                        state.carbs += ((state.selection?.carbs ?? 0) as NSDecimalNumber) as Decimal
                        state.fat += ((state.selection?.fat ?? 0) as NSDecimalNumber) as Decimal
                        state.protein += ((state.selection?.protein ?? 0) as NSDecimalNumber) as Decimal

                        state.addPresetToNewMeal()
                    }
                    label: { Text("[ +1 ]") }
                        .disabled(state.selection == nil)
                        .buttonStyle(BorderlessButtonStyle())
                        .controlSize(.mini)
                        .accentColor(.blue)
                }
            }
        }

        @ViewBuilder private func proteinAndFat() -> some View {
            HStack {
                Text("Fat").foregroundColor(.orange) // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.fat,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                )
                Text("grams")
            }
            HStack {
                Text("Protein").foregroundColor(.red) // .fontWeight(.thin)
                Spacer()
                DecimalTextField(
                    "0",
                    value: $state.protein,
                    formatter: formatter,
                    autofocus: false,
                    cleanInput: true
                ).foregroundColor(.loopRed)

                Text("grams")
            }
            HStack {
                Text("Notering").foregroundColor(.primary)
                TextField("Emoji eller kort text", text: $state.note).multilineTextAlignment(.trailing)
                if state.note != "", isFocused {
                    Button { isFocused = false } label: {
                        Image(systemName: "keyboard.chevron.compact.down") }
                        .controlSize(.mini)
                }
            }.focused($isFocused)
            Section {
                mealPresets
            }
        }
    }
}
