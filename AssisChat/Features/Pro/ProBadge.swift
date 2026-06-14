//
//  ProBadge.swift
//  AssisChat
//
//

import SwiftUI

struct ProBadge: View {
    @EnvironmentObject private var proFeature: ProFeature

    var body: some View {
        if proFeature.showBadge {
            Text(String("PRO"))
                .bold()
                .font(.system(.footnote, design: .rounded))
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.accentColor)
                .cornerRadius(20)
                .colorScheme(.dark)
        } else {
            EmptyView()
        }
    }
}

struct ProBadge_Previews: PreviewProvider {
    static var previews: some View {
        ProBadge()
    }
}
