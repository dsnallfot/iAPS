import SwiftUI

@available(watchOSApplicationExtension 9.0, *) struct BolusView: View {
    @EnvironmentObject var state: WatchStateModel

    @State var steps = 0.0

    var numberFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        formatter.maximum = Double((state.maxBolus ?? 5) / (state.bolusIncrement ?? 0.1)) as NSNumber
        formatter.maximumFractionDigits = (state.bolusIncrement ?? 0.1) > 0.05 ? 1 : 2
        formatter.minimumFractionDigits = (state.bolusIncrement ?? 0.1) > 0.05 ? 1 : 2
        formatter.allowsFloats = true
        formatter.roundingIncrement = Double(state.bolusIncrement ?? 0.1) as NSNumber
        return formatter
    }

    var body: some View {
        GeometryReader { _ in
            VStack { // }(spacing: 16) {
                Spacer()
                HStack {
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        let newValue = steps - 1
                        steps = max(newValue, 0)
                    } label: { Image(systemName: "minus").scaleEffect(1.25).fontWeight(.bold) }
                        .buttonStyle(.borderless).padding(.leading, 13)
                        .tint(.blue)

                    Spacer()
                    Text(numberFormatter.string(from: (steps * Double(state.bolusIncrement ?? 0.1)) as NSNumber)! + " E")
                        .font(.title3)
                        .focusable(true)
                        .digitalCrownRotation(
                            $steps,
                            from: 0,
                            through: Double((state.maxBolus ?? 5) / (state.bolusIncrement ?? 0.1)),
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )

                    Spacer()
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        let newValue = steps + 1
                        steps = min(newValue, Double((state.maxBolus ?? 5) / (state.bolusIncrement ?? 0.1)))
                    } label: { Image(systemName: "plus").scaleEffect(1.35).fontWeight(.bold) }
                        .buttonStyle(.borderless).padding(.trailing, 18)
                        .tint(.blue)
                }
                Spacer()
                HStack {
                    Button {
                        WKInterfaceDevice.current().play(.click)

                        state.isBolusViewActive = false
                    }
                    label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .foregroundColor(.loopRed)
                            .frame(width: 30, height: 30)
                    }
                    Button {
                        WKInterfaceDevice.current().play(.click)

                        enactBolus()
                    }
                    label: {
                        Image(systemName: "checkmark.circle.fill")
                            .resizable()
                            .foregroundColor(.loopGreen)
                            .frame(width: 30, height: 30)
                    }
                    .disabled(steps <= 0)
                }
            }.frame(maxHeight: .infinity, alignment: .bottom)
        }
        .navigationTitle("Enact Bolus")

        .onAppear {
            steps = Double((state.bolusRecommended ?? 0) / (state.bolusIncrement ?? 0.1))
        }
    }

    private func enactBolus() {
        let amount = steps * Double(state.bolusIncrement ?? 0.1)
        state.addBolus(amount: amount)
    }
}

@available(watchOSApplicationExtension 9.0, *) struct BolusView_Previews: PreviewProvider {
    static var previews: some View {
        let state = WatchStateModel()
        state.bolusRecommended = 10.3
        state.bolusIncrement = 0.05
        return Group {
            BolusView()
            BolusView().previewDevice("Apple Watch Series 5 - 40mm")
            BolusView().previewDevice("Apple Watch Series 3 - 38mm")
        }.environmentObject(state)
    }
}
