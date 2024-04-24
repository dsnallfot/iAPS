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
    @State var isBolusActive = false
    @State private var pulse = 0
    @State private var steps = 0

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack {
                header
                Spacer()
                buttons
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
        HStack {
            Text(state.glucose)
                .font(.system(size: 45, weight: .semibold))
                .scaledToFill()
                .minimumScaleFactor(0.3)
            Text(" ")
            Text(state.trend)
                .font(.system(size: 35, weight: .semibold))
                .scaledToFill()
                .minimumScaleFactor(0.3)
                .offset(x: -8, y: 0)
            Spacer()
            if state.timerDate.timeIntervalSince(state.lastUpdate) > 10 {
                withAnimation {
                    BlinkingView(count: 7, size: 4)
                        .frame(width: 18, height: 18)
                }
            }
            Spacer()
        }
    }

    var buttons: some View {
        HStack(alignment: .center) {
            Spacer()
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

            /* NavigationLink(isActive: $state.isBolusViewActive) {
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
             Spacer() */

            NavigationLink(isActive: $state.isTempTargetViewActive) {
                TempTargetsView()
                    .environmentObject(state)
            } label: {
                ZStack {
                    if let until = state.tempTargets.compactMap(\.until).first, until > Date() {
                        Image(systemName: "target")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 35, height: 35)
                            .foregroundColor(.cyan.opacity(0.4))
                        Text(until, style: .timer)
                            .scaledToFill()
                            .font(.system(size: 11).weight(.bold))
                            .foregroundColor(.white.opacity(1))
                    } else {
                        Image(systemName: "target")
                            .renderingMode(.template)
                            .resizable()
                            .frame(width: 35, height: 35)
                            .foregroundColor(.cyan)
                    }
                }
            }
            Spacer()
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
