import SwiftUI
import UniformTypeIdentifiers

private enum LayoutMetrics {
    static let detailOuterPadding: CGFloat = 24
    static let sectionSpacing: CGFloat = 20
    static let cardSpacing: CGFloat = 12
    static let cardHorizontalPadding: CGFloat = 12
    static let cardVerticalPadding: CGFloat = 10
    static let itemSpacing: CGFloat = 8
    static let itemVerticalPadding: CGFloat = 4
}

struct ContentView: View {
    @ObservedObject var controller: CursorController
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        VStack(alignment: .leading, spacing: 14) {
            Text("Cursie")
                .font(.headline)

            Text(controller.selectedFolderURL?.lastPathComponent ?? Localized.string("app.chooseCursorFolder"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Label(
                controller.menuStatusLabel,
                systemImage: controller.menuStatusSystemImage
            )
            .font(.footnote)
            .foregroundStyle(controller.hasMenuStatusWarning ? AnyShapeStyle(Color.orange) : AnyShapeStyle(.secondary))

            HStack(spacing: 8) {
                Button(Localized.string("app.openSettings")) {
                    (NSApp.delegate as? AppDelegate)?.openSettingsWindow()
                }
                .buttonStyle(.borderedProminent)
            }

            Divider()

            Text(controller.statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(Localized.string("app.quit")) {
                NSApp.terminate(nil)
            }
            .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(width: 280)
    }
}

struct SettingsView: View {
    @ObservedObject var controller: CursorController
    @ObservedObject private var sparkleUpdateState: SparkleUpdateState
    @ObservedObject private var localization = LocalizationController.shared
    private let sparkleUpdater: SparkleUpdaterController
    @State private var selection: SidebarCursorItem? = .primary(.arrow)
    @State private var isSupplementalExpanded = false
    @State private var keyMonitor: Any?
    @State private var hasShownAdditionalCursorHintThisLaunch = false

    init(controller: CursorController, sparkleUpdater: SparkleUpdaterController = .shared) {
        self.controller = controller
        self.sparkleUpdater = sparkleUpdater
        _sparkleUpdateState = ObservedObject(wrappedValue: sparkleUpdater.updateState)
    }

    var body: some View {
        let _ = localization.selectedLanguage
        let sidebarTopPadding: CGFloat = sparkleUpdateState.hasAvailableUpdate ? 38 : 26
        ZStack {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ScrollViewReader { proxy in
                        ZStack(alignment: .topTrailing) {
                            List(selection: $selection) {
                                ForEach(CursorRole.allCases) { role in
                                    if let assignment = controller.assignment(for: role) {
                                        CursorRoleRow(
                                            assignment: assignment,
                                            hasSelectedFolder: controller.selectedFolderIsValid
                                        )
                                            .tag(SidebarCursorItem.primary(role))
                                            .id(SidebarCursorItem.primary(role))
                                            .contentShape(Rectangle())
                                    }
                                }

                                Section {
                                    Button {
                                        isSupplementalExpanded.toggle()
                                        if isSupplementalExpanded && !hasShownAdditionalCursorHintThisLaunch {
                                            hasShownAdditionalCursorHintThisLaunch = true
                                            controller.activeAlert = UserFacingAlert(
                                                title: Localized.string("app.additionalCursors"),
                                                message: Localized.string("app.additionalCursorHint")
                                            )
                                        }
                                        if !isSupplementalExpanded {
                                            if case .supplemental = selection {
                                                selection = .primary(.arrow)
                                            }
                                        }
                                    } label: {
                                        AdditionalCursorsHeader(isExpanded: isSupplementalExpanded)
                                    }
                                    .buttonStyle(.plain)
                                    .focusable(false)

                                    if isSupplementalExpanded {
                                        ForEach(SupplementalCursorRole.allCases) { role in
                                            SupplementalCursorRoleRow(assignment: controller.supplementalAssignment(for: role))
                                                .contentShape(Rectangle())
                                                .tag(SidebarCursorItem.supplemental(role))
                                                .id(SidebarCursorItem.supplemental(role))
                                        }
                                    }
                                }
                            }
                            .listStyle(.sidebar)
                            .scrollContentBackground(.hidden)
                            // Clear the traffic lights, which float over the top of this card.
                            .padding(.top, sidebarTopPadding)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color.primary.opacity(0.05))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                                    )
                            )
                            .onSelectionChange(of: selection) { newValue in
                                guard let newValue else { return }
                                scrollSidebar(to: newValue, proxy: proxy)
                            }
                            .onAppear {
                                if let selection {
                                    scrollSidebar(to: selection, proxy: proxy)
                                }
                            }

                            if sparkleUpdateState.hasAvailableUpdate {
                                Button {
                                    sparkleUpdater.showAvailableUpdate()
                                } label: {
                                    Label(Localized.string("update.available"), systemImage: "arrow.down.circle.fill")
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                                .focusable(false)
                                .padding(.top, 8)
                                .padding(.trailing, 14)
                                .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                            }
                        }
                        .animation(.easeInOut(duration: 0.16), value: sparkleUpdateState.hasAvailableUpdate)
                    }
                    .frame(width: 250)

                    Group {
                        switch selection {
                        case .primary(let role):
                            if let assignment = controller.assignment(for: role) {
                                CursorRoleDetailView(controller: controller, assignment: assignment)
                            } else {
                                EmptySelectionView()
                            }
                        case .supplemental(let role):
                            SupplementalCursorRoleDetailView(controller: controller, assignment: controller.supplementalAssignment(for: role))
                        case nil:
                            EmptySelectionView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                SystemApplySection(controller: controller)
            }
            .padding(8)
            .background(Color(nsColor: .windowBackgroundColor))

            if controller.isApplyingSystemCursors {
                ApplyingOverlay(progress: controller.systemApplyProgress)
            }
        }
        .ignoresSafeArea()
        .frame(minWidth: 860, minHeight: 620)
        .alert(item: $controller.activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(Localized.string("alert.ok")))
            )
        }
        .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
            handleDrop(providers: providers)
        }
        .onAppear {
            installKeyMonitorIfNeeded()
            sparkleUpdater.checkForAvailableUpdateOnce()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        guard provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) else { return false }
        let dropSelection = selection
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
            guard let url = droppedFileURL(from: item) else {
                Task { @MainActor in
                    controller.activeAlert = UserFacingAlert(
                        title: Localized.string("alert.errorTitle"),
                        message: Localized.string("alert.dropLoadFailed")
                    )
                }
                return
            }
            Task { @MainActor in
                _ = controller.handleDroppedItem(at: url, selection: dropSelection)
            }
        }
        return true
    }

    private func handleSidebarMove(_ direction: MoveCommandDirection) {
        let items = visibleSidebarItems
        guard !items.isEmpty else { return }

        switch direction {
        case .down:
            guard let selection else {
                self.selection = items.first
                return
            }
            guard let index = items.firstIndex(of: selection) else {
                self.selection = items.first
                return
            }
            self.selection = items[(index + 1) % items.count]
        case .up:
            guard let selection else {
                self.selection = items.last
                return
            }
            guard let index = items.firstIndex(of: selection) else {
                self.selection = items.last
                return
            }
            self.selection = items[(index - 1 + items.count) % items.count]
        default:
            break
        }
    }

    private var visibleSidebarItems: [SidebarCursorItem] {
        let primaryItems = CursorRole.allCases.map(SidebarCursorItem.primary)
        guard isSupplementalExpanded else { return primaryItems }
        return primaryItems + SupplementalCursorRole.allCases.map(SidebarCursorItem.supplemental)
    }

    private func scrollSidebar(to item: SidebarCursorItem, proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.12)) {
                proxy.scrollTo(item, anchor: .center)
            }
        }
    }

    private func installKeyMonitorIfNeeded() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard shouldHandleSidebarArrowKey(event) else { return event }

            switch event.keyCode {
            case 125:
                handleSidebarMove(.down)
                return nil
            case 126:
                handleSidebarMove(.up)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        guard let keyMonitor else { return }
        NSEvent.removeMonitor(keyMonitor)
        self.keyMonitor = nil
    }

    private func shouldHandleSidebarArrowKey(_ event: NSEvent) -> Bool {
        guard !controller.isApplyingSystemCursors else { return false }
        guard event.keyCode == 125 || event.keyCode == 126 else { return false }
        guard NSApp.keyWindow != nil else { return false }
        if NSApp.keyWindow?.firstResponder is NSTextView {
            return false
        }
        return true
    }
}

