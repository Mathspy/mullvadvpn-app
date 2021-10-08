//
//  PreferencesViewController.swift
//  MullvadVPN
//
//  Created by pronebird on 19/05/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit
import Logging

class PreferencesViewController: UITableViewController, PreferencesDataSourceDelegate, TunnelObserver {

    private let logger = Logger(label: "PreferencesViewController")

    private let dataSource = PreferencesDataSource()

    init() {
        super.init(style: .grouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.backgroundColor = .secondaryColor
        tableView.separatorColor = .secondaryColor
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        tableView.sectionHeaderHeight = UIMetrics.sectionSpacing

        dataSource.tableView = tableView

        navigationItem.title = NSLocalizedString("NAVIGATION_TITLE", tableName: "Preferences", comment: "Navigation title")
        navigationItem.largeTitleDisplayMode = .always
        navigationItem.rightBarButtonItem = editButtonItem

        TunnelManager.shared.addObserver(self)

        if let dnsSettings = TunnelManager.shared.tunnelInfo?.tunnelSettings.interface.dnsSettings {
            //viewModel = PreferencesViewModel(from: dnsSettings)
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        dataSource.setEditing(editing)

        super.setEditing(editing, animated: animated)
    }

    // MARK: - PreferencesDataSourceDelegate

    func preferencesDataSource(_ dataSource: PreferencesDataSource, didChangeDataModel dataModel: PreferencesDataModel) {

    }

    // MARK: - TunnelObserver

    func tunnelManager(_ manager: TunnelManager, didUpdateTunnelState tunnelState: TunnelState) {
        // no-op
    }

    func tunnelManager(_ manager: TunnelManager, didFailWithError error: TunnelManager.Error) {
        // no-op
    }

    func tunnelManager(_ manager: TunnelManager, didUpdateTunnelSettings tunnelInfo: TunnelInfo?) {
        guard let dnsSettings = tunnelInfo?.tunnelSettings.interface.dnsSettings else { return }

        // update data source
    }

    // MARK: - Private

    private func saveDNSSettings() {
        let dnsSettings = dataSource.dataModel.asDNSSettings()

        TunnelManager.shared.setDNSSettings(dnsSettings)
            .onFailure { [weak self] error in
                self?.logger.error(chainedError: error, message: "Failed to save DNS settings")
            }
            .observe { _ in }
    }

}
