//
//  SettingsDNSServerAddressCell.swift
//  MullvadVPN
//
//  Created by pronebird on 08/10/2021.
//  Copyright © 2021 Mullvad VPN AB. All rights reserved.
//

import UIKit

class SettingsDNSServerAddressCell: SettingsCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundView?.backgroundColor = UIColor.SubCell.backgroundColor

        indentationWidth = 16
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let indentPoints = CGFloat(indentationLevel) * indentationWidth

        contentView.frame = CGRect(
            x: indentPoints,
            y: contentView.frame.origin.y,
            width: contentView.frame.size.width - indentPoints,
            height: contentView.frame.size.height
        )
    }
}
