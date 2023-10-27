import SwiftUI

public struct BolusProgressViewStyle: ProgressViewStyle {
    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 5.0)
                .opacity(0.3)
                .foregroundColor(.secondary)
                .frame(width: 27, height: 27)

            Rectangle().fill(Color.insulin)
                .frame(width: 11, height: 11)

            Circle()
                .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                .stroke(style: StrokeStyle(lineWidth: 5.0, lineCap: .butt, lineJoin: .round))
                .foregroundColor(.insulin)
                .rotationEffect(Angle(degrees: -90))
                .frame(width: 27, height: 27)
        }.frame(width: 36, height: 36)
    }
}
