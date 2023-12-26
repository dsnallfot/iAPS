import SwiftUI

struct PumpView: View {
    @Binding var reservoir: Decimal?
    @Binding var battery: Battery?
    @Binding var name: String
    @Binding var expiresAtDate: Date?
    @Binding var timerDate: Date
    @Binding var timeZone: TimeZone?

    private var reservoirFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }

    private var batteryFormatter: NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter
    }

    var body: some View {
        if let reservoir = reservoir {
            HStack {
                HStack {
                    Image(systemName: "drop.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 14)
                        .foregroundColor(reservoirColor)
                        .offset(x: 2, y: 0)
                    if reservoir == 0xDEAD_BEEF {
                        Text("50+" + NSLocalizedString(" E", comment: "Insulin unit"))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    } else {
                        Text(
                            reservoirFormatter
                                .string(from: reservoir as NSNumber)! + NSLocalizedString(" E", comment: "Insulin unit")
                        )
                        .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary) }

                    if let timeZone = timeZone, timeZone.secondsFromGMT() != TimeZone.current.secondsFromGMT() {
                        Image(systemName: "clock.badge.exclamationmark.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 14)
                            .symbolRenderingMode(.multicolor)
                            .foregroundStyle(Color.warning, Color.red)
                    }
                }
                .frame(width: 78) // , alignment: .trailing)
                // .frame(width: 60, alignment: .trailing)
                Spacer()
                HStack {
                    if let battery = battery, battery.display ?? false, expiresAtDate == nil {
                        Image(systemName: "battery.100")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 10)
                            .foregroundColor(batteryColor)
                            .offset(x: 3, y: 0)
                        Text("\(Int(battery.percent ?? 100)) %")
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    }
                    if let date = expiresAtDate {
                        Image(systemName: "stopwatch.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 14)
                            .foregroundColor(timerColor)
                            .offset(x: 2, y: 0)
                        Text(remainingTimeString(time: date.timeIntervalSince(timerDate)))
                            .font(.system(size: 14, weight: .semibold)).foregroundColor(.primary)
                    }
                }
                .frame(width: 78) // , alignment: .trailing)
                // .frame(width: 60, alignment: .trailing)
            }
        }
    }

    private func remainingTimeString(time: TimeInterval) -> String {
        guard time > 0 else {
            return NSLocalizedString("Replace pod", comment: "View/Header when pod expired")
        }

        var time = time
        let days = Int(time / 1.days.timeInterval)
        time -= days.days.timeInterval
        let hours = Int(time / 1.hours.timeInterval)
        time -= hours.hours.timeInterval
        let minutes = Int(time / 1.minutes.timeInterval)

        if days >= 1 {
            return "\(days)" + NSLocalizedString("d", comment: "abbreviation for days") + " \(hours)" +
                NSLocalizedString("h", comment: "abbreviation for hours")
        }

        if hours >= 1 {
            return "\(hours)" + NSLocalizedString("h", comment: "abbreviation for hours")
        }

        return "\(minutes)" + NSLocalizedString("m", comment: "abbreviation for minutes")
    }

    private var batteryColor: Color {
        guard let battery = battery, let percent = battery.percent else {
            return .gray
        }

        switch percent {
        case ...10:
            return .loopRed
        case ...20:
            return .loopYellow
        default:
            return .loopGreen
        }
    }

    private var reservoirColor: Color {
        guard let reservoir = reservoir else {
            return .gray
        }

        switch reservoir {
        case ...10:
            return .loopRed
        case ...30:
            return .loopYellow
        default:
            return .insulin
        }
    }

    private var timerColor: Color {
        guard let expisesAt = expiresAtDate else {
            return .gray
        }

        let time = expisesAt.timeIntervalSince(timerDate)

        switch time {
        case ...8.hours.timeInterval:
            return .loopRed
        case ...1.days.timeInterval:
            return .loopYellow
        default:
            return .loopGreen
        }
    }
}
