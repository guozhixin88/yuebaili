import AppKit
import EventKit
import Foundation

private let gregorian: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "zh_CN")
    calendar.firstWeekday = 2
    return calendar
}()

private let chineseCalendar: Calendar = {
    var calendar = Calendar(identifier: .chinese)
    calendar.locale = Locale(identifier: "zh_CN")
    return calendar
}()

private enum DisplayPart: String, CaseIterable {
    case date = "showDate"
    case lunar = "showLunar"
    case weekday = "showWeekday"
    case time = "showTime"
    case seconds = "showSeconds"

    var title: String {
        switch self {
        case .date: return "显示日期"
        case .lunar: return "显示农历"
        case .weekday: return "显示星期"
        case .time: return "显示时间"
        case .seconds: return "显示秒数"
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let contextMenu = NSMenu()
    private let calendarController = CalendarPopoverController()
    private var timer: Timer?
    private let defaults = UserDefaults.standard

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        registerDefaults()

        if let button = statusItem.button {
            button.font = NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .regular)
            button.toolTip = "农历日期"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildContextMenu()

        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = calendarController

        calendarController.openCalendar = { [weak self] in
            self?.openCalendar()
        }
        calendarController.quitApp = {
            NSApp.terminate(nil)
        }

        updateTitle()
        configureTimer()
    }

    private func updateTitle() {
        let now = Date()
        statusItem.button?.title = menuBarTitle(from: now)
        calendarController.refreshTodayText()
    }

    private func menuBarTitle(from date: Date) -> String {
        var parts: [String] = []
        if isEnabled(.date) {
            let month = gregorian.component(.month, from: date)
            let day = gregorian.component(.day, from: date)
            parts.append("\(month)月\(day)日")
        }
        if isEnabled(.lunar) {
            parts.append(lunarDay(from: date))
        }
        if isEnabled(.weekday) {
            let weekday = gregorian.component(.weekday, from: date)
            parts.append(weekdayText(weekday))
        }
        if isEnabled(.time) {
            parts.append(timeText(from: date, includeSeconds: isEnabled(.seconds)))
        }
        if parts.isEmpty {
            let month = gregorian.component(.month, from: date)
            let day = gregorian.component(.day, from: date)
            return "\(month)月\(day)日"
        }
        return parts.joined(separator: " ")
    }

    private func registerDefaults() {
        defaults.register(defaults: [
            DisplayPart.date.rawValue: true,
            DisplayPart.lunar.rawValue: true,
            DisplayPart.weekday.rawValue: true,
            DisplayPart.time.rawValue: false,
            DisplayPart.seconds.rawValue: false
        ])
    }

    private func isEnabled(_ part: DisplayPart) -> Bool {
        defaults.bool(forKey: part.rawValue)
    }

    private func configureTimer() {
        timer?.invalidate()
        let interval: TimeInterval = isEnabled(.time) && isEnabled(.seconds) ? 1 : 60
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateTitle()
        }
        RunLoop.main.add(timer!, forMode: .common)
    }