private extension View {
    @ViewBuilder
    func onSelectionChange<Value: Equatable>(
        of value: Value,
        perform action: @escaping (Value) -> Void
    ) -> some View {
        if #available(macOS 14.0, *) {
            self.onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            self.onChange(of: value) { newValue in
                action(newValue)
            }
        }
    }
}

private func droppedFileURL(from item: NSSecureCoding?) -> URL? {
    if let data = item as? Data,
       let url = URL(dataRepresentation: data, relativeTo: nil) {
        return url
    }
    if let url = item as? URL {
        return url
    }
    if let string = item as? String {
        if let url = URL(string: string), url.scheme != nil {
            return url
        }
        return URL(fileURLWithPath: string)
    }
    return nil
}

struct AdditionalCursorsHeader: View {
    let isExpanded: Bool
    @State private var isHovering = false
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        HStack(spacing: 14) {
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .foregroundStyle(.secondary)
                .font(.caption.weight(.semibold))
                .frame(width: 12)

            Text(Localized.string("app.additionalCursors"))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }

    private var backgroundColor: Color {
        if isHovering {
            return Color.primary.opacity(0.09)
        }
        return Color.primary.opacity(0.05)
    }
}

struct EmptySelectionView: View {
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        VStack(spacing: 12) {
            Image(systemName: "cursorarrow")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text(Localized.string("app.noCursorLoaded"))
                .font(.headline)
            Text(Localized.string("app.loadCursorFolderHint"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ApplyingOverlay: View {
    let progress: SystemApplyProgress
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                Text(Localized.string(progress.titleKey))
                    .font(.headline)
                Text(Localized.string(progress.detailKey))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                ProgressView(value: progress.fraction)
                    .progressViewStyle(.linear)
                    .frame(width: 240)
                Text("\(Int((progress.fraction * 100).rounded()))%")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
            .frame(width: 320)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(radius: 20, y: 10)
        }
    }
}

struct SystemApplySection: View {
    @ObservedObject var controller: CursorController
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        controller.restoreSystemCursors()
                    } label: {
                        Label(Localized.string("systemApply.restore"), systemImage: "arrow.counterclockwise")
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                    .disabled(controller.isApplyingSystemCursors)

                    Text(Localized.string("systemApply.restoreHint"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 12)

                Button {
                    controller.applyToSystemCursors()
                } label: {
                    Label(Localized.string("systemApply.apply"), systemImage: "cursorarrow.motionlines")
                }
                .buttonStyle(.borderedProminent)
                .focusable(false)
                .disabled(controller.isApplyingSystemCursors || controller.isLoadingTheme)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            )
    }

}

struct ExportScaleControl: View {
    @ObservedObject var controller: CursorController
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        GroupBox {
            VStack(alignment: .leading, spacing: LayoutMetrics.itemSpacing) {
                HStack {
                    Text(Localized.string("export.sizeLabel"))
                        .font(.headline)
                    Spacer()
                    Text(controller.exportSizePercentageText)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                VStack(spacing: 8) {
                    Slider(value: $controller.exportSizeMultiplier, in: 1.0...3.0, step: 0.1)
                        .focusable(false)
                }
                .padding(.vertical, 8)
            }
            .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
            .padding(.vertical, LayoutMetrics.cardVerticalPadding)
        } label: {
            EmptyView()
        }
    }
}

struct CursorRoleRow: View {
    let assignment: CursorAssignment
    let hasSelectedFolder: Bool
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        HStack(spacing: 10) {
            Image(systemName: statusSymbolName)
                .foregroundStyle(statusColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.role.displayName)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var statusSymbolName: String {
        if !assignment.isResolved {
            return showsAutomaticMappingFailure ? "exclamationmark.triangle.fill" : "circle.dashed"
        }
        if assignment.usesArrowFallback { return "exclamationmark.triangle.fill" }
        if assignment.isOverride { return "slider.horizontal.3" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if !assignment.isResolved {
            return showsAutomaticMappingFailure ? .orange : .secondary
        }
        if assignment.usesArrowFallback { return .orange }
        if assignment.isOverride { return .accentColor }
        return .secondary
    }

    private var subtitle: String {
        if !assignment.isResolved {
            return showsAutomaticMappingFailure ? Localized.string("app.automaticMatchFailed") : Localized.string("app.noCursorLoaded")
        }
        if assignment.usesArrowFallback { return Localized.string("app.automaticMatchFailedArrowFallback") }
        if assignment.isOverride { return assignment.sourceURL?.lastPathComponent ?? Localized.string("app.manualOverride") }
        return assignment.sourceURL?.lastPathComponent ?? Localized.string("app.automaticallyMatched")
    }

    private var showsAutomaticMappingFailure: Bool {
        hasSelectedFolder && !assignment.isResolved
    }
}

struct SupplementalCursorRoleRow: View {
    let assignment: SupplementalCursorAssignment
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        HStack(spacing: 10) {
            Image(systemName: statusSymbolName)
                .foregroundStyle(statusColor)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(assignment.role.displayName)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var statusSymbolName: String {
        if !assignment.isResolved { return "circle.dashed" }
        if assignment.isOverride { return "slider.horizontal.3" }
        return "checkmark.circle.fill"
    }

    private var statusColor: Color {
        if !assignment.isResolved { return .secondary }
        if assignment.isOverride { return .accentColor }
        return .secondary
    }

    private var subtitle: String {
        if !assignment.isResolved { return Localized.string("app.noCursorLoaded") }
        if assignment.isOverride { return assignment.sourceURL?.lastPathComponent ?? Localized.string("app.manualOverride") }
        return Localized.string("app.noCursorLoaded")
    }
}

struct CursorRoleDetailView: View {
    @ObservedObject var controller: CursorController
    let assignment: CursorAssignment
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics.sectionSpacing) {
                SettingsHeader(controller: controller)

                if let appliedPreview = assignment.appliedPreview {
                    PreviewGroup(
                        subtitle: assignment.sourceURL?.lastPathComponent ?? Localized.string("app.automaticallyMatchedFromFolder"),
                        animation: appliedPreview,
                        exportSizeMultiplier: controller.exportSizeMultiplier,
                        largePreviewScale: largePreviewScale
                    ) {
                        Button(Localized.string("app.changeCursorFile")) {
                            controller.chooseOverride(for: assignment.role)
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                } else {
                    EmptyPreviewGroup(
                        subtitle: assignment.sourceURL?.lastPathComponent ?? Localized.string("app.noCursorLoaded")
                    ) {
                        Button(Localized.string("app.changeCursorFile")) {
                            controller.chooseOverride(for: assignment.role)
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                }
                ExportScaleControl(controller: controller)
                GroupBox {
                    VStack(alignment: .leading, spacing: LayoutMetrics.cardSpacing) {
                        if assignment.usesArrowFallback {
                            Label(Localized.string("app.arrowFallbackDescription"), systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                        }
                        DetailItem(title: Localized.string("app.automaticMatchKeywords")) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ThemeResolver.displayKeywords(for: assignment.role, language: Localized.currentLanguage))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        DetailItem(title: Localized.string("app.mousecape")) {
                            Text(assignment.role.mousecapeMappingDescription)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        DetailItem(title: Localized.string("app.currentSource")) {
                            Text(assignment.sourceURL?.path ?? Localized.string("app.automaticallyMatchedInsideSelectedFolder"))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
                    .padding(.vertical, LayoutMetrics.cardVerticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    EmptyView()
                }
            }
            .padding(LayoutMetrics.detailOuterPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var largePreviewScale: CGFloat {
        switch assignment.role {
        case .diagonalResizeNWSE, .diagonalResizeNESW:
            return 1.6
        default:
            return 1.0
        }
    }
}

struct SupplementalCursorRoleDetailView: View {
    @ObservedObject var controller: CursorController
    let assignment: SupplementalCursorAssignment
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        ScrollView {
            VStack(alignment: .leading, spacing: LayoutMetrics.sectionSpacing) {
                SettingsHeader(controller: controller)

                if let appliedPreview = assignment.appliedPreview {
                    PreviewGroup(
                        subtitle: assignment.sourceURL?.lastPathComponent ?? Localized.string("app.automaticallyMatchedFromFolder"),
                        animation: appliedPreview,
                        exportSizeMultiplier: controller.exportSizeMultiplier,
                        largePreviewScale: 1.0
                    ) {
                        Button(Localized.string("app.changeCursorFile")) {
                            controller.chooseOverride(for: assignment.role)
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                } else {
                    EmptyPreviewGroup(
                        subtitle: assignment.sourceURL?.lastPathComponent ?? Localized.string("app.noCursorLoaded")
                    ) {
                        Button(Localized.string("app.changeCursorFile")) {
                            controller.chooseOverride(for: assignment.role)
                        }
                        .buttonStyle(.bordered)
                        .focusable(false)
                    }
                }
                ExportScaleControl(controller: controller)
                GroupBox {
                    VStack(alignment: .leading, spacing: LayoutMetrics.cardSpacing) {
                        Text(Localized.string("app.additionalCursorHint"))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, 6)

                        DetailItem(title: Localized.string("app.inheritedMatchKeywords")) {
                            Text(ThemeResolver.displayKeywords(for: assignment.mappedRole, language: Localized.currentLanguage))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        DetailItem(title: Localized.string("app.mousecape")) {
                            Text(assignment.role.mousecapeMappingDescription)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        DetailItem(title: Localized.string("app.currentSource")) {
                            Text(assignment.sourceURL?.path ?? Localized.string("app.noCursorLoaded"))
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
                    .padding(.vertical, LayoutMetrics.cardVerticalPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                } label: {
                    EmptyView()
                }
            }
            .padding(LayoutMetrics.detailOuterPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct SettingsHeader: View {
    @ObservedObject var controller: CursorController
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        GroupBox {
            VStack(alignment: .leading, spacing: LayoutMetrics.cardSpacing) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Localized.string("app.cursorFolder"))
                            .font(.headline)
                        Text(controller.selectedFolderURL?.path ?? Localized.string("app.noFolderSelected"))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(Localized.string("app.chooseFolder")) {
                        controller.chooseThemeFolder()
                    }
                    .buttonStyle(.bordered)
                    .focusable(false)
                }

            }
            .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
            .padding(.vertical, LayoutMetrics.cardVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct PreviewGroup<TrailingAction: View>: View {
    let subtitle: String
    let animation: CursorAnimation
    let exportSizeMultiplier: Double
    let largePreviewScale: CGFloat
    let trailingAction: TrailingAction
    @ObservedObject private var localization = LocalizationController.shared

    init(
        subtitle: String,
        animation: CursorAnimation,
        exportSizeMultiplier: Double,
        largePreviewScale: CGFloat = 1.0,
        @ViewBuilder trailingAction: () -> TrailingAction = { EmptyView() }
    ) {
        self.subtitle = subtitle
        self.animation = animation
        self.exportSizeMultiplier = exportSizeMultiplier
        self.largePreviewScale = largePreviewScale
        self.trailingAction = trailingAction()
    }

    var body: some View {
        let _ = localization.selectedLanguage
        GroupBox {
            VStack(alignment: .leading, spacing: LayoutMetrics.cardSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(subtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    trailingAction
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: LayoutMetrics.itemSpacing) {
                        Text(Localized.string("preview.large"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        CursorPreviewView(animation: animation, previewScale: largePreviewScale)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: LayoutMetrics.itemSpacing) {
                        Text(Localized.string("preview.actualSize"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        CursorActualSizePreviewView(
                            animation: animation,
                            exportSizeMultiplier: exportSizeMultiplier
                        )
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
            .padding(.vertical, LayoutMetrics.cardVerticalPadding)
        } label: {
            EmptyView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct DetailItem<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.semibold))
            content
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, LayoutMetrics.itemVerticalPadding)
    }
}

struct EmptyPreviewGroup<TrailingAction: View>: View {
    let subtitle: String
    let trailingAction: TrailingAction
    @ObservedObject private var localization = LocalizationController.shared

    init(
        subtitle: String,
        @ViewBuilder trailingAction: () -> TrailingAction = { EmptyView() }
    ) {
        self.subtitle = subtitle
        self.trailingAction = trailingAction()
    }

    var body: some View {
        let _ = localization.selectedLanguage
        GroupBox {
            VStack(alignment: .leading, spacing: LayoutMetrics.cardSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(subtitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    trailingAction
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: LayoutMetrics.itemSpacing) {
                        Text(Localized.string("preview.large"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        EmptyPreviewPane()
                    }

                    VStack(alignment: .leading, spacing: LayoutMetrics.itemSpacing) {
                        Text(Localized.string("preview.actualSize"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        EmptyPreviewPane()
                    }
                }
            }
            .padding(.horizontal, LayoutMetrics.cardHorizontalPadding)
            .padding(.vertical, LayoutMetrics.cardVerticalPadding)
        } label: {
            EmptyView()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct EmptyPreviewPane: View {
    @ObservedObject private var localization = LocalizationController.shared

    var body: some View {
        let _ = localization.selectedLanguage
        VStack(spacing: LayoutMetrics.cardSpacing) {
            Image(systemName: "cursorarrow")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(Localized.string("app.cursorWillAppearHere"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(height: 220)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct CursorPreviewView: View {
    let animation: CursorAnimation
    let previewScale: CGFloat

    var body: some View {
        CursorAnimatedImageView(
            animation: animation,
            displayMode: .scaledFit(scale: previewScale, padding: 24)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CursorActualSizePreviewView: View {
    let animation: CursorAnimation
    let exportSizeMultiplier: Double

    var body: some View {
        let displaySize = actualDisplaySize(for: animation, multiplier: exportSizeMultiplier)
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
                .padding(24)

            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 1, height: 120)
            Rectangle()
                .fill(Color.secondary.opacity(0.18))
                .frame(width: 120, height: 1)

            CursorAnimatedImageView(
                animation: animation,
                displayMode: .actualSize(size: displaySize)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(24)
    }

    private func actualDisplaySize(for animation: CursorAnimation, multiplier: Double) -> CGSize {
        CapeExporter.previewDisplaySize(for: animation, sizeMultiplier: multiplier)
    }

}

private struct CursorAnimatedImageView: NSViewRepresentable {
    let animation: CursorAnimation
    let displayMode: CursorPreviewDisplayMode

    func makeNSView(context: Context) -> CursorAnimatedImageContainer {
        CursorAnimatedImageContainer()
    }

    func updateNSView(_ nsView: CursorAnimatedImageContainer, context: Context) {
        nsView.configure(animation: animation, displayMode: displayMode)
    }
}

private enum CursorPreviewDisplayMode: Equatable {
    case scaledFit(scale: CGFloat, padding: CGFloat)
    case actualSize(size: CGSize)
}

@MainActor
private final class CursorAnimatedImageContainer: NSView {
    private struct Signature: Equatable {
        let imageIDs: [ObjectIdentifier]
        let delays: [TimeInterval]
        let canvasSize: CGSize
        let displayMode: CursorPreviewDisplayMode

        init(animation: CursorAnimation, displayMode: CursorPreviewDisplayMode) {
            imageIDs = animation.frames.map { ObjectIdentifier($0.image) }
            delays = animation.frames.map(\.delay)
            canvasSize = animation.canvasSize
            self.displayMode = displayMode
        }
    }

    private let imageView = PixelatedImageView()
    private var animation: CursorAnimation?
    private var displayMode = CursorPreviewDisplayMode.scaledFit(scale: 1, padding: 0)
    private var signature: Signature?
    private var frameTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(imageView)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateFrameTimer()
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if newWindow == nil {
            frameTimer?.invalidate()
            frameTimer = nil
        }
    }

    override func layout() {
        super.layout()
        layoutImageView()
    }

    func configure(animation: CursorAnimation, displayMode: CursorPreviewDisplayMode) {
        let nextSignature = Signature(animation: animation, displayMode: displayMode)
        guard nextSignature != signature else { return }

        self.animation = animation
        self.displayMode = displayMode
        signature = nextSignature
        updateImage(at: Date())
        updateFrameTimer()
        needsLayout = true
    }

    private func updateFrameTimer() {
        frameTimer?.invalidate()
        frameTimer = nil

        guard
            window != nil,
            let animation,
            let interval = CursorPreviewTimeline.refreshInterval(for: animation)
        else {
            return
        }

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateImage(at: Date())
            }
        }
        timer.tolerance = min(interval * 0.25, 0.02)
        RunLoop.main.add(timer, forMode: .common)
        frameTimer = timer
    }

    private func updateImage(at date: Date) {
        guard let animation, !animation.frames.isEmpty else {
            imageView.image = nil
            return
        }

        let frameIndex = CursorPreviewTimeline.frameIndex(for: animation, at: date)
        imageView.image = animation.frames[min(frameIndex, animation.frames.count - 1)].image
    }

    private func layoutImageView() {
        switch displayMode {
        case .scaledFit(let scale, let padding):
            imageView.frame = scaledFitFrame(scale: scale, padding: padding)
        case .actualSize(let size):
            imageView.frame = CursorPreviewLayout.actualSizeFrame(
                in: bounds,
                size: size
            )
        }
    }

    private func scaledFitFrame(scale: CGFloat, padding: CGFloat) -> NSRect {
        let available = bounds.insetBy(dx: padding, dy: padding)
        guard
            let image = imageView.image,
            image.size.width > 0,
            image.size.height > 0,
            available.width > 0,
            available.height > 0
        else {
            return available
        }

        let fitScale = min(available.width / image.size.width, available.height / image.size.height)
        let finalScale = fitScale * scale
        let size = NSSize(width: image.size.width * finalScale, height: image.size.height * finalScale)
        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        ).integral
    }
}

enum CursorPreviewLayout {
    static func actualSizeFrame(in bounds: NSRect, size: CGSize) -> NSRect {
        NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        ).integral
    }
}

@MainActor
private final class PixelatedImageView: NSView {
    var image: NSImage? {
        didSet {
            needsDisplay = true
        }
    }

    override var isFlipped: Bool {
        true
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .nearest
        layer?.contentsGravity = .resize
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let image else { return }
        NSGraphicsContext.current?.imageInterpolation = .none
        image.draw(
            in: bounds,
            from: NSRect(origin: .zero, size: image.size),
            operation: .copy,
            fraction: 1.0,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.none]
        )
    }
}
