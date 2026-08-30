//
//  ContentView.swift
//  ERP Mobile
//
//  Created by Razvan on 6/5/26.
//

import SwiftUI

/// Păstrat pentru compatibilitate preview; aplicația folosește AuthGateView.
struct ContentView: View {
    var body: some View {
        AuthGateView()
            .environmentObject(SessionManager())
    }
}

#Preview {
    ContentView()
}