    private func buildContextMenu() {
        contextMenu.removeAllItems()

        let settingsItem = NSMenuItem(title: "设置", action: nil, keyEquivalent: "")
        let settingsMenu = NSMenu()
        for part in DisplayPart.allCases {
            let item = NSMenuItem(title: part.title, action: #selector(toggleDisplayPart(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = part.rawValue
            item.state = isEnabled(part) ? .on : .off
            settingsMenu.addItem(item)
        }
        settingsItem.submenu = settingsMenu
        contextMenu.addItem(settingsItem)
        contextMenu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        contextMenu.addItem(quitItem)
    }

    @objc private func toggleDisplayPart(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let part = DisplayPart(rawValue: raw) else {
            return
        }
        defaults.set(!isEnabled(part), forKey: part.rawValue)

        if part == .time && !isEnabled(.time) {
            defaults.set(false, forKey: DisplayPart.seconds.rawValue)
        }
        if part == .seconds && isEnabled(.seconds) {
            defaults.set(true, forKey: DisplayPart.time.rawValue)
        }

        buildContextMenu()
        configureTimer()
        updateTitle()
    }

    private func timeText(from date: Date, includeSeconds: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = includeSeconds ? "HH:mm:ss" : "HH:mm"
        return formatter.string(from: date)
    }


    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(sender)
            statusItem.menu = contextMenu
            sender.performClick(nil)
            statusItem.menu = nil
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }
        calendarController.showCurrentMonth()
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func openCalendar() {
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/Calendar.app"),
                                           configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

final class CalendarPopoverController: NSViewController {
    var openCalendar: (() -> Void)?
    var quitApp: (() -> Void)?

    private let eventStore = EKEventStore()
    private let titleLabel = NSTextField(labelWithString: "")
    private let gridView = CalendarGridView()
    private let relationButton = NSButton(title: "今天", target: nil, action: nil)
    private let todayLabel = NSTextField(labelWithString: "")
    private var displayedMonth = Date()
    private var selectedDate = Date()
    private var didRequestCalendarAccess = false

    override func loadView() {
        let visual = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: 372, height: 430))
        visual.material = .popover
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.wantsLayer = true

        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 14, right: 18)
        root.translatesAutoresizingMaskIntoConstraints = false
        visual.addSubview(root)
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: visual.leadingAnchor),
            root.trailingAnchor.constraint(equalTo: visual.trailingAnchor),
            root.topAnchor.constraint(equalTo: visual.topAnchor),
            root.bottomAnchor.constraint(equalTo: visual.bottomAnchor)
        ])

        let header = NSStackView()
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8

        let prev = iconButton("chevron.left", fallback: "‹", action: #selector(previousMonth))
        let next = iconButton("chevron.right", fallback: "›", action: #selector(nextMonth))
        titleLabel.alignment = .center
        titleLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .medium)
        titleLabel.textColor = .labelColor

        header.addArrangedSubview(prev)
        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(next)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 240).isActive = true
        root.addArrangedSubview(header)

        gridView.translatesAutoresizingMaskIntoConstraints = false
        gridView.heightAnchor.constraint(equalToConstant: 292).isActive = true
        gridView.month = displayedMonth
        gridView.selectedDate = selectedDate
        gridView.onSelectDate = { [weak self] date in
            self?.selectDate(date)
        }
        root.addArrangedSubview(gridView)

        let footer = NSStackView()
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        let calendarButton = textButton("打开日历", action: #selector(openSystemCalendar))
        configureRelationButton()

        todayLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        todayLabel.textColor = .secondaryLabelColor
        todayLabel.lineBreakMode = .byTruncatingTail

        footer.addArrangedSubview(relationButton)
        footer.addArrangedSubview(todayLabel)
        footer.addArrangedSubview(calendarButton)
        todayLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        todayLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        todayLabel.widthAnchor.constraint(equalToConstant: 220).isActive = true
        root.addArrangedSubview(footer)

        view = visual
        preferredContentSize = visual.frame.size
        refresh()
    }

    func showCurrentMonth() {
        displayedMonth = Date()
        selectedDate = Date()
        refresh()
    }

    func refreshTodayText() {
        relationButton.title = relativeDayText(from: selectedDate)
        todayLabel.stringValue = fullDateText(from: selectedDate)
    }

    private func refresh() {
        let year = gregorian.component(.year, from: displayedMonth)
        let month = gregorian.component(.month, from: displayedMonth)
        titleLabel.stringValue = "\(year) / \(month)"
        gridView.month = displayedMonth
        gridView.selectedDate = selectedDate
        gridView.needsDisplay = true
        refreshTodayText()
        loadHolidayEvents()
    }

    private func iconButton(_ symbolName: String, fallback: String, action: Selector) -> NSButton {
        let button = NSButton(title: fallback, target: self, action: action)
        button.bezelStyle = .regularSquare
        button.isBordered = false
        button.font = NSFont.systemFont(ofSize: 24, weight: .semibold)
        if #available(macOS 11.0, *), let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil) {
            button.image = image
            button.title = ""
            button.imagePosition = .imageOnly
        }
        button.widthAnchor.constraint(equalToConstant: 36).isActive = true
        button.heightAnchor.constraint(equalToConstant: 32).isActive = true
        return button
    }

    private func textButton(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = NSFont.systemFont(ofSize: 12, weight: .regular)
        return button
    }

    private func configureRelationButton() {
        relationButton.target = self
        relationButton.action = #selector(showToday)
        relationButton.bezelStyle = .rounded
        relationButton.controlSize = .small
        relationButton.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        relationButton.alignment = .center
        relationButton.widthAnchor.constraint(equalToConstant: 78).isActive = true
        relationButton.heightAnchor.constraint(equalToConstant: 24).isActive = true
    }

    @objc private func previousMonth() {
        displayedMonth = gregorian.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
        refresh()
    }

    @objc private func nextMonth() {
        displayedMonth = gregorian.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
        refresh()
    }

    @objc private func showToday() {
        displayedMonth = Date()
        selectedDate = Date()
        refresh()
    }

    @objc private func openSystemCalendar() {
        openCalendar?()
    }

    private func loadHolidayEvents() {
        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {
        case .fullAccess, .authorized:
            fetchHolidayEvents()
        case .notDetermined:
            guard !didRequestCalendarAccess else { return }
            didRequestCalendarAccess = true
            requestCalendarAccess()
        default:
            gridView.holidayEvents = [:]
            gridView.needsDisplay = true
        }
    }

    private func requestCalendarAccess() {
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    granted ? self?.fetchHolidayEvents() : self?.clearHolidayEvents()
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    granted ? self?.fetchHolidayEvents() : self?.clearHolidayEvents()
                }
            }
        }
    }

    private func fetchHolidayEvents() {
        guard let firstOfMonth = startOfMonth(for: displayedMonth),
              let rangeStart = gregorian.date(byAdding: .day, value: -10, to: firstOfMonth),
              let rangeEnd = gregorian.date(byAdding: .day, value: 52, to: firstOfMonth) else {
            return
        }

        let holidayCalendars = eventStore.calendars(for: .event).filter { calendar in
            let title = calendar.title
            return title.contains("节假日") || title.contains("假日") || title.localizedCaseInsensitiveContains("holiday")
        }

        guard !holidayCalendars.isEmpty else {
            clearHolidayEvents()
            return
        }

        let predicate = eventStore.predicateForEvents(withStart: rangeStart, end: rangeEnd, calendars: holidayCalendars)
        let events = eventStore.events(matching: predicate)
        var result: [String: HolidayInfo] = [:]

        for event in events where event.isAllDay {
            let info = holidayInfo(fromCalendarTitle: event.title)
            let key = dateKey(event.startDate)
            if let existing = result[key] {
                result[key] = preferredHolidayInfo(existing, info)
            } else {
                result[key] = info
            }
        }

        gridView.holidayEvents = result
        gridView.needsDisplay = true
    }

    private func clearHolidayEvents() {
        gridView.holidayEvents = [:]
        gridView.needsDisplay = true
    }

    private func selectDate(_ date: Date) {
        selectedDate = date
        if !gregorian.isDate(date, equalTo: displayedMonth, toGranularity: .month) {
            displayedMonth = date
            loadHolidayEvents()
        }
        gridView.month = displayedMonth
        gridView.selectedDate = selectedDate
        gridView.needsDisplay = true
        refreshTodayText()
    }

    private func startOfMonth(for date: Date) -> Date? {
        let components = gregorian.dateComponents([.year, .month], from: date)
        return gregorian.date(from: components)
    }
}

