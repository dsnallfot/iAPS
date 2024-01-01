import SwiftUI

public struct BolusProgressViewStyle: ProgressViewStyle {
    @Environment(\.colorScheme) var colorScheme

    public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
        let progress = configuration.fractionCompleted ?? 0

        return ZStack {
            VStack {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle())
                    .accentColor(Color.white)
            }
        }.frame(width: 180, height: 5)
    }
}

/* import SwiftUI

 public struct BolusProgressViewStyle: ProgressViewStyle {
     @Environment(\.colorScheme) var colorScheme

     public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
         @State var progress = CGFloat(configuration.fractionCompleted ?? 0)
         ZStack {
             VStack {
                 ProgressView(value: progress)
             }
         }.frame(width: 100, height: 5)
     }
 } */

/* import SwiftUI

 public struct BolusProgressViewStyle: ProgressViewStyle {
     public func makeBody(configuration: LinearProgressViewStyle.Configuration) -> some View {
         ZStack {
             Circle()
                 .stroke(lineWidth: 4.0)
                 .opacity(0.3)
                 .foregroundColor(.secondary)
                 .frame(width: 22, height: 22)

             Rectangle().fill(Color.red)
                 .frame(width: 8, height: 8)

             Circle()
                 .trim(from: 0.0, to: CGFloat(configuration.fractionCompleted ?? 0))
                 .stroke(style: StrokeStyle(lineWidth: 5.0, lineCap: .butt, lineJoin: .round))
                 .foregroundColor(.insulin)
                 .rotationEffect(Angle(degrees: -90))
                 .frame(width: 22, height: 22)
         }.frame(width: 36, height: 36)
     }
 } */
