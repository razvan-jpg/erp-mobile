import Foundation

enum ERPHelpContent {
    static var document: HelpManualDocument {
        HelpManualDocument(
            pageTitle: L10n.tr("help.page_title"),
            subtitle: L10n.tr("help.subtitle"),
            versionLine: L10n.tr("help.installed_version", AppInfo.marketingVersionWithBuildLabel),
            lastUpdated: L10n.tr("help.last_updated"),
            footer: L10n.tr("help.footer", AppInfo.marketingVersionWithBuildLabel),
            sections: erpSections + utilitiesSections + zettaSections
        )
    }

    private static var erpSections: [HelpManualSection] {
        [
            HelpManualSection(
                id: "intro",
                title: L10n.tr("help.section_intro_title"),
                paragraphs: [
                    L10n.tr("help.section_intro_p1"),
                    L10n.tr("help.section_intro_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_intro_b1"),
                    L10n.tr("help.section_intro_b2"),
                    L10n.tr("help.section_intro_b3"),
                    L10n.tr("help.section_intro_b4"),
                ],
                screenshotAssetNames: ["HelpDashboard"],
                tip: L10n.tr("help.section_intro_tip")
            ),
            HelpManualSection(
                id: "login",
                title: L10n.tr("help.section_login_title"),
                paragraphs: [
                    L10n.tr("help.section_login_p1"),
                    L10n.tr("help.section_login_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_login_b1"),
                    L10n.tr("help.section_login_b2"),
                    L10n.tr("help.section_login_b3"),
                    L10n.tr("help.section_login_b4"),
                ],
                screenshotAssetNames: ["HelpDashboard"],
                tip: L10n.tr("help.section_login_tip")
            ),
            HelpManualSection(
                id: "dashboard",
                title: L10n.tr("help.section_dashboard_title"),
                paragraphs: [
                    L10n.tr("help.section_dashboard_p1"),
                    L10n.tr("help.section_dashboard_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_dashboard_b1"),
                    L10n.tr("help.section_dashboard_b2"),
                    L10n.tr("help.section_dashboard_b3"),
                    L10n.tr("help.section_dashboard_b4"),
                    L10n.tr("help.section_dashboard_b5"),
                    L10n.tr("help.section_dashboard_b6"),
                    L10n.tr("help.section_dashboard_b7"),
                ],
                screenshotAssetNames: ["HelpDashboard", "HelpCompanyMenu"],
                tip: L10n.tr("help.section_dashboard_tip")
            ),
            HelpManualSection(
                id: "company",
                title: L10n.tr("help.section_company_title"),
                paragraphs: [
                    L10n.tr("help.section_company_p1"),
                    L10n.tr("help.section_company_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_company_b1"),
                    L10n.tr("help.section_company_b2"),
                    L10n.tr("help.section_company_b3"),
                    L10n.tr("help.section_company_b4"),
                ],
                screenshotAssetNames: ["HelpCompanyMenu", "HelpStatusBar"],
                tip: L10n.tr("help.section_company_tip")
            ),
            HelpManualSection(
                id: "settings",
                title: L10n.tr("help.section_settings_title"),
                paragraphs: [
                    L10n.tr("help.section_settings_p1"),
                    L10n.tr("help.section_settings_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_settings_b1"),
                    L10n.tr("help.section_settings_b2"),
                    L10n.tr("help.section_settings_b3"),
                    L10n.tr("help.section_settings_b4"),
                    L10n.tr("help.section_settings_b5"),
                    L10n.tr("help.section_settings_b6"),
                    L10n.tr("help.section_settings_b7"),
                ],
                screenshotAssetNames: ["HelpSettings"],
                tip: L10n.tr("help.section_settings_tip")
            ),
            HelpManualSection(
                id: "users",
                title: L10n.tr("help.section_users_title"),
                paragraphs: [
                    L10n.tr("help.section_users_p1"),
                ],
                bullets: [
                    L10n.tr("help.section_users_b1"),
                    L10n.tr("help.section_users_b2"),
                    L10n.tr("help.section_users_b3"),
                    L10n.tr("help.section_users_b4"),
                ],
                screenshotAssetNames: ["HelpUsers"],
                tip: L10n.tr("help.section_users_tip")
            ),
            HelpManualSection(
                id: "bulk-delete",
                title: L10n.tr("help.section_bulk_delete_title"),
                paragraphs: [
                    L10n.tr("help.section_bulk_delete_p1"),
                    L10n.tr("help.section_bulk_delete_p2"),
                    L10n.tr("help.section_bulk_delete_p3"),
                ],
                bullets: [
                    L10n.tr("help.section_bulk_delete_b1"),
                    L10n.tr("help.section_bulk_delete_b2"),
                    L10n.tr("help.section_bulk_delete_b3"),
                    L10n.tr("help.section_bulk_delete_b4"),
                    L10n.tr("help.section_bulk_delete_b5"),
                    L10n.tr("help.section_bulk_delete_b6"),
                    L10n.tr("help.section_bulk_delete_b7"),
                    L10n.tr("help.section_bulk_delete_b8"),
                    L10n.tr("help.section_bulk_delete_b9"),
                    L10n.tr("help.section_bulk_delete_b10"),
                ],
                screenshotAssetNames: ["HelpSuppliersModule", "HelpClientSituation"],
                tip: L10n.tr("help.section_bulk_delete_tip")
            ),
            HelpManualSection(
                id: "nomenclatoare",
                title: L10n.tr("help.section_nomenclatoare_title"),
                paragraphs: [
                    L10n.tr("help.section_nomenclatoare_p1"),
                    L10n.tr("help.section_nomenclatoare_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_nomenclatoare_b1"),
                    L10n.tr("help.section_nomenclatoare_b2"),
                    L10n.tr("help.section_nomenclatoare_b3"),
                    L10n.tr("help.section_nomenclatoare_b4"),
                    L10n.tr("help.section_nomenclatoare_b5"),
                ],
                screenshotAssetNames: ["HelpNomenclatoare"],
                tip: L10n.tr("help.section_nomenclatoare_tip")
            ),
            HelpManualSection(
                id: "suppliers",
                title: L10n.tr("help.section_suppliers_title"),
                paragraphs: [
                    L10n.tr("help.section_suppliers_p1"),
                    L10n.tr("help.section_suppliers_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_suppliers_b1"),
                    L10n.tr("help.section_suppliers_b2"),
                    L10n.tr("help.section_suppliers_b3"),
                    L10n.tr("help.section_suppliers_b4"),
                    L10n.tr("help.section_suppliers_b5"),
                    L10n.tr("help.section_suppliers_b7"),
                ],
                screenshotAssetNames: ["HelpSuppliersModule", "HelpNIR"],
                tip: L10n.tr("help.section_suppliers_tip")
            ),
            HelpManualSection(
                id: "clients",
                title: L10n.tr("help.section_clients_title"),
                paragraphs: [
                    L10n.tr("help.section_clients_p1"),
                    L10n.tr("help.section_clients_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_clients_b1"),
                    L10n.tr("help.section_clients_b2"),
                    L10n.tr("help.section_clients_b3"),
                    L10n.tr("help.section_clients_b4"),
                    L10n.tr("help.section_clients_b6"),
                ],
                screenshotAssetNames: ["HelpClientsModule", "HelpClientSituation"],
                tip: L10n.tr("help.section_clients_tip")
            ),
            HelpManualSection(
                id: "inventory",
                title: L10n.tr("help.section_inventory_title"),
                paragraphs: [
                    L10n.tr("help.section_inventory_p1"),
                    L10n.tr("help.section_inventory_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_inventory_b1"),
                    L10n.tr("help.section_inventory_b2"),
                    L10n.tr("help.section_inventory_b3"),
                    L10n.tr("help.section_inventory_b4"),
                ],
                screenshotAssetNames: ["HelpInventory"],
                tip: L10n.tr("help.section_inventory_tip")
            ),
            HelpManualSection(
                id: "stock-sheet",
                title: L10n.tr("help.section_stock_sheet_title"),
                paragraphs: [
                    L10n.tr("help.section_stock_sheet_p1"),
                    L10n.tr("help.section_stock_sheet_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_stock_sheet_b1"),
                    L10n.tr("help.section_stock_sheet_b2"),
                    L10n.tr("help.section_stock_sheet_b3"),
                    L10n.tr("help.section_stock_sheet_b4"),
                ],
                screenshotAssetNames: ["HelpInventory"],
                tip: L10n.tr("help.section_stock_sheet_tip")
            ),
            HelpManualSection(
                id: "crm",
                title: L10n.tr("help.section_crm_title"),
                paragraphs: [
                    L10n.tr("help.section_crm_p1"),
                    L10n.tr("help.section_crm_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_crm_b1"),
                    L10n.tr("help.section_crm_b2"),
                    L10n.tr("help.section_crm_b3"),
                    L10n.tr("help.section_crm_b4"),
                    L10n.tr("help.section_crm_b5"),
                    L10n.tr("help.section_crm_b6"),
                    L10n.tr("help.section_crm_b7"),
                    L10n.tr("help.section_crm_b8"),
                ],
                screenshotAssetNames: ["HelpClientsModule", "HelpDashboard"],
                tip: L10n.tr("help.section_crm_tip")
            ),
            HelpManualSection(
                id: "cash-register",
                title: L10n.tr("help.section_cash_register_title"),
                paragraphs: [
                    L10n.tr("help.section_cash_register_p1"),
                    L10n.tr("help.section_cash_register_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_cash_register_b1"),
                    L10n.tr("help.section_cash_register_b2"),
                    L10n.tr("help.section_cash_register_b3"),
                    L10n.tr("help.section_cash_register_b4"),
                    L10n.tr("help.section_cash_register_b5"),
                    L10n.tr("help.section_cash_register_b6"),
                    L10n.tr("help.section_cash_register_b7"),
                ],
                screenshotAssetNames: ["HelpUtilitiesCashRegister", "HelpDashboard"],
                tip: L10n.tr("help.section_cash_register_tip")
            ),
            HelpManualSection(
                id: "legal",
                title: L10n.tr("help.section_legal_title"),
                paragraphs: [
                    L10n.tr("help.section_legal_p1"),
                ],
                bullets: [
                    L10n.tr("help.section_legal_b1"),
                    L10n.tr("help.section_legal_b2"),
                    L10n.tr("help.section_legal_b3"),
                    L10n.tr("help.section_legal_b4"),
                    L10n.tr("help.section_legal_b5"),
                ],
                screenshotAssetNames: ["HelpStatusBar"],
                tip: L10n.tr("help.section_legal_tip")
            ),
        ]
    }