final class CalendarGridView: NSView {
    var month = Date()
    var selectedDate = Date()
    var holidayEvents: [String: HolidayInfo] = [:]
    var onSelectDate: ((Date) -> Void)?

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let weekNames = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let width = bounds.width
        let weekHeight: CGFloat = 28
        let cellWidth = width / 7
        let cellHeight = (bounds.height - weekHeight) / 6

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let weekAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]

        for index in 0..<7 {
            let rect = NSRect(x: CGFloat(index) * cellWidth, y: 0, width: cellWidth, height: weekHeight)
            weekNames[index].draw(in: rect.insetBy(dx: 0, dy: 4), withAttributes: weekAttrs)
        }

        guard let firstOfMonth = startOfMonth(for: month) else { return }
        let weekday = gregorian.component(.weekday, from: firstOfMonth)
        let offset = (weekday - gregorian.firstWeekday + 7) % 7
        let startDate = gregorian.date(byAdding: .day, value: -offset, to: firstOfMonth) ?? firstOfMonth
        let shownMonth = gregorian.component(.month, from: month)
        let today = gregorian.startOfDay(for: Date())

        for index in 0..<42 {
            guard let date = gregorian.date(byAdding: .day, value: index, to: startDate) else { continue }
            let col = index % 7
            let row = index / 7
            let rect = NSRect(x: CGFloat(col) * cellWidth,
                              y: weekHeight + CGFloat(row) * cellHeight,
                              width: cellWidth,
                              height: cellHeight)
            drawDay(date, in: rect, shownMonth: shownMonth, today: today, paragraph: paragraph)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let date = date(at: point) else { return }
        onSelectDate?(date)
    }

    private func drawDay(_ date: Date, in rect: NSRect, shownMonth: Int, today: Date, paragraph: NSParagraphStyle) {
        let day = gregorian.component(.day, from: date)
        let month = gregorian.component(.month, from: date)
        let isCurrentMonth = month == shownMonth
        let isToday = gregorian.isDate(date, inSameDayAs: today)
        let isSelected = gregorian.isDate(date, inSameDayAs: selectedDate)
        let holiday = holidayEvents[dateKey(date)]
        let subText = holiday?.subtitle ?? lunarDay(from: date)

        let textColor: NSColor = {
            if isToday { return .white }
            if isSelected { return .labelColor }
            if holiday?.isWorkday == true { return .systemOrange }
            if holiday?.isHoliday == true { return .systemRed }
            return isCurrentMonth ? .labelColor : .tertiaryLabelColor
        }()
        let subTextColor: NSColor = {
            if isToday { return .white.withAlphaComponent(0.92) }
            if holiday?.isWorkday == true { return .systemOrange }
            if holiday?.isHoliday == true { return .systemRed }
            return isCurrentMonth ? .secondaryLabelColor : .tertiaryLabelColor
        }()

        if isSelected && !isToday {
            NSColor.selectedContentBackgroundColor.withAlphaComponent(0.20).setFill()
            let selection = NSBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 2), xRadius: 9, yRadius: 9)
            selection.fill()
        }

        if isToday {
            NSColor.systemRed.setFill()
            let circle = NSBezierPath(ovalIn: NSRect(x: rect.midX - 22, y: rect.minY + 1, width: 44, height: 44))
            circle.fill()
        }

        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 17, weight: .medium),
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let lunarAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: subTextColor,
            .paragraphStyle: paragraph
        ]

        "\(day)".draw(in: NSRect(x: rect.minX, y: rect.minY + 3, width: rect.width, height: 21), withAttributes: dayAttrs)
        subText.draw(in: NSRect(x: rect.minX, y: rect.minY + 25, width: rect.width, height: 16), withAttributes: lunarAttrs)
    }

    private func startOfMonth(for date: Date) -> Date? {
        let components = gregorian.dateComponents([.year, .month], from: date)
        return gregorian.date(from: components)
    }

    private func date(at point: NSPoint) -> Date? {
        let weekHeight: CGFloat = 28
        guard point.y >= weekHeight else { return nil }

        let cellWidth = bounds.width / 7
        let cellHeight = (bounds.height - weekHeight) / 6
        guard cellWidth > 0, cellHeight > 0 else { return nil }

        let col = min(max(Int(point.x / cellWidth), 0), 6)
        let row = min(max(Int((point.y - weekHeight) / cellHeight), 0), 5)
        let index = row * 7 + col

        guard let firstOfMonth = startOfMonth(for: month) else { return nil }
        let weekday = gregorian.component(.weekday, from: firstOfMonth)
        let offset = (weekday - gregorian.firstWeekday + 7) % 7
        let startDate = gregorian.date(byAdding: .day, value: -offset, to: firstOfMonth) ?? firstOfMonth
        return gregorian.date(byAdding: .day, value: index, to: startDate)
    }
}

