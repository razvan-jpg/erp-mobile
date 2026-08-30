import SwiftUI

private enum HelpManualAnchor {
    static let toc = "help-manual-toc"
}

struct HelpManualView<ExtraContent: View, HeaderTrailing: View>: View {
    let document: HelpManualDocument
    var onBack: (() -> Void)? = nil
    var useGradientBackground = true
    @ViewBuilder private var extraContent: () -> ExtraContent
    @ViewBuilder private var headerTrailingContent: () -> HeaderTrailing

    init(
        document: HelpManualDocument,
        onBack: (() -> Void)? = nil,
        useGradientBackground: Bool = true,
        @ViewBuilder headerTrailingContent: @escaping () -> HeaderTrailing = { EmptyView() },
        @ViewBuilder extraContent: @escaping () -> ExtraContent
    ) {
        self.document = document
        self.onBack = onBack
        self.useGradientBackground = useGradientBackground
        self.headerTrailingContent = headerTrailingContent
        self.extraContent = extraContent
    }

    var body: some View {
        ZStack {
            if useGradientBackground {
                LinearGradient(
                    colors: [.canvasTop, .canvasBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            } else {
                Color(.systemGroupedBackground).ignoresSafeArea()
            }

            VStack(spacing: 0) {
                if let onBack {
                    HStack {
                        Button(action: onBack) {
                            Label(L10n.tr("common.back"), systemImage: "chevron.left")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }

                ScrollViewReader { scrollProxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(document.pageTitle)
                                        .font(.custom("Avenir Next", size: 28).weight(.bold))
                                        .foregroundStyle(Color.accentInk)

                                    Text(document.subtitle)
                                        .font(.custom("Avenir Next", size: 14).weight(.medium))
                                        .foregroundStyle(Color.accentInk.opacity(0.75))

                                    Text(document.versionLine)
                                        .font(.custom("Avenir Next", size: 12).weight(.semibold))
                                        .foregroundStyle(Color.red)

                                    Text(document.lastUpdated)
                                        .font(.custom("Avenir Next", size: 12))
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                headerTrailingContent()
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            helpTOC(scrollProxy: scrollProxy)
                                .id(HelpManualAnchor.toc)

                            ForEach(document.sections) { section in
                                helpSection(section, scrollProxy: scrollProxy)
                                    .id(section.id)
                            }

                            extraContent()

                            Text(document.footer)
                                .font(.custom("Avenir Next", size: 12).weight(.medium))
                                .foregroundStyle(Color.accentInk.opacity(0.65))
                                .padding(.top, 8)
                                .padding(.bottom, 28)
                        }
                        .padding(.horizontal, 20)
                        .frame(maxWidth: 760)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func helpTOC(scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("help.toc"))
                .font(.custom("Avenir Next", size: 16).weight(.semibold))
                .foregroundStyle(Color.accentInk)
            ForEach(document.sections) { section in
                Button {
                    scrollToSection(section.id, using: scrollProxy)
                } label: {
                    HStack(spacing: 8) {
                        Text(section.title)
                            .font(.custom("Avenir Next", size: 13))
                            .foregroundStyle(Color.accentInk.opacity(0.9))
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentWarm)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground)
    }

    private func helpSection(_ section: HelpManualSection, scrollProxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section.title)
                .font(.custom("Avenir Next", size: 18).weight(.bold))
                .foregroundStyle(Color.accentInk)

            ForEach(section.paragraphs, id: \.self) { paragraph in
                Text(paragraph)
                    .font(.custom("Avenir Next", size: 14))
                    .foregroundStyle(Color.accentInk.opacity(0.9))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.screenshotAssetNames, id: \.self) { assetName in
                helpScreenshot(assetName)
            }

            if !section.bullets.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(section.bullets, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•")
                                .font(.custom("Avenir Next", size: 14).weight(.bold))
                                .foregroundStyle(Color.accentWarm)
                            Text(item)
                                .font(.custom("Avenir Next", size: 14))
                                .foregroundStyle(Color.accentInk.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if let tip = section.tip {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentWarm)
                    Text(tip)
                        .font(.custom("Avenir Next", size: 13).weight(.medium))
                        .foregroundStyle(Color.accentInk.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.accentWarm.opacity(0.1))
                )
            }

            Button {
                scrollToSection(HelpManualAnchor.toc, using: scrollProxy)
            } label: {
                Label(L10n.tr("help.back_to_toc"), systemImage: "list.bullet.rectangle")
            }
            .buttonStyle(SecondaryButtonStyle())
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(sectionBackground)
    }

    private func scrollToSection(_ anchor: String, using scrollProxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.35)) {
            scrollProxy.scrollTo(anchor, anchor: .top)
        }
    }

    @ViewBuilder
    private func helpScreenshot(_ assetName: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.accentInk.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 10, y: 4)

            Text(L10n.tr("help.screenshot_caption"))
                .font(.custom("Avenir Next", size: 11))
                .foregroundStyle(Color.labelMuted)
        }
        .padding(.vertical, 4)
    }

    private var sectionBackground: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.panelFill.opacity(0.92))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
    }
}

extension HelpManualView where ExtraContent == EmptyView, HeaderTrailing == EmptyView {
    init(
        document: HelpManualDocument,
        onBack: (() -> Void)? = nil,
        useGradientBackground: Bool = true
    ) {
        self.init(
            document: document,
            onBack: onBack,
            useGradientBackground: useGradientBackground,
            headerTrailingContent: { EmptyView() },
            extraContent: { EmptyView() }
        )
    }
}

#if !canImport(SwiftUI)
#endif