    private static var utilitiesSections: [HelpManualSection] {
        [
            HelpManualSection(
                id: "utilities",
                title: L10n.tr("help.section_utilities_title"),
                paragraphs: [
                    L10n.tr("help.section_utilities_p1"),
                    L10n.tr("help.section_utilities_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_utilities_b1"),
                    L10n.tr("help.section_utilities_b2"),
                    L10n.tr("help.section_utilities_b3"),
                    L10n.tr("help.section_utilities_b4"),
                    L10n.tr("help.section_utilities_b5"),
                    L10n.tr("help.section_utilities_b6"),
                ],
                screenshotAssetNames: [
                    "HelpUtilitiesMenu",
                    "HelpUtilitiesZetta",
                    "HelpUtilitiesMT940",
                    "HelpUtilitiesCashRegister",
                ],
                tip: L10n.tr("help.section_utilities_tip")
            ),
        ]
    }

    private static var zettaSections: [HelpManualSection] {
        [
            HelpManualSection(
                id: "zetta-category",
                title: L10n.tr("help.section_zetta_category_title"),
                paragraphs: [
                    L10n.tr("help.section_zetta_category_p1"),
                    L10n.tr("help.section_zetta_category_p2"),
                ],
                bullets: [
                    L10n.tr("help.section_zetta_category_b1"),
                    L10n.tr("help.section_zetta_category_b2"),
                    L10n.tr("help.section_zetta_category_b3"),
                    L10n.tr("help.section_zetta_category_b4"),
                ],
                screenshotAssetNames: ["HelpClientsModule", "HelpMainScreen"],
                tip: L10n.tr("help.section_zetta_category_tip")
            ),
        ] + HelpContent.manualSections.map { section in
            HelpManualSection(
                id: "zetta-\(section.id)",
                title: L10n.tr("help.zetta_section_prefix", section.title),
                paragraphs: section.paragraphs,
                bullets: section.bullets,
                screenshotAssetNames: section.screenshotAssetNames,
                tip: section.tip
            )
        }
    }
}
