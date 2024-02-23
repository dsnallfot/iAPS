import HealthKit
import SwiftDate
import SwiftUI

@available(watchOSApplicationExtension 9.0, *) struct MainView: View {
    private enum Config {
        static let lag: TimeInterval = 30
    }

    @EnvironmentObject var state: WatchStateModel

    @State var isCarbsActive = false
    @State var isTargetsActive = false
    @State var isOverrideActive = false
    @State var isBolusActive = false
    @State private var pulse = 0
    @State private var steps = 0

    @GestureState var isDetectingLongPress = false
    @State var completedLongPress = false

    @State var completedLongPressOfBG = false
    @GestureState var isDetectingLongPressOfBG = false

    private var healthStore = HKHealthStore()
    let heartRateQuantity = HKUnit(from: "count/min")

    var body: some View {
        ZStack(alignment: .topLeading) {
            // if !completedLongPressOfBG {
            if state.timerDate.timeIntervalSince(state.lastUpdate) > 10 {
                HStack {
                    Spacer()

                    Text("Updating...").font(.system(size: 9)).foregroundColor(.secondary)
                    withAnimation {
                        BlinkingView(count: 5, size: 3)
                            .frame(width: 10, height: 10)
                    }
                    Spacer()
                }
                .offset(x: 0, y: 9)
            }
            // }
            VStack {
                // if !completedLongPressOfBG {
                header
                Spacer()
                buttons
                /* } else {
                     bigHeader
                 } */
            }

            if state.isConfirmationViewActive {
                ConfirmationView(success: $state.confirmationSuccess)
                    .background(Rectangle().fill(.black))
            }

            if state.isConfirmationBolusViewActive {
                BolusConfirmationView()
                    .environmentObject(state)
                    .background(Rectangle().fill(.black))
            }
        }
        .frame(maxHeight: .infinity)
        .padding()
        .onReceive(state.timer) { date in
            state.timerDate = date
            state.requestState()
        }
        .onAppear {
            state.requestState()
        }
    }

    var header: some View {
        VStack {
            HStack(alignment: .top) {
                HStack {
                    Text(state.glucose)
                        .font(.system(size: 45, weight: .semibold))
                        .scaledToFill()
                        .minimumScaleFactor(0.3)
                    Spacer()
                    Text(state.trend)
                        .font(.system(size: 35, weight: .semibold))
                        .scaledToFill()
                        .minimumScaleFactor(0.3)
                        .offset(x: -8, y: 0)
                    Spacer()
                    Circle().stroke(color, lineWidth: 5).frame(width: 35, height: 35).padding(5)
                }
            }
            VStack {
                HStack {
                    let cleanedDelta = state.delta
                        .replacingOccurrences(of: ",", with: ".")
                        .replacingOccurrences(of: "+", with: "")
                        .replacingOccurrences(of: "−", with: "-")

                    let cleanedGlucose = state.glucose
                        .replacingOccurrences(of: ",", with: ".")

                    if let glucoseValue = Double(cleanedGlucose),
                       let deltaValue = Double(cleanedDelta)
                    {
                        let computedValue = glucoseValue + deltaValue * 2.5
                        let formattedComputedValue = String(format: "%.1f", computedValue)
                        let formattedComputedValueWithComma = formattedComputedValue.replacingOccurrences(of: ".", with: ",")

                        HStack {
                            Text(state.delta)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 45, alignment: .leading)
                        .padding(.leading, 5)
                        Spacer()
                        if state.displaySensorDelayOnWatch {
                            // Conditionally format the Image and Text
                            HStack {
                                if computedValue > 7.8 {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: 12))
                                        .foregroundColor(.loopYellow)
                                    Text(formattedComputedValueWithComma)
                                        .font(.caption)
                                        .foregroundColor(.loopYellow)
                                } else if computedValue < 3.9 {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: 12))
                                        .foregroundColor(.loopRed)
                                    Text(formattedComputedValueWithComma)
                                        .font(.caption)
                                        .foregroundColor(.loopRed)
                                } else {
                                    Image(systemName: "goforward.15")
                                        .font(.system(size: 12))
                                        .foregroundColor(.loopGreen)
                                    Text(formattedComputedValueWithComma)
                                        .font(.caption)
                                        .foregroundColor(.loopGreen)
                                }
                            }
                            .frame(width: 60, alignment: .center)
                        }
                    } else {
                        HStack {
                            Text(state.delta)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 60, alignment: .leading)
                    }

