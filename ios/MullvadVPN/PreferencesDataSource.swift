//
//  PreferencesDataSource.swift
//  MullvadVPN
//
//  Created by pronebird on 05/10/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import Foundation
import UIKit
import Network

protocol PreferencesDataSourceDelegate: AnyObject {
    func preferencesDataSource(_ dataSource: PreferencesDataSource, didChangeDataModel dataModel: PreferencesDataModel)
}

struct PreferencesDataModel: Equatable {
    var blockAdvertising: Bool
    var blockTracking: Bool
    var enableCustomDNS: Bool
    var customDNSDomains: [String]

    var dnsDomainInput: String = ""

    init(from dnsSettings: DNSSettings = DNSSettings()) {
        blockAdvertising = dnsSettings.blockAdvertising
        blockTracking = dnsSettings.blockTracking
        enableCustomDNS = dnsSettings.enableCustomDNS
        customDNSDomains = dnsSettings.customDNSDomains.map { ipAddress in
            return "\(ipAddress)"
        }
    }

    func asDNSSettings() -> DNSSettings {
        var dnsSettings = DNSSettings()
        dnsSettings.blockAdvertising = blockAdvertising
        dnsSettings.blockTracking = blockTracking
        dnsSettings.enableCustomDNS = enableCustomDNS
        dnsSettings.customDNSDomains = customDNSDomains.compactMap { ipAddressString in
            return AnyIPAddress(ipAddressString)
        }
        return dnsSettings
    }

    func isValidDNSDomainForVisualPresentation(_ string: String) -> Bool {
        return string.isEmpty || AnyIPAddress(string) != nil
    }

    var canEnableCustomDNS: Bool {
        return !blockAdvertising && !blockTracking
    }

    var effectiveEnableCustomDNS: Bool {
        return !blockAdvertising && !blockTracking && enableCustomDNS
    }
}

class PreferencesDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    enum ReuseIdentifiers: String {
        case editableToggle
        case toggle
        case dnsServer
        case editableDNSServer
        case customDNSFooter
    }

    enum Section {
        case mullvadDNS
        case customDNS
    }

    enum Item: Hashable {
        case blockAdvertising
        case blockTracking
        case useCustomDNS
        case addDNSEntry
        case dnsEntry(_ index: Int)
    }

    var isEditing = false

    var sections: [Section] = [.mullvadDNS, .customDNS]

    var dataModel = PreferencesDataModel()

    weak var delegate: PreferencesDataSourceDelegate?

    weak var tableView: UITableView? {
        didSet {
            tableView?.dataSource = self
            tableView?.delegate = self

            registerCells()
        }
    }

    func registerCells() {
        tableView?.register(SettingsSwitchCell.self, forCellReuseIdentifier: ReuseIdentifiers.editableToggle.rawValue)
        tableView?.register(SettingsDNSTextCell.self, forCellReuseIdentifier: ReuseIdentifiers.editableDNSServer.rawValue)
        tableView?.register(SettingsDNSServerAddressCell.self, forCellReuseIdentifier: ReuseIdentifiers.dnsServer.rawValue)
        tableView?.register(SettingsStaticToggleCell.self, forCellReuseIdentifier: ReuseIdentifiers.toggle.rawValue)
        tableView?.register(EmptyTableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: EmptyTableViewHeaderFooterView.reuseIdentifier)
        tableView?.register(SettingsStaticTextFooterView.self, forHeaderFooterViewReuseIdentifier: ReuseIdentifiers.customDNSFooter.rawValue)

    }

    // MARK: - UITableViewDataSource

    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionObject = sections[section]

        return makeItems(for: sectionObject, dataModel: dataModel).count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionObject = sections[indexPath.section]
        let sectionItems = makeItems(for: sectionObject, dataModel: dataModel)
        let item = sectionItems[indexPath.row]

        return dequeueCellForItem(item, in: tableView, at: indexPath)
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Disable swipe to delete when not editing the table view
        guard isEditing else { return false }

        let item = mapIndexPathToItem(indexPath)

        switch item {
        case .dnsEntry, .addDNSEntry:
            return true
        default:
            return false
        }
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        let item = mapIndexPathToItem(indexPath)

        if case .addDNSEntry = item, editingStyle == .insert {
            commitDNSServer()
        }

        if case .dnsEntry(let serverIndex) = item, editingStyle == .delete {
            deleteDNSServer(at: serverIndex)
        }
    }

    func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        let item = mapIndexPathToItem(indexPath)

        switch item {
        case .dnsEntry:
            return true
        default:
            return false
        }
    }

    func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
        let sourceItem = mapIndexPathToItem(sourceIndexPath)!
        let destinationItem = mapIndexPathToItem(destinationIndexPath)!

        if case .dnsEntry(let sourceIndex) = sourceItem, case .dnsEntry(let destinationIndex) = destinationItem {
            dataModel.customDNSDomains.swapAt(sourceIndex, destinationIndex)
        }
    }

    // MARK: - UITableViewDelegate

    func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return tableView.dequeueReusableHeaderFooterView(withIdentifier: EmptyTableViewHeaderFooterView.reuseIdentifier)
    }

    func tableView(_ tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        let sectionObject = sections[section]

        switch sectionObject {
        case .mullvadDNS:
            return nil

        case .customDNS:
            let reusableView = tableView.dequeueReusableHeaderFooterView(withIdentifier: ReuseIdentifiers.customDNSFooter.rawValue) as! SettingsStaticTextFooterView

            reusableView.titleLabel.text = NSLocalizedString(
                "CUSTOM_DNS_FOOTER_LABEL",
                tableName: "Preferences",
                value: "Disable Block Ads and Block trackers to activate this setting.",
                comment: ""
            )

            return reusableView
        }
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let sectionObject = sections[section]

        switch sectionObject {
        case .mullvadDNS:
            return UITableView.automaticDimension

        case .customDNS:
            if dataModel.canEnableCustomDNS {
                return 0
            } else {
                return UITableView.automaticDimension
            }
        }
    }

    func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        let item = mapIndexPathToItem(indexPath)

        switch item {
        case .dnsEntry:
            return .delete
        case .addDNSEntry:
            return .insert
        default:
            return .none
        }
    }

    func tableView(_ tableView: UITableView, targetIndexPathForMoveFromRowAt sourceIndexPath: IndexPath, toProposedIndexPath proposedDestinationIndexPath: IndexPath) -> IndexPath {
        let sectionObject = mapIndexPathToSection(sourceIndexPath)!

        if case .customDNS = sectionObject {
            let items = makeItems(for: sectionObject, dataModel: dataModel)

            let comparator = { (_ item: Item) -> Bool in
                if case .dnsEntry = item {
                    return true
                }
                return false
            }

            let minAllowedIndex = items.firstIndex(where: comparator)!
            let maxAllowedIndex = items.lastIndex(where: comparator)!

            let minAllowedIndexPath = IndexPath(row: minAllowedIndex, section: sourceIndexPath.section)
            let maxAllowedIndexPath = IndexPath(row: maxAllowedIndex, section: sourceIndexPath.section)

            if proposedDestinationIndexPath.section < sourceIndexPath.section {
                return minAllowedIndexPath
            } else if proposedDestinationIndexPath.section > sourceIndexPath.section {
                return maxAllowedIndexPath
            } else {
                if proposedDestinationIndexPath.row < minAllowedIndex {
                    return minAllowedIndexPath
                } else if proposedDestinationIndexPath.row > maxAllowedIndex {
                    return maxAllowedIndexPath
                } else {
                    return proposedDestinationIndexPath
                }
            }
        } else {
            return sourceIndexPath
        }
    }

    func tableView(_ tableView: UITableView, indentationLevelForRowAt indexPath: IndexPath) -> Int {
        let item = mapIndexPathToItem(indexPath)

        if case .dnsEntry = item, !isEditing {
            return 1
        } else {
            return 0
        }
    }

    // MARK: -

    func makeItems(for section: Section, dataModel: PreferencesDataModel) -> [Item] {
        switch section {
        case .mullvadDNS:
            return [.blockAdvertising, .blockTracking]

        case .customDNS:
            var items: [Item] = [.useCustomDNS]

            items.append(contentsOf: dataModel.customDNSDomains.enumerated().map { i, _ in .dnsEntry(i) })

            if isEditing {
                items.append(.addDNSEntry)
            }

            return items
        }
    }

    func mapIndexPathToSection(_ indexPath: IndexPath) -> Section? {
        guard sections.indices.contains(indexPath.section) else { return nil }

        return sections[indexPath.section]
    }

    func mapIndexPathToItem(_ indexPath: IndexPath) -> Item? {
        guard sections.indices.contains(indexPath.section) else { return nil }

        let sectionObject = sections[indexPath.section]
        let items = makeItems(for: sectionObject, dataModel: dataModel)

        guard items.indices.contains(indexPath.row) else { return nil }

        return items[indexPath.row]
    }

    func mapItemToIndexPath(_ item: Item, in section: Section) -> IndexPath? {
        guard let sectionIndex = sectionIndex(for: section) else { return nil }

        let items = makeItems(for: section, dataModel: dataModel)

        guard let itemIndex = items.firstIndex(of: item) else { return nil }

        return IndexPath(row: itemIndex, section: sectionIndex)
    }

    func mapItemToCell(_ item: Item, in section: Section) -> UITableViewCell? {
        guard let indexPath = mapItemToIndexPath(item, in: section) else { return nil }

        return tableView?.cellForRow(at: indexPath)
    }

    func dequeueCellForItem(_ item: Item, in tableView: UITableView, at indexPath: IndexPath) -> UITableViewCell {
        switch item {
        case .blockAdvertising:
            let titleLabel = NSLocalizedString(
                "BLOCK_ADS_CELL_LABEL",
                tableName: "Preferences",
                value: "Block ads",
                comment: ""
            )

            if isEditing {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.editableToggle.rawValue, for: indexPath) as! SettingsSwitchCell

                cell.titleLabel.text = titleLabel
                cell.setOn(dataModel.blockAdvertising, animated: false)
                cell.action = { [weak self] isOn in
                    self?.setBlockAdvertising(isOn)
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.toggle.rawValue, for: indexPath) as! SettingsStaticToggleCell

                cell.titleLabel.text = titleLabel
                cell.isOn = dataModel.blockAdvertising

                return cell
            }

        case .blockTracking:
            let titleLabel = NSLocalizedString(
                "BLOCK_TRACKERS_CELL_LABEL",
                tableName: "Preferences",
                value: "Block trackers",
                comment: ""
            )

            if isEditing {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.editableToggle.rawValue, for: indexPath) as! SettingsSwitchCell

                cell.titleLabel.text = titleLabel
                cell.setOn(dataModel.blockTracking, animated: false)
                cell.action = { [weak self] isOn in
                    self?.setBlockTracking(isOn)
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.toggle.rawValue, for: indexPath) as! SettingsStaticToggleCell

                cell.titleLabel.text = titleLabel
                cell.isOn = dataModel.blockTracking

                return cell
            }

        case .useCustomDNS:
            let titleLabel = NSLocalizedString(
                "CUSTOM_DNS_CELL_LABEL",
                tableName: "Preferences",
                value: "Use custom DNS",
                comment: ""
            )

            if isEditing {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.editableToggle.rawValue, for: indexPath) as! SettingsSwitchCell

                cell.titleLabel.text = titleLabel
                cell.setEnabled(dataModel.canEnableCustomDNS)
                cell.setOn(dataModel.effectiveEnableCustomDNS, animated: false)

                cell.action = { [weak self] isOn in
                    self?.setEnableCustomDNS(isOn)
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.toggle.rawValue, for: indexPath) as! SettingsStaticToggleCell

                cell.titleLabel.text = titleLabel
                cell.isOn = dataModel.effectiveEnableCustomDNS

                return cell
            }

        case .addDNSEntry:
            let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.editableDNSServer.rawValue, for: indexPath) as! SettingsDNSTextCell
            cell.textField.text = dataModel.dnsDomainInput
            cell.isValidInput = dataModel.isValidDNSDomainForVisualPresentation(dataModel.dnsDomainInput)

            cell.onTextChange = { [weak self] cell in
                guard let self = self else { return }

                let text = cell.textField.text ?? ""

                self.dataModel.dnsDomainInput = text
                cell.isValidInput = self.dataModel.isValidDNSDomainForVisualPresentation(text)
            }

            cell.onReturnKey = { [weak self] cell in
                let text = cell.textField.text ?? ""

                if text.isEmpty {
                    cell.endEditing(false)
                } else {
                    self?.commitDNSServer()
                }

            }

            return cell

        case .dnsEntry(let serverIndex):
            let dnsServerAddress = dataModel.customDNSDomains[serverIndex]

            if isEditing {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.editableDNSServer.rawValue, for: indexPath) as! SettingsDNSTextCell
                cell.textField.text = dnsServerAddress
                cell.isValidInput = dataModel.isValidDNSDomainForVisualPresentation(dnsServerAddress)

                cell.onTextChange = { [weak self] cell in
                    guard let self = self else { return }

                    let text = cell.textField.text ?? ""

                    self.dataModel.customDNSDomains[serverIndex] = text
                    cell.isValidInput = self.dataModel.isValidDNSDomainForVisualPresentation(text)
                }

                cell.onReturnKey = { cell in
                    cell.endEditing(false)
                }

                return cell
            } else {
                let cell = tableView.dequeueReusableCell(withIdentifier: ReuseIdentifiers.dnsServer.rawValue, for: indexPath) as! SettingsDNSServerAddressCell

                cell.titleLabel.text = dnsServerAddress

                return cell
            }
        }
    }

    func sectionIndex(for sectionIdentifer: Section) -> Int? {
        return sections.firstIndex(of: sectionIdentifer)
    }

    func sectionIndices(for sectionIdentifiers: [Section]) -> IndexSet {
        let indices = sectionIdentifiers.compactMap { section in
            return sectionIndex(for: section)
        }
        return IndexSet(indices)
    }

    func setBlockAdvertising(_ isEnabled: Bool) {
        let oldDataModel = dataModel

        dataModel.blockAdvertising = isEnabled

        updateCustomDNSFooterIfNeeded(oldDataModel: oldDataModel)
    }

    func setBlockTracking(_ isEnabled: Bool) {
        let oldDataModel = dataModel

        dataModel.blockTracking = isEnabled

        updateCustomDNSFooterIfNeeded(oldDataModel: oldDataModel)
    }

    func setEnableCustomDNS(_ isEnabled: Bool) {
        let oldDataModel = dataModel

        dataModel.enableCustomDNS = isEnabled

        updateCustomDNSFooterIfNeeded(oldDataModel: oldDataModel)
    }

    func updateCustomDNSFooterIfNeeded(oldDataModel: PreferencesDataModel) {
        if oldDataModel.canEnableCustomDNS != dataModel.canEnableCustomDNS {
            tableView?.performBatchUpdates {
                let sectionIndex = sectionIndex(for: .customDNS)!
                let indexPath = mapItemToIndexPath(.useCustomDNS, in: .customDNS)!

                tableView?.reloadRows(at: [indexPath], with: .none)
                tableView?.footerView(forSection: sectionIndex)
            }
        }
    }

    func setEditing(_ editing: Bool) {
        guard isEditing != editing else { return }

        isEditing = editing

        // Since user can edit the existing fields, make sure to filter out invalid input
        if !editing {
            dataModel.customDNSDomains = dataModel.customDNSDomains.compactMap { ipAddressString in
                return AnyIPAddress(ipAddressString).map { ipAddress in
                    return "\(ipAddress)"
                }
            }
        }

        tableView?.reloadData()
    }

    func commitDNSServer() {
        let ipAddress = AnyIPAddress(dataModel.dnsDomainInput)
        let newServerIndex = dataModel.customDNSDomains.count
        let addServerCell = mapItemToCell(.addDNSEntry, in: .customDNS) as? SettingsDNSTextCell

        if let ipAddress = ipAddress {
            dataModel.dnsDomainInput = ""
            dataModel.customDNSDomains.append("\(ipAddress)")

            addServerCell?.textField.text = dataModel.dnsDomainInput
            addServerCell?.isValidInput = dataModel.isValidDNSDomainForVisualPresentation(dataModel.dnsDomainInput)

            let indexPathForNewServer = mapItemToIndexPath(.dnsEntry(newServerIndex), in: .customDNS)!

            tableView?.performBatchUpdates({
                tableView?.insertRows(at: [indexPathForNewServer], with: .automatic)
            }, completion: { completed in
                if completed {
                    if let indexPath = self.mapItemToIndexPath(.addDNSEntry, in: .customDNS) {
                        self.tableView?.scrollToRow(at: indexPath, at: .bottom, animated: true)
                    }
                }
            })
        } else {
            addServerCell?.isValidInput = false
        }
    }

    func deleteDNSServer(at index: Int) {
        let indexPath = mapItemToIndexPath(.dnsEntry(index), in: .customDNS)!

        dataModel.customDNSDomains.remove(at: index)

        tableView?.performBatchUpdates {
            tableView?.deleteRows(at: [indexPath], with: .automatic)
        }
    }

}
