//
//  ProIntroductionView.swift
//  AssisChat
//
//

import SwiftUI

struct ProIntroductionView: View {
    @Environment(\.dismiss) private var dismiss

    @EnvironmentObject private var proFeature: ProFeature

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack {
                    Image("Icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .cornerRadius(20)
                    HStack {
                        Image(systemName: "laurel.leading")
                        Text("Hermes Local Fork")
                        Image(systemName: "laurel.trailing")
                    }
                    .font(proFeature.pro ? .title2 : .headline)
                    .foregroundColor(proFeature.pro ? .accentColor : .primary)
                    .padding(.top)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)

                Text("Local features are unlocked. StoreKit purchase code has been removed from this fork.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.horizontal)
                    .foregroundColor(.secondary)
                    .font(.subheadline)

                ProFeatureList()

                CopyrightView()
                    .padding(.vertical)
            }

            #if os(macOS)
            Button {
                dismiss()
            } label: {
                Image(systemName: "multiply")
            }
            .buttonBorderShape(.roundedRectangle)
            .padding()
            #endif
        }
        .background(Color.groupedBackground)
    }
}

struct ProFeatureList: View {
    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: "heart")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .font(.largeTitle)
                .foregroundColor(.appRed)

            VStack(alignment: .leading, spacing: 5) {
                Text("Privacy Hardened")
                Text("Provider secrets are stored in Keychain and sensitive logs are removed.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondaryGroupedBackground)
        .cornerRadius(12)
        .padding(.horizontal)

        HStack(alignment: .top) {
            Image(systemName: "icloud")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .font(.largeTitle)
                .foregroundColor(.appBlue)

            VStack(alignment: .leading, spacing: 5) {
                Text("Local Storage")
                Text("CloudKit sync is disabled for this fork by default.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondaryGroupedBackground)
        .cornerRadius(12)
        .padding(.horizontal)

        HStack(alignment: .top) {
            Image(systemName: "lock.open")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .font(.largeTitle)
                .foregroundColor(.appGreen)

            VStack(alignment: .leading, spacing: 5) {
                Text("Unlock All Features")
                Text("Unlock all the local features of the app.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondaryGroupedBackground)
        .cornerRadius(12)
        .padding(.horizontal)

        HStack(alignment: .top) {
            Image(systemName: "lock.slash")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .font(.largeTitle)
                .foregroundColor(.appRed)

            VStack(alignment: .leading, spacing: 5) {
                Text("NOT Include Services")
                Text("The Coffee Plan does NOT include OpenAI API services and any online services that AssisChat may offer in the future.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.secondaryGroupedBackground)
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ProIntroductionView_Previews: PreviewProvider {
    static var previews: some View {
        ProIntroductionView()
    }
}