                    Spacer()
                    HStack {
                        if state.lastLoopDate != nil {
                            Text(timeString)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.gray)
                        } else {
                            Text("--")
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(width: 50, alignment: .trailing)
                }

                Spacer()
                HStack(alignment: .firstTextBaseline) {
                    HStack {
                        Text(iobFormatter.string(from: (state.cob ?? 0) as NSNumber)!)
                            .font(.caption2)
                            .scaledToFill()
                            .foregroundColor(Color.white)
                            .minimumScaleFactor(0.5)
                        Text("g").foregroundColor(.loopYellow)
                            .font(.caption2)
                            .scaledToFill()
                            .minimumScaleFactor(0.5)
                    }
                    .frame(width: 45, alignment: .leading)
                    .padding(.leading, 5)

                    Spacer()
                    HStack {
                        Text(iobFormatter.string(from: (state.iob ?? 0) as NSNumber)!)
                            .font(.caption2)
                            .scaledToFill()
                            .foregroundColor(Color.white)
                            .minimumScaleFactor(0.5)

                        Text("U").foregroundColor(.insulin)
                            .font(.caption2)
                            .scaledToFill()
                            .minimumScaleFactor(0.5)
                    }
                    .frame(width: 60, alignment: .center)

                    switch state.displayOnWatch {
                    case .HR:
                        Spacer()
                        HStack {
                            if completedLongPress {
                                HStack {
                                    Text("❤️" + "\(pulse)")
                                        .fontWeight(.regular)
                                        .font(.custom("activated", size: 20))
                                        .scaledToFill()
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.5)
                                }
                                .scaleEffect(isDetectingLongPress ? 3 : 1)
                                .gesture(longPress)

                            } else {
                                HStack {
                                    Text("❤️" + "\(pulse)")
                                        .fontWeight(.regular)
                                        .font(.caption2)
                                        .scaledToFill()
                                        .foregroundColor(.white)
                                        .minimumScaleFactor(0.5)
                                }
                                .scaleEffect(isDetectingLongPress ? 3 : 1)
                                .gesture(longPress)
                            }
                        }
                        .frame(width: 50, alignment: .trailing)
                    case .BGTarget:
                        if let eventualBG = state.eventualBG.nonEmpty {
                            Spacer()
                            HStack {
                                Text(eventualBG)
                                    .font(.caption2)
                                    .scaledToFill()
                                    .foregroundColor(.white)
                                    .minimumScaleFactor(0.5)
                            }
                            .frame(width: 50, alignment: .trailing)
                        }
                    case .steps:
                        Spacer()
                        HStack {
                            Text("🦶" + "\(steps)")
                                .fontWeight(.regular)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(width: 50, alignment: .trailing)
                    case .isf:
                        Spacer()
                        let isf: String = state.isf != nil ? "\(state.isf ?? 0)" : "-"
                        HStack {
                            Image(systemName: "arrow.up.arrow.down")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 12, height: 12)
                                .foregroundColor(.loopGreen)
                            Text("\(isf)")
                                .fontWeight(.regular)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(width: 50, alignment: .trailing)
                    case .override:
                        Spacer()
                        let override: String = state.override != nil ? state.override! : "-"
                        HStack {
                            Image(systemName: "person")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 12, height: 12)
                                .foregroundColor(.white)
                                .offset(x: 3)
                            Text(override)
                                .fontWeight(.regular)
                                .font(.caption2)
                                .scaledToFill()
                                .foregroundColor(.white)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(width: 50, alignment: .trailing)
                    }
                }
                Spacer()
                    .onAppear(perform: start)
            }
        }
        .padding()
        // .scaleEffect(isDetectingLongPressOfBG ? 3 : 1)
        .gesture(longPresBGs)
    }

    /* var bigHeader: some View {
         VStack(alignment: .center) {
             HStack {
                 Text(state.glucose).font(.system(size: 60, weight: .semibold))
                 Text(state.trend != "→" ? state.trend : "").font(.system(size: 60, weight: .semibold))
                     .scaledToFill()
                     .minimumScaleFactor(0.5)
             }.padding(.bottom, 30)

             HStack {
                 Circle().stroke(color, lineWidth: 5).frame(width: 35, height: 35).padding(10)
             }
         }
         .gesture(longPresBGs)
     } */

    var longPress: some Gesture {
        LongPressGesture(minimumDuration: 2) // 1)
            .updating($isDetectingLongPress) { currentState, gestureState,
                _ in
                gestureState = currentState
            }
            .onEnded { _ in
                if completedLongPress {
                    completedLongPress = false
                } else { completedLongPress = true }
            }
    }

    var longPresBGs: some Gesture {
        LongPressGesture(minimumDuration: 1)
            .updating($isDetectingLongPressOfBG) { currentState, gestureState,
                _ in
                gestureState = currentState
            }
            .onEnded { _ in
                if completedLongPressOfBG {
                    completedLongPressOfBG = false
                } else { completedLongPressOfBG = true }
            }
    }

    var buttons: some View {
        HStack(alignment: .center) {
            NavigationLink(isActive: $state.isCarbsViewActive) {
                CarbsView()
                    .environmentObject(state)
            } label: {
                Image(systemName: "fork.knife.circle")
                    .renderingMode(.template)
                    .resizable()
                    .fontWeight(.light)
                    .frame(width: 35, height: 35)
                    .foregroundColor(.loopYellow)
            }

            Spacer()

            NavigationLink(isActive: $state.isBolusViewActive) {
                BolusView()
                    .environmentObject(state)
            } label: {
                Image(systemName: "drop.circle")
                    .renderingMode(.template)
                    .resizable()
                    .fontWeight(.light)
                    .frame(width: 35, height: 35)
                    .foregroundColor(.insulin)
            }
            Spacer()

            /* NavigationLink(isActive: $state.isTempTargetViewActive) {
             TempTargetsView()
             .environmentObject(state)
             } label: {
             VStack {
             Image(systemName: "target")
             .renderingMode(.template)
             .resizable()
             .fontWeight(.light)
             .frame(width: 35, height: 35)
             .foregroundColor(.cyan)
             if let until = state.tempTargets.compactMap(\.until).first, until > Date() {
             Text(until, style: .timer)
             .scaledToFill()
             .font(.system(size: 8))
             }
             }
             } */
            // if state.useTargetButton {
            // use longpress to toggle between temptargets and override buttons instead of default and bigheader views
            if completedLongPressOfBG {
                NavigationLink(isActive: $state.isTempTargetViewActive) {
                    TempTargetsView()
                        .environmentObject(state)
                } label: {
                    VStack {
                        Image(systemName: "target")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 35, height: 35)
                            .foregroundColor(.cyan)
                        if let until = state.tempTargets.compactMap(\.until).first, until > Date() {
                            Text(until, style: .timer)
                                .scaledToFill()
                                .font(.system(size: 8))
                        }
                    }
                }
            } else {
                NavigationLink(isActive: $state.isOverridesViewActive) {
                    OverridesView()
                        .environmentObject(state)
                } label: {
                    VStack {
                        if let until = state.overrides.compactMap(\.until).first, until > Date.now {
                            Image(systemName: "person.circle")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.purple.opacity(0.7))

                            if until > Date.now.addingTimeInterval(48.hours.timeInterval) {
                                Text("∞")
                                    .scaledToFill()
                                    .font(.system(size: 12))
                                    .offset(y: -3)

                            } else {
                                Text(until, style: .timer)
                                    .font(.system(size: 8))
                            }
                        } else {
                            Image(systemName: "person.circle")
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 35, height: 35)
                                .foregroundColor(.purple.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    func start() {
        autorizeHealthKit()
        startHeartRateQuery(quantityTypeIdentifier: .heartRate)
        startStepsQuery(quantityTypeIdentifier: .stepCount)
    }

    func autorizeHealthKit() {
        let healthKitTypes: Set = [
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
            HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        ]
        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { _, _ in }
    }

    private func startStepsQuery(quantityTypeIdentifier _: HKQuantityTypeIdentifier) {
        let type = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        var interval = DateComponents()
        interval.day = 1
        let query = HKStatisticsCollectionQuery(
            quantityType: type,
            quantitySamplePredicate: nil,
            options: [.cumulativeSum],
            anchorDate: startOfDay,
            intervalComponents: interval
        )

        query.initialResultsHandler = { _, result, _ in
            var resultCount = 0.0
            guard let result = result else {
                self.steps = 0
                return
            }
            result.enumerateStatistics(from: startOfDay, to: now) { statistics, _ in

                if let sum = statistics.sumQuantity() {
                    // Get steps (they are of double type)
                    resultCount = sum.doubleValue(for: HKUnit.count())
                } // end if
                // Return
                self.steps = Int(resultCount)
            }
        }

        query.statisticsUpdateHandler = {
            _, statistics, _, _ in

            // If new statistics are available
            if let sum = statistics?.sumQuantity() {
                let resultCount = sum.doubleValue(for: HKUnit.count())
                // Return
                self.steps = Int(resultCount)
            } // end if
        }
        healthStore.execute(query)
    }

    private func startHeartRateQuery(quantityTypeIdentifier: HKQuantityTypeIdentifier) {
        let devicePredicate = HKQuery.predicateForObjects(from: [HKDevice.local()])
        let updateHandler: (HKAnchoredObjectQuery, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?, Error?) -> Void = {
            _, samples, _, _, _ in
            guard let samples = samples as? [HKQuantitySample] else {
                return
            }
            self.process(samples, type: quantityTypeIdentifier)
        }
        let query = HKAnchoredObjectQuery(
            type: HKObjectType.quantityType(forIdentifier: quantityTypeIdentifier)!,
            predicate: devicePredicate,
            anchor: nil,
            limit: HKObjectQueryNoLimit,
            resultsHandler: updateHandler
        )
        query.updateHandler = updateHandler
        healthStore.execute(query)
    }

    private func process(_ samples: [HKQuantitySample], type: HKQuantityTypeIdentifier) {
        var lastHeartRate = 0.0
        for sample in samples {
            if type == .heartRate {
                lastHeartRate = sample.quantity.doubleValue(for: heartRateQuantity)
            }
            pulse = Int(lastHeartRate)
        }
    }

    private var iobFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 2
        formatter.numberStyle = .decimal
        return formatter
    }

    private var timeString: String {
        let minAgo = Int((Date().timeIntervalSince(state.lastLoopDate ?? .distantPast) - Config.lag) / 60) + 1
        if minAgo > 1440 {
            return "--"
        }
        return "\(minAgo) " + NSLocalizedString("min", comment: "Minutes ago since last loop")
    }

    private var color: Color {
        guard let lastLoopDate = state.lastLoopDate else {
            return .loopGray
        }
        let delta = Date().timeIntervalSince(lastLoopDate) - Config.lag

        if delta <= 5.minutes.timeInterval {
            return .loopGreen
        } else if delta <= 10.minutes.timeInterval {
            return .loopYellow
        } else {
            return .loopRed
        }
    }
}

@available(watchOSApplicationExtension 9.0, *) struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        let state = WatchStateModel()

        state.glucose = "15,8"
        state.delta = "+888"
        state.iob = 100.38
        state.cob = 112.123
        state.lastLoopDate = Date().addingTimeInterval(-200)
        state
            .tempTargets =
            [TempTargetWatchPreset(name: "Test", id: "test", description: "", until: Date().addingTimeInterval(3600 * 3))]

        return Group {
            MainView()
            MainView().previewDevice("Apple Watch Series 5 - 40mm")
            MainView().previewDevice("Apple Watch Series 3 - 38mm")
        }.environmentObject(state)
    }
}
