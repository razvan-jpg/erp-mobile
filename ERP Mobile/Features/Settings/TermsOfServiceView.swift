import SwiftUI

struct TermsOfServiceView: View {
    var useNavigationView = true
    var onBack: (() -> Void)? = nil

    @EnvironmentObject private var localeManager: LocaleManager
    @State private var termsText = ""
    @State private var isLoading = true

    var body: some View {
        if useNavigationView {
            NavigationView { termsBody }
        } else {
            termsBody
        }
    }

    private var termsBody: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    Text(termsText)
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
        .navigationTitle(L10n.tr("settings.terms_of_service"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if let onBack {
                    Button(L10n.tr("common.done"), action: onBack)
                }
            }
        }
        .onAppear {
            Task { await loadTerms() }
        }
        .onChange(of: localeManager.language) { _ in
            Task { await loadTerms() }
        }
    }

    private func loadTerms() async {
        isLoading = true
        let language = localeManager.language
        termsText = TermsOfServiceLoader.text(for: language)
        isLoading = false
    }
}
