//
//  SettingsCell.swift
//  MullvadVPN
//
//  Created by pronebird on 22/05/2019.
//  Copyright © 2019 Mullvad VPN AB. All rights reserved.
//

import UIKit

class SettingsCell: BasicTableViewCell {
    static let disabledCellOpacity: CGFloat = 0.5

    let titleLabel = UILabel()
    let detailTitleLabel = UILabel()

    var isEnabled: Bool = true {
        didSet {
            let opacity = isEnabled ? 1 : Self.disabledCellOpacity
            contentView.alpha = opacity
            isUserInteractionEnabled = isEnabled
        }
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        tintColor = .white
        backgroundView?.backgroundColor = UIColor.Cell.backgroundColor
        selectedBackgroundView?.backgroundColor = UIColor.Cell.selectedAltBackgroundColor
        separatorInset = .zero

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 17)
        titleLabel.textColor = .white

        detailTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        detailTitleLabel.font = UIFont.systemFont(ofSize: 13)
        detailTitleLabel.textColor = .white

        titleLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        detailTitleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)

        titleLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        detailTitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentView.addSubview(titleLabel)
        contentView.addSubview(detailTitleLabel)

        setLayoutMargins()

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            titleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),

            detailTitleLabel.leadingAnchor.constraint(greaterThanOrEqualToSystemSpacingAfter: titleLabel.trailingAnchor, multiplier: 1),

            detailTitleLabel.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            detailTitleLabel.topAnchor.constraint(equalTo: contentView.layoutMarginsGuide.topAnchor),
            detailTitleLabel.bottomAnchor.constraint(equalTo: contentView.layoutMarginsGuide.bottomAnchor),
        ])

        enableDisclosureViewTintColorFix()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        setLayoutMargins()
    }

    override func didAddSubview(_ subview: UIView) {
        super.didAddSubview(subview)

        if let button = subview as? UIButton {
            updateDisclosureButtonBackgroundImageRenderingMode(button)
        }
    }

    /// `UITableViewCell` resets the disclosure view image when the app goes in background
    /// This fix ensures that the image is tinted when the app becomes active again.
    private func enableDisclosureViewTintColorFix() {
        appDidBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: nil) { [weak self] (note) in
                self?.updateDisclosureViewTintColor()
        }

        updateDisclosureViewTintColor()
    }

    private func setLayoutMargins() {
        // Set layout margins for standard acceessories added into the cell (reorder control, etc..)
        layoutMargins = UIMetrics.settingsCellLayoutMargins

        // Set layout margins for cell content
        contentView.layoutMargins = UIMetrics.settingsCellLayoutMargins
    }

    /// For some reason the `tintColor` is not applied to standard accessory views.
    /// Fix this by looking for the accessory button and changing the image rendering mode
    private func updateDisclosureViewTintColor() {
        for case let button as UIButton in subviews {
            updateDisclosureButtonBackgroundImageRenderingMode(button)
        }
    }

    private func updateDisclosureButtonBackgroundImageRenderingMode(_ button: UIButton) {
        if let image = button.backgroundImage(for: .normal)?.withRenderingMode(.alwaysTemplate) {
            button.setBackgroundImage(image, for: .normal)
        }
    }
}