struct HolidayInfo {
    let subtitle: String
    let isHoliday: Bool
    let isWorkday: Bool
}

private func holidayInfo(fromCalendarTitle title: String) -> HolidayInfo {
    let isWorkday = title.contains("班")
    let isHoliday = title.contains("休")
    let cleaned = title
        .replacingOccurrences(of: "（休）", with: "")
        .replacingOccurrences(of: "(休)", with: "")
        .replacingOccurrences(of: "（班）", with: "")
        .replacingOccurrences(of: "(班)", with: "")
        .replacingOccurrences(of: "休", with: "")
        .replacingOccurrences(of: "班", with: "")
        .trimmingCharacters(in: .whitespacesAndNewlines)
    let subtitle = cleaned.isEmpty ? (isWorkday ? "班" : "休") : cleaned
    return HolidayInfo(subtitle: subtitle, isHoliday: isHoliday, isWorkday: isWorkday)
}

private func preferredHolidayInfo(_ left: HolidayInfo, _ right: HolidayInfo) -> HolidayInfo {
    if left.isHoliday != right.isHoliday {
        return left.isHoliday ? left : right
    }
    if left.isWorkday != right.isWorkday {
        return left.isWorkday ? left : right
    }
    return left.subtitle.count <= right.subtitle.count ? left : right
}

