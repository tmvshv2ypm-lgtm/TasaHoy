import SwiftUI

/// Root TabView of TasaHoy:
/// Automatically adopts Apple's native iOS 26 / iOS 27 floating Liquid Glass Tab Bar
/// with the real interactive refractive droplet, zero ads, and instant refresh on launch.
struct MainTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TasaHoyViewModel()
    @ObservedObject private var themeManager = TasaThemeManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            TabView(selection: $viewModel.selectedTab) {
                ConverterView(viewModel: viewModel)
                    .tabItem {
                        Label(L10n.tabConverter, systemImage: "arrow.left.arrow.right.circle.fill")
                    }
                    .tag(AppTab.converter)

                RatesBoardView(viewModel: viewModel)
                    .tabItem {
                        Label(L10n.tabRates, systemImage: "chart.line.uptrend.xyaxis")
                    }
                    .tag(AppTab.rates)

                PaymentProfilesView(viewModel: viewModel)
                    .tabItem {
                        Label(L10n.tabPayments, systemImage: "creditcard.fill")
                    }
                    .tag(AppTab.payments)
            }
            .tint(themeManager.primaryAccent)

            // Floating Liquid Glass copy confirmation toast
            if let toast = viewModel.toastMessage {
                HStack(spacing: 7) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color(hex: "#10B981"))
                    Text(toast)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .liquidGlassCapsule(interactive: false)
                .shadow(color: Color.black.opacity(0.14), radius: 10, y: 4)
                .padding(.top, 10)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(99)
            }
        }
        .preferredColorScheme(themeManager.appearance.preferredColorScheme)
        .task {
            await viewModel.refreshRates(forceHaptic: false)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    await viewModel.refreshIfNeededOnForeground()
                }
            }
        }
        .sheet(isPresented: $viewModel.showCurrencyPicker) {
            CurrencyPickerSheet(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .sheet(isPresented: $viewModel.showAddCurrency) {
            AddCurrencySheet(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .fullScreenCover(isPresented: $viewModel.showScanner) {
            PriceScannerSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showShareCardSheet) {
            ShareRateCardSheet(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsSheet(viewModel: viewModel)
                .preferredColorScheme(themeManager.appearance.preferredColorScheme)
                .tint(themeManager.primaryAccent)
        }
        .sheet(isPresented: $viewModel.showSystemShareSheet) {
            ActivityShareSheet(items: viewModel.shareItems)
                .ignoresSafeArea()
        }
    }
}
