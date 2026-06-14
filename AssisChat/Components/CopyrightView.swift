//
//  CopyrightView.swift
//  AssisChat
//

import SwiftUI

struct CopyrightView: View {
    let detailed: Bool

    init(detailed: Bool = false) {
        self.detailed = detailed
    }

    var body: some View {
        VStack(alignment: .center) {
            if detailed {
                Text("Current Version: \(Bundle.main.releaseVersionNumber ?? "")(\(Bundle.main.buildVersionNumber ?? ""))")
                    .font(.system(.footnote))
                Text("DaisyChat")
                    .font(.system(.footnote))
                    .padding(.bottom)
            }

            Image(systemName: "sparkles")
                .font(.footnote)
        }
        .frame(maxWidth: .infinity)
        .foregroundColor(.secondary)
        .listRowBackground(Color.clear)
        .opacity(0.5)
    }

}

struct CopyrightView_Previews: PreviewProvider {
    static var previews: some View {
        CopyrightView()
    }
}
