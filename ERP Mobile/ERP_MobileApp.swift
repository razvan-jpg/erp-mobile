//
//  ERP_MobileApp.swift
//  ERP Mobile
//
//  Created by Razvan on 6/5/26.
//

import SwiftUI

@main
struct ERP_MobileApp: App {
    @StateObject private var session = SessionManager()
    @StateObject private var companyManager = CompanyManager()
    @StateObject private var localeManager = LocaleManager()
    @State private var showLaunchSplash = true
    @State private var showDevelopmentInfo = false

    init() {
        L10n.preload()
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                AuthGateView(showLaunchSplash: showLaunchSplash)
                    .environmentObject(session)
                    .environmentObject(companyManager)
                    .environmentObject(localeManager)
                    .environment(\.locale, localeManager.locale)

                if showLaunchSplash {
                    AppLaunchSplashView {
                        withAnimation(.easeOut(duration: 0.35)) {
                            showLaunchSplash = false
                            showDevelopmentInfo = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                if showDevelopmentInfo {
                    AppDevelopmentInfoOverlay {
                        withAnimation(.easeOut(duration: 0.25)) {
                            showDevelopmentInfo = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .onAppear {
#if targetEnvironment(macCatalyst)
                MacInstallSupport.configureOnLaunch()
#endif
            }
        }
    }
}
