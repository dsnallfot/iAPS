import SwiftUI

@available(watchOSApplicationExtension 9.0, *) struct CarbsView: View {
    @EnvironmentObject var state: WatchStateModel

    // Selected nutrient
    enum Selection: String {
        case none
        case carbs
        case protein
        case fat
    }

    @State var selection: Selection = .carbs
    @State var carbAmount = 0.0
    @State var fatAmount = 0.0
    @State var proteinAmount = 0.0
    @State var colorOfselection: Color = .darkGray
    // @State var displayPresets: Bool = false

    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximum = (state.maxCOB ?? 120) as NSNumber
        formatter.maximumFractionDigits = 0
        formatter.allowsFloats = false
        return formatter
    }

    var body: some View {
        VStack {
            // nutrient
            if state.displayFatAndProteinOnWatch {
                Spacer()
                carbs
                Spacer()
                fat
                Spacer()
                protein
            } else {
                Spacer()
                carbs
            }
            Spacer()
            buttonStack
        }
        .frame(maxHeight: .infinity, alignment: .bottom)
        .onAppear { carbAmount = 0 }
    }

    var nutrient: some View {
        HStack {
            switch selection {
            case .protein:
                Text("Protein")
            case .fat:
                Text("Fat")
            default:
                Text("Carbs")
            }
        }.font(.footnote).frame(maxWidth: .infinity, alignment: .center)
    }

    var carbs: some View {
        HStack {
            if selection == .carbs {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = carbAmount - 5
                    carbAmount = max(newValue, 0)
                } label: { Image(systemName: "minus").scaleEffect(1.25).fontWeight(.bold) }
                    .buttonStyle(.borderless).padding(.leading, 13)
                    .tint(selection == .carbs ? .blue : .none)
            }
            Spacer()
            Text("Kh").font(selection == .carbs ? .title3 : .headline)
            Text(numberFormatter.string(from: carbAmount as NSNumber)! + " g")
                .font(selection == .carbs ? .title3 : .headline)
                .focusable(selection == .carbs)
                .digitalCrownRotation(
                    $carbAmount,
                    from: 0,
                    through: Double(state.maxCarbs ?? 120),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            Spacer()
            if selection == .carbs {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = carbAmount + 5
                    carbAmount = min(newValue, Double(state.maxCarbs ?? 120))
                } label: { Image(systemName: "plus").scaleEffect(1.35).fontWeight(.bold) }
                    .buttonStyle(.borderless).padding(.trailing, 18)
                    .tint(selection == .carbs ? .blue : .none)
            }
        }
        .onTapGesture {
            select(entry: .carbs)
        }
        .background(selection == .carbs && state.displayFatAndProteinOnWatch ? colorOfselection : .black)
    }

    var protein: some View {
        HStack {
            if selection == .protein {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = proteinAmount - 5
                    proteinAmount = max(newValue, 0)
                } label: { Image(systemName: "minus").scaleEffect(1.25).fontWeight(.bold) }
                    .buttonStyle(.borderless).padding(.leading, 13)
                    .tint(selection == .protein ? .blue : .none)
            }
            Spacer()
            Text("🍗").font(selection == .protein ? .title3 : .headline)
            // Spacer()
            Text(numberFormatter.string(from: proteinAmount as NSNumber)! + " g")
                .font(selection == .protein ? .title3 : .headline)
                .foregroundStyle(.brown)
                .focusable(selection == .protein)
                .digitalCrownRotation(
                    $proteinAmount,
                    from: 0,
                    through: Double(state.maxCarbs ?? 120),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            Spacer()
            if selection == .protein {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = proteinAmount + 5
                    proteinAmount = min(newValue, Double(state.maxCarbs ?? 120))
                } label: { Image(systemName: "plus").scaleEffect(1.35).fontWeight(.bold) }.buttonStyle(.borderless)
                    .padding(.trailing, 18)
                    .tint(selection == .protein ? .blue : .none)
            }
        }
        .onTapGesture {
            select(entry: .protein)
        }
        .background(selection == .protein ? colorOfselection : .black)
    }

    var fat: some View {
        HStack {
            if selection == .fat {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = fatAmount - 5
                    fatAmount = max(newValue, 0)
                } label: { Image(systemName: "minus").scaleEffect(1.25).fontWeight(.bold) }
                    .buttonStyle(.borderless).padding(.leading, 13)
                    .tint(selection == .fat ? .blue : .none)
            }
            Spacer()
            Text("🧀").font(selection == .fat ? .title3 : .headline)
            // Spacer()
            Text(numberFormatter.string(from: fatAmount as NSNumber)! + " g")
                .font(selection == .fat ? .title3 : .headline)
                .foregroundColor(.brown)
                .focusable(selection == .fat)
                .digitalCrownRotation(
                    $fatAmount,
                    from: 0,
                    through: Double(state.maxCarbs ?? 120),
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            Spacer()
            if selection == .fat {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    let newValue = fatAmount + 5
                    fatAmount = min(newValue, Double(state.maxCarbs ?? 120))
                } label: { Image(systemName: "plus").scaleEffect(1.35).fontWeight(.bold) }
                    .buttonStyle(.borderless).padding(.trailing, 18)
                    .tint(selection == .fat ? .blue : .none)
            }
        }
        .onTapGesture {
            select(entry: .fat)
        }
        .background(selection == .fat ? colorOfselection : .black)
    }

    var buttonStack: some View {
        HStack {
            Button {
                WKInterfaceDevice.current().play(.click)
                // Get amount from displayed string
                let amountCarbs = Int(numberFormatter.string(from: carbAmount as NSNumber)!) ?? Int(carbAmount.rounded())
                let amountFat = Int(numberFormatter.string(from: fatAmount as NSNumber)!) ?? Int(fatAmount.rounded())
                let amountProtein = Int(numberFormatter.string(from: proteinAmount as NSNumber)!) ??
                    Int(proteinAmount.rounded())
                state.addMeal(amountCarbs, fat: amountFat, protein: amountProtein)
            }
            label: { Text("Save")
                .frame(width: 100, height: 30)
            }
            .font(.title3.weight(.semibold))
            .foregroundColor(carbAmount > 0 || fatAmount > 0 || proteinAmount > 0 ? .blue : .secondary)
            .disabled(carbAmount <= 0 && fatAmount <= 0 && proteinAmount <= 0)

            .navigationTitle("Reg Måltid")
        }
    }

    private func select(entry: Selection) {
        selection = entry
    }
}

@available(watchOSApplicationExtension 9.0, *) struct CarbsView_Previews: PreviewProvider {
    static var previews: some View {
        let state = WatchStateModel()
        state.carbsRequired = 120
        return Group {
            CarbsView()
            CarbsView().previewDevice("Apple Watch Series 5 - 40mm")
            CarbsView().previewDevice("Apple Watch Series 3 - 38mm")
        }
        .environmentObject(state)
    }
}
