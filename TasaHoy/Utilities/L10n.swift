import Foundation

/// Centralized multi-language localization helper backed by `Localizable.xcstrings`,
/// automatically adapting to the iPhone's system language with clean fallbacks.
enum L10n {
    static func tr(_ key: String, _ fallback: String) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback, comment: "")
    }

    static func fmt(_ key: String, _ fallback: String, _ args: CVarArg...) -> String {
        let format = tr(key, fallback)
        return String(format: format, locale: Locale.current, arguments: args)
    }

    // MARK: - Tabs
    static var tabConverter: String { tr("tab.converter", "Conversor") }
    static var tabRates: String { tr("tab.rates", "Tasas") }
    static var tabPayments: String { tr("tab.payments", "Pagos") }

    // MARK: - Common Actions
    static var cancel: String { tr("action.cancel", "Cancelar") }
    static var save: String { tr("action.save", "Guardar") }
    static var done: String { tr("action.done", "Listo") }
    static var close: String { tr("action.close", "Cerrar") }
    static var delete: String { tr("action.delete", "Eliminar") }
    static var copy: String { tr("action.copy", "Copiar") }
    static var copied: String { tr("action.copied", "Copiado") }
    static var share: String { tr("action.share", "Compartir") }
    static var refresh: String { tr("action.refresh", "Actualizar") }
    static var add: String { tr("action.add", "Agregar") }
    static var edit: String { tr("action.edit", "Editar") }
    static var settingsTitle: String { tr("settings.title", "Configuración") }

    // MARK: - Rates & Currencies
    static var rateBCVUSD: String { tr("rate.bcv_usd", "Dólar BCV") }
    static var rateBCVEUR: String { tr("rate.bcv_eur", "Euro BCV") }
    static var rateUSDT: String { tr("rate.usdt", "USDT") }
    static var rateUSDTFull: String { tr("rate.usdt_full", "USDT (Binance P2P)") }
    static var rateAverage: String { tr("rate.average", "Promedio BCV / USDT") }
    static var rateAverageShort: String { tr("rate.average_short", "Promedio") }
    static var rateCOP: String { tr("rate.cop", "Peso Colombiano") }
    static var rateCustom: String { tr("rate.custom", "Personalizada") }
    static var bolivaresName: String { tr("currency.ves", "Bolívares") }

    static var subtitleBCVOfficial: String { tr("subtitle.bcv_official", "Oficial · bcv.org.ve") }
    static var subtitleBinanceP2P: String { tr("subtitle.binance_p2p", "Mercado P2P en vivo") }
    static var subtitleAverage: String { tr("subtitle.average", "Media entre BCV y USDT") }
    static var subtitleCOP: String { tr("subtitle.cop", "Referencia diaria") }
    static var subtitleCustom: String { tr("subtitle.custom", "Tasa definida por ti") }

    // MARK: - Converter Home
    static var converterTodayBadge: String { tr("converter.today_badge", "Vigente") }
    static var converterNextRateBadge: String { tr("converter.next_rate_badge", "Próxima BCV") }
    static var converterSwitchToToday: String { tr("converter.switch_today", "Hoy") }
    static var converterSwitchToNext: String { tr("converter.switch_next", "Próxima") }
    static var converterScanner: String { tr("converter.scanner", "Escáner") }
    static var converterCalculator: String { tr("converter.calculator", "Calculadora") }
    static var converterShareRate: String { tr("converter.share_rate", "Compartir") }
    static var converterSelectCurrency: String { tr("converter.select_currency", "Elegir moneda") }
    static var converterQuickComparison: String { tr("converter.quick_comparison", "Equivalente en otras tasas") }
    static var converterTapToSwitch: String { tr("converter.tap_to_switch", "Toca para cambiar tasa") }
    static var converterUpdatedAt: String { tr("converter.updated_at", "Actualizado") }
    static var converterUpdating: String { tr("converter.updating", "Actualizando tasas...") }
    static var converterOfflineCache: String { tr("converter.offline_cache", "Mostrando última tasa guardada") }
    static var converterSwapAccessibility: String { tr("converter.swap_a11y", "Invertir moneda activa") }

    // MARK: - Currency Picker & Add Currency
    static var pickerTitle: String { tr("picker.title", "Seleccionar tasa") }
    static var pickerPrimarySection: String { tr("picker.primary_section", "Principales") }
    static var pickerWorldSection: String { tr("picker.world_section", "Otras divisas") }
    static var pickerCustomSection: String { tr("picker.custom_section", "Tasas personalizadas") }
    static var pickerAddCurrency: String { tr("picker.add_currency", "Agregar otra moneda o tasa") }

    static var addCurrencyTitle: String { tr("add_currency.title", "Agregar moneda") }
    static var addCurrencyModeWorld: String { tr("add_currency.mode_world", "Divisa mundial") }
    static var addCurrencyModeCustom: String { tr("add_currency.mode_custom", "Tasa personalizada") }
    static var addCurrencySearchPlaceholder: String { tr("add_currency.search", "Buscar divisa (ej. Real, Libra, Peso)...") }
    static var addCurrencyNameLabel: String { tr("add_currency.name_label", "Nombre") }
    static var addCurrencyNamePlaceholder: String { tr("add_currency.name_placeholder", "Ej: Remesa, Tienda, Zelle") }
    static var addCurrencySymbolLabel: String { tr("add_currency.symbol_label", "Símbolo") }
    static var addCurrencyRateLabel: String { tr("add_currency.rate_label", "Valor en Bolívares (Bs)") }
    static var addCurrencyColorLabel: String { tr("add_currency.color_label", "Color") }
    static var addCurrencyAdded: String { tr("add_currency.added", "Agregada") }

    // MARK: - Rates Board & Charts
    static var ratesTitle: String { tr("rates.title", "Tasas") }
    static var ratesBCVSection: String { tr("rates.bcv_section", "Banco Central de Venezuela (BCV)") }
    static var ratesUSDTSection: String { tr("rates.usdt_section", "USDT · Mercado P2P") }
    static var ratesGapSection: String { tr("rates.gap_section", "Brecha y Promedio") }
    static var ratesWorldSection: String { tr("rates.world_section", "Peso Colombiano y Divisas") }
    static var ratesChartSection: String { tr("rates.chart_section", "Evolución histórica") }
    static var ratesValueDate: String { tr("rates.value_date", "Fecha de valor") }
    static var ratesUpcomingPublished: String { tr("rates.upcoming_published", "Nueva tasa BCV publicada") }
    static var ratesMoreBCV: String { tr("rates.more_bcv", "Más divisas BCV (CNY, TRY, RUB)") }
    static var ratesLessBCV: String { tr("rates.less_bcv", "Ocultar divisas adicionales") }
    static var ratesBuy: String { tr("rates.buy", "Compra") }
    static var ratesSell: String { tr("rates.sell", "Venta") }
    static var ratesAverageLabel: String { tr("rates.average_label", "Promedio") }
    static var ratesLiveInstant: String { tr("rates.live_instant", "En vivo · sin esperas") }
    static var ratesGapTitle: String { tr("rates.gap_title", "Brecha USDT vs BCV") }
    static var ratesAverageTitle: String { tr("rates.average_title", "Promedio (BCV + USDT)") }
    static var ratesPer1000COP: String { tr("rates.per_1000_cop", "1.000 COP en Bs") }
    static var ratesCOPPerBs: String { tr("rates.cop_per_bs", "COP por 1 Bs") }
    static var ratesCOPPerUSD: String { tr("rates.cop_per_usd", "COP por 1 USD") }
    static var chartYearShort: String { tr("chart.year_short", "1A") }
    static var chartNoData: String { tr("chart.no_data", "Sin datos históricos disponibles") }
    static var chartMin: String { tr("chart.min", "Mín") }
    static var chartMax: String { tr("chart.max", "Máx") }
    static var chartPeriodChange: String { tr("chart.period_change", "Variación") }
    static var ratesUseInConverter: String { tr("rates.use_in_converter", "Calcular") }

    // MARK: - Price Scanner (Camera OCR)
    static var scannerTitle: String { tr("scanner.title", "Escáner de precios") }
    static var scannerHint: String { tr("scanner.hint", "Apunta la cámara a un precio para convertirlo") }
    static var scannerDetected: String { tr("scanner.detected", "Precio detectado") }
    static var scannerUseAmount: String { tr("scanner.use_amount", "Usar en calculadora") }
    static var scannerDirectionToBs: String { tr("scanner.dir_to_bs", "Divisa → Bs") }
    static var scannerDirectionToFX: String { tr("scanner.dir_to_fx", "Bs → Divisa") }
    static var scannerPermissionTitle: String { tr("scanner.permission_title", "Acceso a la cámara") }
    static var scannerPermissionBody: String { tr("scanner.permission_body", "Activa el permiso de cámara en Ajustes para escanear etiquetas de precios en tiempo real.") }
    static var scannerOpenSettings: String { tr("scanner.open_settings", "Abrir Ajustes") }
    static var scannerTorch: String { tr("scanner.torch", "Linterna") }

    // MARK: - Payment Profiles
    static var paymentsTitle: String { tr("payments.title", "Perfiles de pago") }
    static var paymentFilterAll: String { tr("payment.filter_all", "Todos") }
    static var paymentPagoMovil: String { tr("payment.pago_movil", "Pago Móvil") }
    static var paymentBankAccount: String { tr("payment.bank_account", "Cuenta bancaria") }
    static var paymentZelle: String { tr("payment.zelle", "Zelle") }
    static var paymentBinancePay: String { tr("payment.binance_pay", "Binance Pay") }
    static var paymentAddNew: String { tr("payment.add_new", "Nuevo perfil") }
    static var paymentEditProfile: String { tr("payment.edit_profile", "Editar perfil") }
    static var paymentEmptyTitle: String { tr("payment.empty_title", "Sin perfiles guardados") }
    static var paymentEmptySubtitle: String { tr("payment.empty_subtitle", "Guarda tu Pago Móvil, cuenta bancaria o Zelle para compartir tus datos con un toque.") }
    static var paymentCopyData: String { tr("payment.copy_data", "Copiar datos") }
    static var paymentCopyWithAmount: String { tr("payment.copy_with_amount", "Copiar con monto") }
    static var paymentShowQR: String { tr("payment.show_qr", "Ver QR") }
    static var paymentAliasLabel: String { tr("payment.alias_label", "Etiqueta (ej. Personal, Negocio)") }
    static var paymentHolderLabel: String { tr("payment.holder_label", "Nombre del titular") }
    static var paymentBankLabel: String { tr("payment.bank_label", "Banco") }
    static var paymentPhoneLabel: String { tr("payment.phone_label", "Teléfono") }
    static var paymentDocumentLabel: String { tr("payment.document_label", "Cédula / RIF") }
    static var paymentAccountLabel: String { tr("payment.account_label", "Número de cuenta (20 dígitos)") }
    static var paymentZelleLabel: String { tr("payment.zelle_label", "Correo o teléfono Zelle") }
    static var paymentBinanceLabel: String { tr("payment.binance_label", "Binance Pay ID o correo") }

    // MARK: - Settings & Themes
    static var settingsAppearanceSection: String { tr("settings.appearance_section", "Apariencia") }
    static var settingsAppearanceMode: String { tr("settings.appearance_mode", "Modo") }
    static var appearanceSystem: String { tr("appearance.system", "Sistema") }
    static var appearanceLight: String { tr("appearance.light", "Claro") }
    static var appearanceDark: String { tr("appearance.dark", "Oscuro") }

    static var settingsThemeTitle: String { tr("settings.theme_title", "Tema visual") }
    static var settingsThemeSubtitle: String { tr("settings.theme_subtitle", "Acentos y tarjetas Liquid Glass") }
    static var settingsConverterSection: String { tr("settings.converter_section", "Conversor y formato") }
    static var settingsDefaultCurrency: String { tr("settings.default_currency", "Moneda predeterminada") }
    static var settingsDecimals: String { tr("settings.decimals", "Decimales en tasas") }
    static var precisionTwo: String { tr("precision.two", "2 decimales") }
    static var precisionFour: String { tr("precision.four", "4 decimales") }
    static var settingsNumberFormat: String { tr("settings.number_format", "Formato numérico") }
    static var settingsFXAnchor: String { tr("settings.fx_anchor", "Base para COP y otras divisas") }
    static var settingsFXAnchorFooter: String { tr("settings.fx_anchor_footer", "Define si el Peso Colombiano y las divisas mundiales se calculan usando el Dólar BCV, el Promedio o USDT.") }
    static var settingsInfoSection: String { tr("settings.info_section", "Fuentes e información") }
    static var settingsDisclaimerTitle: String { tr("settings.disclaimer_title", "Aviso informativo") }
    static var settingsDisclaimerBody: String {
        tr(
            "settings.disclaimer_body",
            "TasaHoy es una herramienta informativa independiente, sin anuncios ni afiliación gubernamental o con exchanges. La única tasa oficial en Venezuela es la publicada por el Banco Central de Venezuela (bcv.org.ve). La referencia USDT se calcula en vivo a partir de anuncios públicos de compra y venta en Binance P2P (1 USDT ≠ 1 USD) y varía según la dinámica del mercado."
        )
    }
    static var settingsAboutTitle: String { tr("settings.about_title", "Acerca de TasaHoy") }
    static var settingsAboutSubtitle: String { tr("settings.about_subtitle", "Sin anuncios · Liquid Glass nativo para iOS") }

    // MARK: - Themes
    static var themeOriginalTitle: String { tr("theme.original.title", "Original") }
    static var themeOriginalSubtitle: String { tr("theme.original.subtitle", "Esmeralda, azul, cian y ámbar por divisa") }
    static var themeEmeraldTitle: String { tr("theme.emerald.title", "Esmeralda") }
    static var themeEmeraldSubtitle: String { tr("theme.emerald.subtitle", "Verde financiero limpio y fresco") }
    static var themeBlueTitle: String { tr("theme.blue.title", "Azul Zafiro") }
    static var themeBlueSubtitle: String { tr("theme.blue.subtitle", "Estilo clásico Apple en azul cristalino") }
    static var themeRoseTitle: String { tr("theme.rose.title", "Rosa Cristal") }
    static var themeRoseSubtitle: String { tr("theme.rose.subtitle", "Matices rosados suaves sobre vidrio") }
    static var themePurpleTitle: String { tr("theme.purple.title", "Púrpura") }
    static var themePurpleSubtitle: String { tr("theme.purple.subtitle", "Acentos violeta e índigo modernos") }
    static var themeAmberTitle: String { tr("theme.amber.title", "Ámbar Dorado") }
    static var themeAmberSubtitle: String { tr("theme.amber.subtitle", "Tonos cálidos dorados y miel") }
    static var themeOrangeTitle: String { tr("theme.orange.title", "Naranja Solar") }
    static var themeOrangeSubtitle: String { tr("theme.orange.subtitle", "Energía coral y mandarina sutil") }
    static var themeCherryTitle: String { tr("theme.cherry.title", "Cereza") }
    static var themeCherrySubtitle: String { tr("theme.cherry.subtitle", "Carmesí elegante y contrastado") }

    // MARK: - Share Card
    static var shareCardFooter: String { tr("share.card_footer", "TasaHoy · Tasas en tiempo real") }
    static var shareCardOfficialTag: String { tr("share.official_tag", "Tasa Oficial BCV") }
    static var shareCardUSDTTag: String { tr("share.usdt_tag", "Referencia Binance P2P") }
    static var shareCardPreviewTitle: String { tr("share.preview_title", "Tarjeta para compartir") }
}