private func dateKey(_ date: Date) -> String {
    let year = gregorian.component(.year, from: date)
    let month = gregorian.component(.month, from: date)
    let day = gregorian.component(.day, from: date)
    return String(format: "%04d-%02d-%02d", year, month, day)
}

private func lunarDay(from date: Date) -> String {
    let components = chineseCalendar.dateComponents([.day], from: date)
    return lunarDayText(components.day ?? 1)
}

private func fullDateText(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "zh_CN")
    formatter.dateFormat = "M月d日 EEEE"

    let components = chineseCalendar.dateComponents([.month, .day, .isLeapMonth], from: date)
    let leap = (components.isLeapMonth ?? false) ? "闰" : ""
    let lunarMonth = lunarMonthText(components.month ?? 1)
    let lunarDay = lunarDayText(components.day ?? 1)

    return "\(formatter.string(from: date))  农历\(leap)\(lunarMonth)月\(lunarDay)"
}

private func relativeDayText(from date: Date) -> String {
    let base = gregorian.startOfDay(for: Date())
    let selected = gregorian.startOfDay(for: date)
    let diff = gregorian.dateComponents([.day], from: base, to: selected).day ?? 0
    if diff == 0 {
        return "今天"
    }
    let absDiff = min(abs(diff), 9999)
    let suffix = abs(diff) > 9999 ? "9999+" : "\(absDiff)"
    return diff > 0 ? "\(suffix)天后" : "\(suffix)天前"
}

private func weekdayText(_ weekday: Int) -> String {
    let names = ["", "周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    return names.indices.contains(weekday) ? names[weekday] : ""
}

private func lunarMonthText(_ month: Int) -> String {
    let names = ["", "正", "二", "三", "四", "五", "六", "七", "八", "九", "十", "冬", "腊"]
    return names.indices.contains(month) ? names[month] : "\(month)"
}

private func lunarDayText(_ day: Int) -> String {
    let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九", "十"]
    switch day {
    case 1...10:
        return "初\(digits[day])"
    case 11...19:
        return "十\(digits[day - 10])"
    case 20:
        return "二十"
    case 21...29:
        return "廿\(digits[day - 20])"
    case 30:
        return "三十"
    default:
        return "\(day)"
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
