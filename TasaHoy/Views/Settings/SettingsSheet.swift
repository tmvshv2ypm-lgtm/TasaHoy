import SwiftUI

/// Clean Apple Liquid Glass Settings sheet matching Voice Notes & PosterCut:
/// Appearance (System / Light / Dark), Subtle Liquid Glass Theme Picker,
/// Default Currency on launch, Precision & Number Format, COP/FX Anchor, and Transparent Sources Info.
struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TasaHoyViewModel
    @ObservedObject private var themeManager = TasaThemeManager.shared

    private var appVersionString: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        return "v\(ver)"
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Appearance & Liquid Glass Themes
                Section {
                    Picker(selection: $themeManager.appearance) {
                        ForEach(AppAppearanceMode.allCases) { mode in
                            Text(mode.localizedTitle).tag(mode)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsAppearanceMode)
                        } icon: {
                            Image(systemName: "circle.lefthalf.filled")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }
                    .pickerStyle(.segmented)

                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        HStack(spacing: 12) {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.settingsThemeTitle)
                                        .foregroundStyle(.primary)
                                    Text(L10n.settingsThemeSubtitle)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "paintpalette.fill")
                                    .foregroundStyle(themeManager.primaryAccent)
                            }

                            Spacer(minLength: 6)

                            HStack(spacing: 6) {
                                Text(themeManager.currentTheme.localizedTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(themeManager.primaryAccent)

                                HStack(spacing: 3) {
                                    ForEach(Array(themeManager.currentTheme.swatchColors.prefix(4).enumerated()), id: \.offset) { _, swatch in
                                        Circle()
                                            .fill(swatch)
                                            .frame(width: 8, height: 8)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text(L10n.settingsAppearanceSection)
                }

                // MARK: - Converter & Formatting Preferences
                Section {
                    Picker(selection: $viewModel.defaultSource) {
                        ForEach(viewModel.allSelectableSources) { source in
                            Text(viewModel.title(for: source)).tag(source)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsDefaultCurrency)
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color(hex: "#F59E0B"))
                        }
                    }

                    Picker(selection: $viewModel.precision) {
                        ForEach(DecimalPrecisionMode.allCases) { p in
                            Text(p.localizedTitle).tag(p)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsDecimals)
                        } icon: {
                            Image(systemName: "number")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }

                    Picker(selection: $viewModel.numberStyle) {
                        ForEach(NumberStylePreference.allCases) { style in
                            Text(style.exampleString).tag(style)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsNumberFormat)
                        } icon: {
                            Image(systemName: "textformat.123")
                                .foregroundStyle(themeManager.primaryAccent)
                        }
                    }

                    Picker(selection: $viewModel.fxAnchor) {
                        ForEach(FXAnchorMode.allCases) { anchor in
                            Text(anchor.localizedTitle).tag(anchor)
                        }
                    } label: {
                        Label {
                            Text(L10n.settingsFXAnchor)
                        } icon: {
                            Image(systemName: "globe")
                                .foregroundStyle(Color(hex: "#8B5CF6"))
                        }
                    }
                } header: {
                    Text(L10n.settingsConverterSection)
                } footer: {
                    Text(L10n.settingsFXAnchorFooter)
                }

                // MARK: - Official Sources & Transparent Disclaimer
                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(themeManager.primaryAccent)
                            Text(L10n.settingsDisclaimerTitle)
                                .font(.subheadline.weight(.semibold))
                        }

                        Text(L10n.settingsDisclaimerBody)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Link(destination: URL(string: "https://www.bcv.org.ve/")!) {
                                Label("bcv.org.ve", systemImage: "arrow.up.right.square")
                                    .font(.caption.weight(.semibold))
                            }
                            .tint(themeManager.primaryAccent)
                        }
                        .padding(.top, 2)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.settingsInfoSection)
                }

                // MARK: - About TasaHoy Card
                Section {
                    HStack(spacing: 14) {
                        TasaMarkView(
                            size: 50,
                            accent: themeManager.primaryAccent,
                            secondary: themeManager.secondaryGlow
                        )
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(verbatim: "TasaHoy")
                                    .font(.headline.weight(.bold))
                                Text(appVersionString)
                                    .font(.caption.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.primary.opacity(0.07), in: Capsule())
                            }
                            Text(L10n.settingsAboutSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text(L10n.settingsAboutTitle)
                }
            }
            .navigationTitle(L10n.settingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L10n.done) {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}
