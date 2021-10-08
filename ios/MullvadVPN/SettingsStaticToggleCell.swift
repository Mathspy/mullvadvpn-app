//
//  SettingsStaticToggleCell.swift
//  MullvadVPN
//
//  Created by pronebird on 08/10/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit

class SettingsStaticToggleCell: SettingsCell {
    var isOn: Bool = false {
        didSet {
            updateDetailText()
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        detailTitleLabel.font = titleLabel.font
        updateDetailText()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func updateDetailText() {
        if isOn {
            detailTitleLabel.text = NSLocalizedString("ENABLED", tableName: "Settings", value: "Enabled", comment: "")
            detailTitleLabel.textColor = .successColor
        } else {
            detailTitleLabel.text = NSLocalizedString("DISABLED", tableName: "Settings", value: "Disabled", comment: "")
            detailTitleLabel.textColor = .dangerColor
        }
    }
}
