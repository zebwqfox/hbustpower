import UIKit

final class SettingsViewController: ModelViewController, UITableViewDataSource, UITableViewDelegate {
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = PowerTheme.background
        installBackdrop()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.cellLayoutMarginsFollowReadableWidth = true
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 58
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        connectScrolling(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func modelDidChange() {
        guard isViewLoaded else { return }
        tableView.reloadData()
    }

    func numberOfSections(in tableView: UITableView) -> Int { 5 }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { section == 2 || section == 4 ? 2 : 1 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["外观", "提醒", "账户", "调试", "关于"][section]
    }

    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0: return "主题只改变颜色和一点小彩蛋。紫鸟紫、枫烻黄的配色来自朋友。"
        case 1: return "打开应用或回到前台更新时，电量首次低于设定值时提醒一次；回升后再次变低会重新提醒。需允许系统通知。"
        case 2: return "登录信息仅保存在本机钥匙串。"
        default: return nil
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = PowerTheme.surface
        cell.imageView?.tintColor = PowerTheme.accent
        cell.textLabel?.font = .preferredFont(forTextStyle: .body)
        cell.textLabel?.adjustsFontForContentSizeCategory = true
        cell.textLabel?.numberOfLines = 0
        cell.detailTextLabel?.font = .preferredFont(forTextStyle: .subheadline)
        cell.detailTextLabel?.adjustsFontForContentSizeCategory = true
        cell.detailTextLabel?.numberOfLines = 0
        if indexPath.section == 0 {
            cell.textLabel?.text = "主题"
            cell.detailTextLabel?.text = PowerTheme.style.name
            cell.imageView?.image = UIImage(systemName: "paintpalette.fill")
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 1 {
            cell.textLabel?.text = "低电量提醒"
            cell.detailTextLabel?.text = String(format: "低于 %.0f 度", model.lowBalanceThreshold)
            cell.imageView?.image = UIImage(systemName: "bell.badge.fill")
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 2, indexPath.row == 0 {
            cell.textLabel?.text = "重新登录智慧湖科"
            cell.imageView?.image = UIImage(systemName: "person.crop.circle")
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.section == 2 {
            cell.textLabel?.text = "清除登录信息"
            cell.textLabel?.textColor = .systemRed
            cell.imageView?.image = UIImage(systemName: "trash.fill")
            cell.imageView?.tintColor = .systemRed
        } else if indexPath.section == 3 {
            cell.textLabel?.text = "调试与诊断"
            cell.detailTextLabel?.text = "通知 · 连接 · 日志"
            cell.imageView?.image = UIImage(systemName: "stethoscope")
            cell.accessoryType = .disclosureIndicator
        } else if indexPath.row == 1 {
            cell.textLabel?.text = "更新日志"
            cell.detailTextLabel?.text = "版本 " + Changelog.latest.version
            cell.imageView?.image = UIImage(systemName: "list.bullet.rectangle")
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.textLabel?.text = "关于湖科电量"
            cell.detailTextLabel?.text = "开发者的话 · 更新日志"
            cell.imageView?.image = UIImage(systemName: "bolt.circle.fill")
            cell.accessoryType = .disclosureIndicator
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 0 {
            navigationController?.pushViewController(ThemePickerViewController(), animated: true)
            return
        }
        if indexPath.section == 3 {
            navigationController?.pushViewController(DebugViewController(model: model), animated: true)
            return
        }
        if indexPath.section == 4 {
            let next: UIViewController = indexPath.row == 1 ? ChangelogViewController() : AboutViewController(model: model)
            navigationController?.pushViewController(next, animated: true)
            return
        }
        guard indexPath.section == 1 || indexPath.section == 2 else { return }
        if indexPath.section == 1 {
            editThreshold()
        } else if indexPath.row == 0 {
            present(UINavigationController(rootViewController: AuthenticationViewController(model: model)), animated: true)
        } else {
            confirmClearLogin()
        }
    }

    private func editThreshold() {
        let alert = UIAlertController(title: "低电量提醒", message: "剩余电量低于多少度时提醒？", preferredStyle: .alert)
        alert.addTextField { field in
            field.keyboardType = .decimalPad
            field.text = String(format: "%.0f", self.model.lowBalanceThreshold)
            field.placeholder = "例如 20"
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "保存", style: .default) { _ in
            guard let text = alert.textFields?.first?.text, let value = Double(text), value.isFinite, value > 0 else { return }
            self.model.lowBalanceThreshold = value
        })
        present(alert, animated: true)
    }

    private func confirmClearLogin() {
        let alert = UIAlertController(title: "清除登录信息？", message: "下次查询时需要重新登录智慧湖科。", preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "清除", style: .destructive) { _ in self.model.clearLogin() })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = view.bounds
        }
        present(alert, animated: true)
    }
}
