import SwiftUI

struct PrivacyPolicyView: View {
    var useNavigationView = true
    var onBack: (() -> Void)? = nil

    @EnvironmentObject private var localeManager: LocaleManager
    @State private var policyText = ""
    @State private var isLoading = true

    var body: some View {
        if useNavigationView {
            NavigationView { policyBody }
        } else {
            policyBody
        }
    }

    private var policyBody: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(policyText)
                        .font(.subheadline)
                        .foregroundColor(AppColors.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .appTextSelectionEnabled()
                }
                .appScrollBottomPadding()
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle(L10n.tr("settings.privacy_policy"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let onBack {
                    Button(L10n.tr("common.done"), action: onBack)
                }
            }
        }
        .onAppear {
            Task { await loadPolicy() }
        }
        .onChange(of: localeManager.language) { _ in
            Task { await loadPolicy() }
        }
    }

    private func loadPolicy() async {
        isLoading = true
        let language = localeManager.language
        policyText = PrivacyPolicyLoader.text(for: language)
        isLoading = false
    }
}
