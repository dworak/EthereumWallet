// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import Photos
import UIKit
import WebKit
import Shared
import Storage
import SnapKit
import Account
import MobileCoreServices
import Telemetry
import Common
import ComponentLibrary
import Redux

class BrowserViewController: UIViewController,
                             SearchBarLocationProvider,
                             Themeable,
                             LibraryPanelDelegate,
                             RecentlyClosedPanelDelegate,
                             QRCodeViewControllerDelegate,
                             StoreSubscriber {
    private enum UX {
        static let ShowHeaderTapAreaHeight: CGFloat = 32
        static let ActionSheetTitleMaxLength = 120
    }

    typealias SubscriberStateType = BrowserViewControllerState

    private let KVOs: [KVOConstants] = [
        .estimatedProgress,
        .loading,
        .canGoBack,
        .canGoForward,
        .URL,
        .title,
    ]

    weak var browserDelegate: BrowserDelegate?
    weak var navigationHandler: BrowserNavigationHandler?

    var urlBar: URLBarView!
    var urlBarHeightConstraint: Constraint!
    var clipboardBarDisplayHandler: ClipboardBarDisplayHandler?
    var readerModeBar: ReaderModeBarView?
    var readerModeCache: ReaderModeCache
    var statusBarOverlay: StatusBarOverlay = .build { _ in }
    var searchController: SearchViewController?
    var screenshotHelper: ScreenshotHelper!
    var searchTelemetry: SearchTelemetry?
    var searchLoader: SearchLoader?
    var findInPageBar: FindInPageBar?
    var zoomPageBar: ZoomPageBar?
    lazy var mailtoLinkHandler = MailtoLinkHandler()
    var urlFromAnotherApp: UrlToOpenModel?
    var isCrashAlertShowing = false
    var currentMiddleButtonState: MiddleButtonState?
    var openedUrlFromExternalSource = false
    var passBookHelper: OpenPassBookHelper?
    var overlayManager: OverlayModeManager
    var appAuthenticator: AppAuthenticationProtocol
    var toolbarContextHintVC: ContextualHintViewController
    let shoppingContextHintVC: ContextualHintViewController
    private var backgroundTabLoader: DefaultBackgroundTabLoader
    var summaryViewController: SummaryViewController?

    // popover rotation handling
    var displayedPopoverController: UIViewController?
    var updateDisplayedPopoverProperties: (() -> Void)?

    // location label actions
    var pasteGoAction: AccessibleAction!
    var pasteAction: AccessibleAction!
    var copyAddressAction: AccessibleAction!

    weak var gridTabTrayController: LegacyGridTabViewController?
    var tabTrayViewController: TabTrayController?

    let profile: Profile
    let tabManager: TabManager
    let ratingPromptManager: RatingPromptManager
    lazy var isTabTrayRefactorEnabled: Bool = TabTrayFlagManager.isRefactorEnabled
    private var browserViewControllerState: BrowserViewControllerState?

    // Header stack view can contain the top url bar, top reader mode, top ZoomPageBar
    var header: BaseAlphaStackView = .build { _ in }

    // OverKeyboardContainer stack view contains
    // the bottom reader mode, the bottom url bar and the ZoomPageBar
    var overKeyboardContainer: BaseAlphaStackView = .build { _ in }

    // Overlay dimming view for private mode
    lazy var privateModeDimmingView: UIView = .build { view in
        view.backgroundColor = self.themeManager.currentTheme.colors.layerScrim
        view.accessibilityIdentifier = AccessibilityIdentifiers.PrivateMode.dimmingView
    }

    // BottomContainer stack view contains toolbar
    var bottomContainer: BaseAlphaStackView = .build { _ in }

    // Alert content that appears on top of the content
    // ex: Find In Page, SnackBars
    var bottomContentStackView: BaseAlphaStackView = .build { stackview in
        stackview.isClearBackground = true
    }

    // The content stack view contains the contentContainer with homepage or browser and the shopping sidebar
    var contentStackView: SidebarEnabledView = .build()

    // The content container contains the homepage or webview. Embeded by the coordinator.
    var contentContainer: ContentContainer = .build { _ in }

    lazy var isBottomSearchBar: Bool = {
        guard isSearchBarLocationFeatureEnabled else { return false }
        return searchBarPosition == .bottom
    }()

    private var topTouchArea: UIButton!

    var topTabsVisible: Bool {
        return topTabsViewController != nil
    }
    // Backdrop used for displaying greyed background for private tabs
    var webViewContainerBackdrop: UIView!
    var keyboardBackdrop: UIView?

    var scrollController = TabScrollingController()
    private var keyboardState: KeyboardState?
    var pendingToast: Toast? // A toast that might be waiting for BVC to appear before displaying
    var downloadToast: DownloadToast? // A toast that is showing the combined download progress

    /// Set to true when the user taps the home button. Used to prevent entering overlay mode.
    /// Immediately set to false afterwards.
    var userHasPressedHomeButton = false

    // Tracking navigation items to record history types.
    // TODO: weak references?
    var ignoredNavigation = Set<WKNavigation>()
    var typedNavigation = [WKNavigation: VisitType]()
    var toolbar = TabToolbar()
    var navigationToolbar: TabToolbarProtocol {
        return toolbar.isHidden ? urlBar : toolbar
    }

    var topTabsViewController: TopTabsViewController?

    // Keep track of allowed `URLRequest`s from `webView(_:decidePolicyFor:decisionHandler:)` so
    // that we can obtain the originating `URLRequest` when a `URLResponse` is received. This will
    // allow us to re-trigger the `URLRequest` if the user requests a file to be downloaded.
    var pendingRequests = [String: URLRequest]()

    // This is set when the user taps "Download Link" from the context menu. We then force a
    // download of the next request through the `WKNavigationDelegate` that matches this web view.
    weak var pendingDownloadWebView: WKWebView?

    let downloadQueue: DownloadQueue

    private var keyboardPressesHandlerValue: Any?

    var themeManager: ThemeManager
    var notificationCenter: NotificationProtocol
    var themeObserver: NSObjectProtocol?

    var logger: Logger

    var newTabSettings: NewTabPage {
        return NewTabAccessors.getNewTabPage(profile.prefs)
    }

    @available(iOS 13.4, *)
    func keyboardPressesHandler() -> KeyboardPressesHandler {
        guard let keyboardPressesHandlerValue = keyboardPressesHandlerValue as? KeyboardPressesHandler else {
            keyboardPressesHandlerValue = KeyboardPressesHandler()
            return keyboardPressesHandlerValue as! KeyboardPressesHandler
        }
        return keyboardPressesHandlerValue
    }

    init(
        profile: Profile,
        tabManager: TabManager,
        themeManager: ThemeManager = AppContainer.shared.resolve(),
        notificationCenter: NotificationProtocol = NotificationCenter.default,
        ratingPromptManager: RatingPromptManager = AppContainer.shared.resolve(),
        downloadQueue: DownloadQueue = AppContainer.shared.resolve(),
        logger: Logger = DefaultLogger.shared,
        appAuthenticator: AppAuthenticationProtocol = AppAuthenticator()
    ) {
        self.profile = profile
        self.tabManager = tabManager
        self.themeManager = themeManager
        self.notificationCenter = notificationCenter
        self.ratingPromptManager = ratingPromptManager
        self.readerModeCache = DiskReaderModeCache.sharedInstance
        self.downloadQueue = downloadQueue
        self.logger = logger
        self.appAuthenticator = appAuthenticator
        self.overlayManager = DefaultOverlayModeManager()
        let contextualViewProvider = ContextualHintViewProvider(forHintType: .toolbarLocation,
                                                                with: profile)
        self.toolbarContextHintVC = ContextualHintViewController(with: contextualViewProvider)
        let shoppingViewProvider = ContextualHintViewProvider(forHintType: .shoppingExperience,
                                                              with: profile)
        shoppingContextHintVC = ContextualHintViewController(with: shoppingViewProvider)
        self.backgroundTabLoader = DefaultBackgroundTabLoader(tabQueue: profile.queue)
        super.init(nibName: nil, bundle: nil)
        didInit()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        unsubscribeFromRedux()
    }

    override var prefersStatusBarHidden: Bool {
        return false
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .allButUpsideDown
        } else {
            return .all
        }
    }

    fileprivate func didInit() {
        screenshotHelper = ScreenshotHelper(controller: self)
        tabManager.addDelegate(self)
        tabManager.addNavigationDelegate(self)
        downloadQueue.delegate = self
        let tabWindowUUID = tabManager.windowUUID
        AppEventQueue.wait(for: [.startupFlowComplete, .tabRestoration(tabWindowUUID)]) { [weak self] in
            // Ensure we call into didBecomeActive at least once during startup flow (if needed)
            guard !AppEventQueue.activityIsCompleted(.browserUpdatedForAppActivation(tabWindowUUID)) else { return }
            self?.browserDidBecomeActive()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        LegacyThemeManager.instance.statusBarStyle
    }

    @objc
    private func didAddPendingBlobDownloadToQueue() {
        pendingDownloadWebView = nil
    }

    /// If user manually opens the keyboard and presses undo, the app switches to the last
    /// open tab, and because of that we need to leave overlay state
    @objc
    func didTapUndoCloseAllTabToast(notification: Notification) {
        overlayManager.switchTab(shouldCancelLoading: true)
    }

    @objc
    func didFinishAnnouncement(notification: Notification) {
        if let userInfo = notification.userInfo,
            let announcementText =  userInfo[UIAccessibility.announcementStringValueUserInfoKey] as? String {
            let saveSuccessMessage: String = .CreditCard.RememberCreditCard.CreditCardSaveSuccessToastMessage
            let updateSuccessMessage: String = .CreditCard.UpdateCreditCard.CreditCardUpdateSuccessToastMessage
            if announcementText == saveSuccessMessage || announcementText == updateSuccessMessage {
                UIAccessibility.post(notification: .layoutChanged, argument: self.tabManager.selectedTab?.currentWebView())
            }
        }
    }

    @objc
    func searchBarPositionDidChange(notification: Notification) {
        guard let dict = notification.object as? NSDictionary,
              let newSearchBarPosition = dict[PrefsKeys.FeatureFlags.SearchBarPosition] as? SearchBarPosition,
              urlBar != nil
        else { return }

        let newPositionIsBottom = newSearchBarPosition == .bottom
        let newParent = newPositionIsBottom ? overKeyboardContainer : header
        urlBar.removeFromParent()
        urlBar.addToParent(parent: newParent)

        if let readerModeBar = readerModeBar {
            readerModeBar.removeFromParent()
            readerModeBar.addToParent(parent: newParent, addToTop: newSearchBarPosition == .bottom)
        }

        isBottomSearchBar = newPositionIsBottom
        updateViewConstraints()
        updateHeaderConstraints()
        toolbar.setNeedsDisplay()
        urlBar.updateConstraints()
    }

    func shouldShowToolbarForTraitCollection(_ previousTraitCollection: UITraitCollection) -> Bool {
        return previousTraitCollection.verticalSizeClass != .compact && previousTraitCollection.horizontalSizeClass != .regular
    }

    func shouldShowTopTabsForTraitCollection(_ newTraitCollection: UITraitCollection) -> Bool {
        return newTraitCollection.verticalSizeClass == .regular && newTraitCollection.horizontalSizeClass == .regular
    }

    @objc
    fileprivate func appMenuBadgeUpdate() {
        let actionNeeded = RustFirefoxAccounts.shared.isActionNeeded
        let showWarningBadge = actionNeeded

        urlBar.warningMenuBadge(setVisible: showWarningBadge)
        toolbar.warningMenuBadge(setVisible: showWarningBadge)
    }

    func updateToolbarStateForTraitCollection(_ newCollection: UITraitCollection) {
        let showToolbar = shouldShowToolbarForTraitCollection(newCollection)
        let showTopTabs = shouldShowTopTabsForTraitCollection(newCollection)

        let hideReloadButton = shouldUseiPadSetup(traitCollection: newCollection)
        urlBar.topTabsIsShowing = showTopTabs
        urlBar.setShowToolbar(!showToolbar, hideReloadButton: hideReloadButton)
        toolbar.addNewTabButton.isHidden = showToolbar

        if showToolbar {
            toolbar.isHidden = false
            toolbar.tabToolbarDelegate = self
            toolbar.applyUIMode(isPrivate: tabManager.selectedTab?.isPrivate ?? false, theme: themeManager.currentTheme)
            toolbar.applyTheme(theme: themeManager.currentTheme)
            toolbar.updateMiddleButtonState(currentMiddleButtonState ?? .search)
            updateTabCountUsingTabManager(self.tabManager)
        } else {
            toolbar.tabToolbarDelegate = nil
            toolbar.isHidden = true
        }

        appMenuBadgeUpdate()

        if showTopTabs, topTabsViewController == nil {
            let topTabsViewController = TopTabsViewController(tabManager: tabManager, profile: profile)
            topTabsViewController.delegate = self
            addChild(topTabsViewController)
            header.addArrangedViewToTop(topTabsViewController.view)
            self.topTabsViewController = topTabsViewController
            topTabsViewController.applyTheme()
        } else if showTopTabs, topTabsViewController != nil {
            topTabsViewController?.applyTheme()
        } else {
            if let topTabsView = topTabsViewController?.view {
                header.removeArrangedView(topTabsView)
            }
            topTabsViewController?.removeFromParent()
            topTabsViewController = nil
        }

        header.setNeedsLayout()
        view.layoutSubviews()

        if let tab = tabManager.selectedTab,
           let webView = tab.webView {
            updateURLBarDisplayURL(tab)
            navigationToolbar.updateBackStatus(webView.canGoBack)
            navigationToolbar.updateForwardStatus(webView.canGoForward)
        }
    }

    func dismissVisibleMenus() {
        displayedPopoverController?.dismiss(animated: true)
        if self.presentedViewController as? PhotonActionSheet != nil {
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
    }

    @objc
    func appDidEnterBackgroundNotification() {
        displayedPopoverController?.dismiss(animated: false) {
            self.updateDisplayedPopoverProperties = nil
            self.displayedPopoverController = nil
        }
        if self.presentedViewController as? PhotonActionSheet != nil {
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
        // Formerly these calls were run during AppDelegate.didEnterBackground(), but we have
        // individual TabManager instances for each BVC, so we perform these here instead.
        tabManager.preserveTabs()
        // TODO: [FXIOS-7856] Some additional updates for telemetry forthcoming, once iPad multi-window is enabled.
        TabsQuantityTelemetry.trackTabsQuantity(tabManager: tabManager)
    }

    @objc
    func tappedTopArea() {
        scrollController.showToolbars(animated: true)
    }

    @objc
    func appWillResignActiveNotification() {
        // Dismiss any popovers that might be visible
        displayedPopoverController?.dismiss(animated: false) {
            self.updateDisplayedPopoverProperties = nil
            self.displayedPopoverController = nil
        }

        // If we are displaying a private tab, hide any elements in the tab that we wouldn't want shown
        // when the app is in the home switcher
        guard let privateTab = tabManager.selectedTab,
              privateTab.isPrivate
        else { return }

        view.bringSubviewToFront(webViewContainerBackdrop)
        webViewContainerBackdrop.alpha = 1
        contentStackView.alpha = 0
        urlBar.locationContainer.alpha = 0
        presentedViewController?.popoverPresentationController?.containerView?.alpha = 0
        presentedViewController?.view.alpha = 0
    }

    @objc
    func appDidBecomeActiveNotification() {
        // Re-show any components that might have been hidden because they were being displayed
        // as part of a private mode tab
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: UIView.AnimationOptions(),
            animations: {
                self.contentStackView.alpha = 1
                self.urlBar.locationContainer.alpha = 1
                self.presentedViewController?.popoverPresentationController?.containerView?.alpha = 1
                self.presentedViewController?.view.alpha = 1
            }, completion: { _ in
                self.webViewContainerBackdrop.alpha = 0
                self.view.sendSubviewToBack(self.webViewContainerBackdrop)
            })

        // Re-show toolbar which might have been hidden during scrolling (prior to app moving into the background)
        scrollController.showToolbars(animated: false)

        browserDidBecomeActive()
    }

    func browserDidBecomeActive() {
        let uuid = tabManager.windowUUID
        AppEventQueue.started(.browserUpdatedForAppActivation(uuid))
        defer { AppEventQueue.completed(.browserUpdatedForAppActivation(uuid)) }

        // Update lock icon without redrawing the whole locationView
        if let tab = tabManager.selectedTab {
            urlBar.locationView.tabDidChangeContentBlocking(tab)
        }

        updateWallpaperMetadata()
        dismissModalsIfStartAtHome()

        // When, for example, you "Load in Background" via the share sheet, the tab is added to `Profile`'s `TabQueue`.
        // Make sure that our startup flow is completed and other tabs have been restored before we load.
        AppEventQueue.wait(for: [.startupFlowComplete, .tabRestoration(tabManager.windowUUID)]) { [weak self] in
            self?.backgroundTabLoader.loadBackgroundTabs()
        }
    }

    private func dismissModalsIfStartAtHome() {
        if tabManager.startAtHomeCheck() {
            store.dispatch(FakespotAction.setAppearanceTo(false))
            guard presentedViewController != nil else { return }
            dismissVC()
        }
    }

    // MARK: - Redux

    func subscribeToRedux() {
        store.dispatch(ActiveScreensStateAction.showScreen(.browserViewController))

        store.subscribe(self, transform: {
            $0.select(BrowserViewControllerState.init)
        })
    }

    func unsubscribeFromRedux() {
        store.unsubscribe(self)
    }

    func newState(state: BrowserViewControllerState) {
        ensureMainThread { [weak self] in
            guard let self else { return }

            browserViewControllerState = state

            // opens or close sidebar/bottom sheet to match the saved state
            if state.fakespotState.isOpen {
                guard let productURL = urlBar.currentURL else { return }
                handleFakespotFlow(productURL: productURL)
            } else if !state.fakespotState.isOpen {
                dismissFakespotIfNeeded()
            }
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        KeyboardHelper.defaultHelper.addDelegate(self)
        trackTelemetry()
        setupNotifications()
        addSubviews()
        listenForThemeChange(view)
        setupAccessibleActions()

        clipboardBarDisplayHandler = ClipboardBarDisplayHandler(prefs: profile.prefs, tabManager: tabManager)
        clipboardBarDisplayHandler?.delegate = self

        scrollController.header = header
        scrollController.overKeyboardContainer = overKeyboardContainer
        scrollController.bottomContainer = bottomContainer

        updateToolbarStateForTraitCollection(traitCollection)

        setupConstraints()

        // Setup UIDropInteraction to handle dragging and dropping
        // links into the view from other apps.
        let dropInteraction = UIDropInteraction(delegate: self)
        view.addInteraction(dropInteraction)

        updateLegacyTheme()

        searchTelemetry = SearchTelemetry()

        // Awesomebar Location Telemetry
        SearchBarSettingsViewModel.recordLocationTelemetry(for: isBottomSearchBar ? .bottom : .top)

        overlayManager.setURLBar(urlBarView: urlBar)

        // Update theme of already existing views
        let theme = themeManager.currentTheme
        header.applyTheme(theme: theme)
        overKeyboardContainer.applyTheme(theme: theme)
        bottomContainer.applyTheme(theme: theme)
        bottomContentStackView.applyTheme(theme: theme)
        statusBarOverlay.hasTopTabs = shouldShowTopTabsForTraitCollection(traitCollection)
        statusBarOverlay.applyTheme(theme: theme)

        // Feature flag for credit card until we fully enable this feature
        let autofillCreditCardStatus = featureFlags.isFeatureEnabled(
            .creditCardAutofillStatus, checking: .buildOnly)
        // We need to update autofill status on sync manager as there could be delay from nimbus
        // in getting the value. When the delay happens the credit cards might not sync
        // as the default value is false
        profile.syncManager.updateCreditCardAutofillStatus(value: autofillCreditCardStatus)
        // Credit card initial setup telemetry
        creditCardInitialSetupTelemetry()

        // Send settings telemetry for Fakespot
        FakespotUtils().addSettingTelemetry()

        subscribeToRedux()
    }

    private func setupAccessibleActions() {
        // UIAccessibilityCustomAction subclass holding an AccessibleAction instance does not work,
        // thus unable to generate AccessibleActions and UIAccessibilityCustomActions "on-demand" and need
        // to make them "persistent" e.g. by being stored in BVC
        pasteGoAction = AccessibleAction(name: .PasteAndGoTitle, handler: { () -> Bool in
            if let pasteboardContents = UIPasteboard.general.string {
                self.urlBar(self.urlBar, didSubmitText: pasteboardContents)
                return true
            }
            return false
        })
        pasteAction = AccessibleAction(name: .PasteTitle, handler: { () -> Bool in
            if let pasteboardContents = UIPasteboard.general.string {
                // Enter overlay mode and make the search controller appear.
                self.overlayManager.openSearch(with: pasteboardContents)

                return true
            }
            return false
        })
        copyAddressAction = AccessibleAction(name: .CopyAddressTitle, handler: { () -> Bool in
            if let url = self.tabManager.selectedTab?.canonicalURL?.displayURL ?? self.urlBar.currentURL {
                UIPasteboard.general.url = url
            }
            return true
        })
    }

    private func setupNotifications() {
        notificationCenter.addObserver(
            self,
            selector: #selector(appWillResignActiveNotification),
            name: UIApplication.willResignActiveNotification,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidBecomeActiveNotification),
            name: UIApplication.didBecomeActiveNotification,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(appDidEnterBackgroundNotification),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(appMenuBadgeUpdate),
            name: .FirefoxAccountStateChange,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(searchBarPositionDidChange),
            name: .SearchBarPositionDidChange,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(didTapUndoCloseAllTabToast),
            name: .DidTapUndoCloseAllTabToast,
            object: nil)
        notificationCenter.addObserver(
            self,
            selector: #selector(didFinishAnnouncement),
            name: UIAccessibility.announcementDidFinishNotification,
            object: nil)
        notificationCenter.addObserver(self,
                                       selector: #selector(didAddPendingBlobDownloadToQueue),
                                       name: .PendingBlobDownloadAddedToQueue,
                                       object: nil)
    }

    func addSubviews() {
        webViewContainerBackdrop = UIView()
        webViewContainerBackdrop.backgroundColor = UIColor.Photon.Ink90
        webViewContainerBackdrop.alpha = 0
        view.addSubview(webViewContainerBackdrop)
        view.addSubview(contentStackView)

        contentStackView.addArrangedSubview(contentContainer)

        topTouchArea = UIButton()
        topTouchArea.isAccessibilityElement = false
        topTouchArea.addTarget(self, action: #selector(tappedTopArea), for: .touchUpInside)
        view.addSubview(topTouchArea)

        // Work around for covering the non-clipped web view content
        view.addSubview(statusBarOverlay)

        // Setup the URL bar, wrapped in a view to get transparency effect
        urlBar = URLBarView(profile: profile)
        urlBar.translatesAutoresizingMaskIntoConstraints = false
        urlBar.delegate = self
        urlBar.tabToolbarDelegate = self
        urlBar.applyTheme(theme: themeManager.currentTheme)
        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        urlBar.applyUIMode(isPrivate: isPrivate, theme: themeManager.currentTheme)

        urlBar.addToParent(parent: isBottomSearchBar ? overKeyboardContainer : header)
        view.addSubview(header)
        view.addSubview(bottomContentStackView)
        view.addSubview(overKeyboardContainer)

        toolbar = TabToolbar()
        bottomContainer.addArrangedSubview(toolbar)
        view.addSubview(bottomContainer)
    }

    // Configure dimming view to show for private mode
    func configureDimmingView() {
        if let selectedTab = tabManager.selectedTab, selectedTab.isPrivate {
            view.addSubview(privateModeDimmingView)
            view.bringSubviewToFront(privateModeDimmingView)

            NSLayoutConstraint.activate([
                privateModeDimmingView.topAnchor.constraint(equalTo: contentStackView.topAnchor),
                privateModeDimmingView.leadingAnchor.constraint(equalTo: contentStackView.leadingAnchor),
                privateModeDimmingView.bottomAnchor.constraint(equalTo: contentStackView.bottomAnchor),
                privateModeDimmingView.trailingAnchor.constraint(equalTo: contentStackView.trailingAnchor)
            ])
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if !displayedRestoreTabsAlert && crashedLastLaunch() {
            logger.log("The application crashed on last session",
                       level: .info,
                       category: .lifecycle)
            displayedRestoreTabsAlert = true
            showRestoreTabsAlert()
        } else {
            tabManager.restoreTabs()
        }

        updateTabCountUsingTabManager(tabManager, animated: false)

        urlBar.searchEnginesDidUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        screenshotHelper.viewIsVisible = true

        if let toast = self.pendingToast {
            self.pendingToast = nil
            show(toast: toast, afterWaiting: ButtonToast.UX.delay)
        }
        showQueuedAlertIfAvailable()

        prepareURLOnboardingContextualHint()

        browserDelegate?.browserHasLoaded()
    }

    private func prepareURLOnboardingContextualHint() {
        guard toolbarContextHintVC.shouldPresentHint(),
              featureFlags.isFeatureEnabled(.isToolbarCFREnabled, checking: .buildOnly)
        else { return }

        toolbarContextHintVC.configure(
            anchor: urlBar,
            withArrowDirection: isBottomSearchBar ? .down : .up,
            andDelegate: self,
            presentedUsing: { self.presentContextualHint() },
            andActionForButton: { self.homePanelDidRequestToOpenSettings(at: .toolbar) },
            overlayState: overlayManager)
    }

    private func presentContextualHint() {
        if IntroScreenManager(prefs: profile.prefs).shouldShowIntroScreen { return }
        present(toolbarContextHintVC, animated: true)

        UIAccessibility.post(notification: .layoutChanged, argument: toolbarContextHintVC)
    }

    override func viewWillDisappear(_ animated: Bool) {
        screenshotHelper.viewIsVisible = false
        super.viewWillDisappear(animated)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        statusBarOverlay.snp.remakeConstraints { make in
            make.top.left.right.equalTo(self.view)
            make.height.equalTo(self.view.safeAreaInsets.top)
        }

        showQueuedAlertIfAvailable()
    }

    override func willTransition(to newCollection: UITraitCollection, with coordinator: UIViewControllerTransitionCoordinator) {
        super.willTransition(to: newCollection, with: coordinator)

        // During split screen launching on iPad, this callback gets fired before viewDidLoad gets a chance to
        // set things up. Make sure to only update the toolbar state if the view is ready for it.
        if isViewLoaded {
            updateToolbarStateForTraitCollection(newCollection)
        }

        displayedPopoverController?.dismiss(animated: true, completion: nil)
        coordinator.animate(alongsideTransition: { context in
            self.scrollController.showToolbars(animated: false)
        }, completion: nil)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        dismissVisibleMenus()

        var fakespotNeedsUpdate = false
        if urlBar.currentURL != nil {
            fakespotNeedsUpdate = contentStackView.isSidebarVisible != FakespotUtils().shouldDisplayInSidebar(viewSize: size)
            if let fakespotState = browserViewControllerState?.fakespotState {
                fakespotNeedsUpdate = fakespotNeedsUpdate && fakespotState.isOpen
            }

            if fakespotNeedsUpdate {
                dismissFakespotIfNeeded(animated: false)
            }
        }

        coordinator.animate(alongsideTransition: { context in
            self.scrollController.updateMinimumZoom()
            self.topTabsViewController?.scrollToCurrentTab(false, centerCell: false)
            if let popover = self.displayedPopoverController {
                self.updateDisplayedPopoverProperties?()
                self.present(popover, animated: true, completion: nil)
            }

            if let productURL = self.urlBar.currentURL, fakespotNeedsUpdate {
                self.handleFakespotFlow(productURL: productURL)
            }
        }, completion: { _ in
            self.scrollController.setMinimumZoom()
        })
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            themeManager.systemThemeChanged()
            updateLegacyTheme()
        }
        setupMiddleButtonStatus(isLoading: false)
    }

    private func updateLegacyTheme() {
        if !NightModeHelper.isActivated() && LegacyThemeManager.instance.systemThemeIsOn {
            let userInterfaceStyle = traitCollection.userInterfaceStyle
            LegacyThemeManager.instance.current = userInterfaceStyle == .dark ? LegacyDarkTheme() : LegacyNormalTheme()
        }
    }

    // MARK: - Constraints

    private func setupConstraints() {
        urlBar.snp.makeConstraints { make in
            urlBarHeightConstraint = make.height.equalTo(UIConstants.TopToolbarHeightMax).constraint
        }

        webViewContainerBackdrop.snp.makeConstraints { make in
            make.edges.equalTo(view)
        }

        NSLayoutConstraint.activate([
            contentStackView.topAnchor.constraint(equalTo: header.bottomAnchor),
            contentStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentStackView.bottomAnchor.constraint(equalTo: overKeyboardContainer.topAnchor),
        ])

        updateHeaderConstraints()
    }

    private func updateHeaderConstraints() {
        header.snp.remakeConstraints { make in
            if isBottomSearchBar {
                make.left.right.equalTo(view)
                make.top.equalTo(view.safeArea.top)
                // The status bar is covered by the statusBarOverlay,
                // if we don't have the URL bar at the top then header height is 0
                make.height.equalTo(0)
            } else {
                scrollController.headerTopConstraint = make.top.equalTo(view.safeArea.top).constraint
                make.left.right.equalTo(view)
            }
        }
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()

        topTouchArea.snp.remakeConstraints { make in
            make.top.left.right.equalTo(view)
            make.height.equalTo(UX.ShowHeaderTapAreaHeight)
        }

        readerModeBar?.snp.remakeConstraints { make in
            make.height.equalTo(UIConstants.ToolbarHeight)
        }

        // Setup the bottom toolbar
        toolbar.snp.remakeConstraints { make in
            make.height.equalTo(UIConstants.BottomToolbarHeight)
        }

        overKeyboardContainer.snp.remakeConstraints { make in
            scrollController.overKeyboardContainerConstraint = make.bottom.equalTo(bottomContainer.snp.top).constraint
            if !isBottomSearchBar, zoomPageBar != nil {
                make.height.greaterThanOrEqualTo(0)
            } else if !isBottomSearchBar {
                make.height.equalTo(0)
            }
            make.leading.trailing.equalTo(view)
        }

        bottomContainer.snp.remakeConstraints { make in
            scrollController.bottomContainerConstraint = make.bottom.equalTo(view.snp.bottom).constraint
            make.leading.trailing.equalTo(view)
        }

        bottomContentStackView.snp.remakeConstraints { remake in
            adjustBottomContentStackView(remake)
        }

        adjustBottomSearchBarForKeyboard()
    }

    private func adjustBottomContentStackView(_ remake: ConstraintMaker) {
        remake.left.equalTo(view.safeArea.left)
        remake.right.equalTo(view.safeArea.right)
        remake.centerX.equalTo(view)
        remake.width.equalTo(view.safeArea.width)

        // Height is set by content - this removes run time error
        remake.height.greaterThanOrEqualTo(0)
        bottomContentStackView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        if isBottomSearchBar {
            adjustBottomContentBottomSearchBar(remake)
        } else {
            adjustBottomContentTopSearchBar(remake)
        }
    }

    private func adjustBottomContentTopSearchBar(_ remake: ConstraintMaker) {
        if let keyboardHeight = keyboardState?.intersectionHeightForView(view), keyboardHeight > 0 {
            remake.bottom.equalTo(view).offset(-keyboardHeight)
        } else if !toolbar.isHidden {
            remake.bottom.lessThanOrEqualTo(overKeyboardContainer.snp.top)
            remake.bottom.lessThanOrEqualTo(view.safeArea.bottom)
        } else {
            remake.bottom.equalTo(view.safeArea.bottom)
        }
    }

    private func adjustBottomContentBottomSearchBar(_ remake: ConstraintMaker) {
        remake.bottom.lessThanOrEqualTo(overKeyboardContainer.snp.top)
        remake.bottom.lessThanOrEqualTo(view.safeArea.bottom)
    }

    private func adjustBottomSearchBarForKeyboard() {
        guard isBottomSearchBar,
              let keyboardHeight = keyboardState?.intersectionHeightForView(view), keyboardHeight > 0
        else {
            overKeyboardContainer.removeKeyboardSpacer()
            return
        }

        let showToolBar = shouldShowToolbarForTraitCollection(traitCollection)
        let toolBarHeight = showToolBar ? UIConstants.BottomToolbarHeight : 0
        let spacerHeight = keyboardHeight - toolBarHeight
        overKeyboardContainer.addKeyboardSpacer(spacerHeight: spacerHeight)
    }

    // Because crashedLastLaunch is sticky, it does not get reset, we need to remember its
    // value so that we do not keep asking the user to restore their tabs.
    var displayedRestoreTabsAlert = false

    fileprivate func crashedLastLaunch() -> Bool {
        return logger.crashedLastLaunch
    }

    fileprivate func showRestoreTabsAlert() {
        let alert = UIAlertController.restoreTabsAlert(
            okayCallback: { _ in
                let extra = [TelemetryWrapper.EventExtraKey.isRestoreTabsStarted.rawValue: true]
                TelemetryWrapper.recordEvent(category: .action,
                                             method: .tap,
                                             object: .restoreTabsAlert,
                                             extras: extra)
                self.isCrashAlertShowing = false
                self.tabManager.restoreTabs(true)
            },
            noCallback: { _ in
                let extra = [TelemetryWrapper.EventExtraKey.isRestoreTabsStarted.rawValue: false]
                TelemetryWrapper.recordEvent(category: .action,
                                             method: .tap,
                                             object: .restoreTabsAlert,
                                             extras: extra)
                self.isCrashAlertShowing = false
                self.tabManager.selectTab(self.tabManager.addTab())
                self.openUrlAfterRestore()
                AppEventQueue.signal(event: .tabRestoration(self.tabManager.windowUUID))
            }
        )
        self.present(alert, animated: true, completion: nil)
        isCrashAlertShowing = true
    }

    fileprivate func showQueuedAlertIfAvailable() {
        if let queuedAlertInfo = tabManager.selectedTab?.dequeueJavascriptAlertPrompt() {
            let alertController = queuedAlertInfo.alertController()
            alertController.delegate = self
            present(alertController, animated: true, completion: nil)
        }
    }

    private func updateWallpaperMetadata() {
        let metadataQueue = DispatchQueue(label: "com.moz.wallpaperVerification.queue")
        metadataQueue.async {
            let wallpaperManager = WallpaperManager()
            wallpaperManager.checkForUpdates()
        }
    }

    func resetBrowserChrome() {
        // animate and reset transform for tab chrome
        urlBar.updateAlphaForSubviews(1)
        toolbar.isHidden = false

        [header, overKeyboardContainer].forEach { view in
            view?.transform = .identity
        }
    }

    // MARK: - Manage embedded content

    func frontEmbeddedContent(_ viewController: ContentContainable) {
        contentContainer.update(content: viewController)
        statusBarOverlay.resetState(isHomepage: contentContainer.hasHomepage)
    }

    /// Embed a ContentContainable inside the content container
    /// - Parameter viewController: the view controller to embed inside the content container
    /// - Returns: True when the content was successfully embedded
    func embedContent(_ viewController: ContentContainable) -> Bool {
        guard contentContainer.canAdd(content: viewController) else { return false }

        addChild(viewController)
        contentContainer.add(content: viewController)
        viewController.didMove(toParent: self)
        statusBarOverlay.resetState(isHomepage: contentContainer.hasHomepage)

        UIAccessibility.post(notification: UIAccessibility.Notification.screenChanged, argument: nil)
        return true
    }

    /// Show the home page embedded in the contentContainer
    /// - Parameter inline: Inline is true when the homepage is created from the tab tray, a long press
    /// on the tab bar to open a new tab or by pressing the home page button on the tab bar. Inline is false when
    /// it's the zero search page, aka when the home page is shown by clicking the url bar from a loaded web page.
    func showEmbeddedHomepage(inline: Bool) {
        guard let isPrivate = browserViewControllerState?.usePrivateHomepage, !isPrivate else {
            browserDelegate?.showPrivateHomepage(overlayManager: overlayManager)
            return
        }

        hideReaderModeBar(animated: false)

        // Make sure reload button is hidden on homepage
        urlBar.locationView.reloadButton.reloadButtonState = .disabled

        browserDelegate?.showHomepage(inline: inline,
                                      toastContainer: contentContainer,
                                      homepanelDelegate: self,
                                      libraryPanelDelegate: self,
                                      statusBarScrollDelegate: statusBarOverlay,
                                      overlayManager: overlayManager)
    }

    func showEmbeddedWebview() {
        // Make sure reload button is working when showing webview
        urlBar.locationView.reloadButton.reloadButtonState = .reload

        guard let webview = tabManager.selectedTab?.webView else {
            logger.log("Webview of selected tab was not available", level: .debug, category: .lifecycle)
            return
        }

        browserDelegate?.show(webView: webview)
    }

    // MARK: - Update content

    func updateInContentHomePanel(_ url: URL?, focusUrlBar: Bool = false) {
        let isAboutHomeURL = url.flatMap { InternalURL($0)?.isAboutHomeURL } ?? false
        guard let url = url else {
            showEmbeddedWebview()
            urlBar.locationView.reloadButton.reloadButtonState = .disabled
            return
        }

        if isAboutHomeURL {
            showEmbeddedHomepage(inline: true)

            if userHasPressedHomeButton {
                userHasPressedHomeButton = false
            }
        } else if !url.absoluteString.hasPrefix("\(InternalURL.baseUrl)/\(SessionRestoreHandler.path)") {
            showEmbeddedWebview()
            urlBar.shouldHideReloadButton(shouldUseiPadSetup())
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            topTabsViewController?.refreshTabs()
        }
    }

    func showLibrary(panel: LibraryPanelType) {
        DispatchQueue.main.async {
            self.navigationHandler?.show(homepanelSection: panel.homepanelSection)
        }
    }

    fileprivate func createSearchControllerIfNeeded() {
        guard self.searchController == nil else { return }

        let isPrivate = tabManager.selectedTab?.isPrivate ?? false
        let searchViewModel = SearchViewModel(isPrivate: isPrivate, isBottomSearchBar: isBottomSearchBar)
        let searchController = SearchViewController(profile: profile,
                                                    viewModel: searchViewModel,
                                                    model: profile.searchEngines,
                                                    tabManager: tabManager)
        searchController.searchEngines = profile.searchEngines
        searchController.searchDelegate = self

        let searchLoader = SearchLoader(profile: profile, urlBar: urlBar)
        searchLoader.addListener(searchController)

        self.searchController = searchController
        self.searchLoader = searchLoader
    }

    func showSearchController() {
        createSearchControllerIfNeeded()

        guard let searchController = self.searchController else { return }

        // This needs to be added to ensure during animation of the keyboard,
        // No content is showing in between the bottom search bar and the searchViewController
        if isBottomSearchBar, keyboardBackdrop == nil {
            keyboardBackdrop = UIView()
            keyboardBackdrop?.backgroundColor = themeManager.currentTheme.colors.layer1
            view.insertSubview(keyboardBackdrop!, belowSubview: overKeyboardContainer)
            keyboardBackdrop?.snp.makeConstraints { make in
                make.edges.equalTo(view)
            }
            view.bringSubviewToFront(bottomContainer)
        }

        addChild(searchController)
        view.addSubview(searchController.view)
        searchController.view.translatesAutoresizingMaskIntoConstraints = false

        let constraintTarget = isBottomSearchBar ? overKeyboardContainer.topAnchor : view.bottomAnchor
        NSLayoutConstraint.activate([
            searchController.view.topAnchor.constraint(equalTo: header.bottomAnchor),
            searchController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            searchController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            searchController.view.bottomAnchor.constraint(equalTo: constraintTarget)
        ])

        searchController.didMove(toParent: self)
    }

    func hideSearchController() {
        privateModeDimmingView.removeFromSuperview()
        guard let searchController = self.searchController else { return }
        searchController.willMove(toParent: nil)
        searchController.view.removeFromSuperview()
        searchController.removeFromParent()

        keyboardBackdrop?.removeFromSuperview()
        keyboardBackdrop = nil
    }

    func destroySearchController() {
        hideSearchController()

        searchController = nil
        searchLoader = nil
    }

    func finishEditingAndSubmit(_ url: URL, visitType: VisitType, forTab tab: Tab) {
        urlBar.currentURL = url
        overlayManager.finishEditing(shouldCancelLoading: false)

        if let nav = tab.loadRequest(URLRequest(url: url)) {
            self.recordNavigationInTab(tab, navigation: nav, visitType: visitType)
        }
    }

    func addBookmark(url: String, title: String? = nil) {
        var title = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty {
            title = url
        }

        let shareItem = ShareItem(url: url, title: title)
        // Add new mobile bookmark at the top of the list
        profile.places.createBookmark(parentGUID: BookmarkRoots.MobileFolderGUID,
                                      url: shareItem.url,
                                      title: shareItem.title,
                                      position: 0)

        var userData = [QuickActionInfos.tabURLKey: shareItem.url]
        if let title = shareItem.title {
            userData[QuickActionInfos.tabTitleKey] = title
        }
        QuickActionsImplementation().addDynamicApplicationShortcutItemOfType(.openLastBookmark,
                                                                             withUserData: userData,
                                                                             toApplication: .shared)

        showBookmarksToast()
    }

    private func showBookmarksToast() {
        let viewModel = ButtonToastViewModel(labelText: .AppMenu.AddBookmarkConfirmMessage,
                                             buttonText: .BookmarksEdit,
                                             textAlignment: .left)
        let toast = ButtonToast(viewModel: viewModel,
                                theme: themeManager.currentTheme) { isButtonTapped in
            isButtonTapped ? self.openBookmarkEditPanel() : nil
        }
        self.show(toast: toast)
    }

    func removeBookmark(url: String) {
        profile.places.deleteBookmarksWithURL(url: url).uponQueue(.main) { result in
            guard result.isSuccess else { return }
            self.showToast(message: .AppMenu.RemoveBookmarkConfirmMessage, toastAction: .removeBookmark)
        }
    }

    /// This function will open a view separate from the bookmark edit panel found in the
    /// Library Panel - Bookmarks section. In order to get the correct information, it needs
    /// to fetch the last added bookmark in the mobile folder, which is the default
    /// location for all bookmarks added on mobile.
    private func openBookmarkEditPanel() {
        TelemetryWrapper.recordEvent(category: .action, method: .change, object: .bookmark, value: .addBookmarkToast)
        if profile.isShutdown { return }
        profile.places.getBookmarksTree(rootGUID: BookmarkRoots.MobileFolderGUID, recursive: false).uponQueue(.main) { result in
            guard let bookmarkFolder = result.successValue as? BookmarkFolderData,
                  let bookmarkNode = bookmarkFolder.children?.first as? FxBookmarkNode
            else { return }

            let detailController = BookmarkDetailPanel(profile: self.profile,
                                                       bookmarkNode: bookmarkNode,
                                                       parentBookmarkFolder: bookmarkFolder,
                                                       presentedFromToast: true)
            let controller: DismissableNavigationViewController
            controller = DismissableNavigationViewController(rootViewController: detailController)
            self.present(controller, animated: true, completion: nil)
        }
    }

    override func accessibilityPerformEscape() -> Bool {
        if overlayManager.inOverlayMode {
            overlayManager.finishEditing(shouldCancelLoading: true)
            return true
        } else if let selectedTab = tabManager.selectedTab, selectedTab.canGoBack {
            selectedTab.goBack()
            return true
        }
        return false
    }

    func setupLoadingSpinnerFor(_ webView: WKWebView, isLoading: Bool) {
        if isLoading {
            webView.scrollView.refreshControl?.beginRefreshing()
        } else {
            webView.scrollView.refreshControl?.endRefreshing()
        }
    }

    func setupMiddleButtonStatus(isLoading: Bool) {
        // Setting the default state to search to account for no tab or starting page tab
        // `state` will be modified later if needed
        var state: MiddleButtonState = .search

        // No tab
        guard let tab = tabManager.selectedTab else {
            urlBar.locationView.reloadButton.reloadButtonState = .disabled
            navigationToolbar.updateMiddleButtonState(state)
            currentMiddleButtonState = state
            return
        }

        // Tab with starting page
        if tab.isURLStartingPage {
            urlBar.locationView.reloadButton.reloadButtonState = .disabled
            navigationToolbar.updateMiddleButtonState(state)
            currentMiddleButtonState = state
            return
        }

        if traitCollection.horizontalSizeClass == .compact {
            state = .home
        } else {
            state = isLoading ? .stop : .reload
        }

        navigationToolbar.updateMiddleButtonState(state)
        if !toolbar.isHidden {
            urlBar.locationView.reloadButton.reloadButtonState = isLoading ? .stop : .reload
        }
        currentMiddleButtonState = state
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let webView = object as? WKWebView,
              let tab = tabManager[webView]
        else { return }

        guard let kp = keyPath,
              let path = KVOConstants(rawValue: kp)
        else {
            logger.log("BVC observeValue webpage unhandled KVO",
                       level: .info,
                       category: .unlabeled,
                       description: "Unhandled KVO key: \(keyPath ?? "nil")")
            return
        }

        switch path {
        case .estimatedProgress:
            guard tab === tabManager.selectedTab else { break }
            if let url = webView.url, !InternalURL.isValid(url: url) {
                urlBar.updateProgressBar(Float(webView.estimatedProgress))
                setupMiddleButtonStatus(isLoading: true)
            } else {
                urlBar.hideProgressBar()
                setupMiddleButtonStatus(isLoading: false)
            }
        case .loading:
            guard let loading = change?[.newKey] as? Bool else { break }
            setupMiddleButtonStatus(isLoading: loading)
            setupLoadingSpinnerFor(webView, isLoading: loading)

        case .URL:
            // Special case for "about:blank" popups, if the webView.url is nil, keep the tab url as "about:blank"
            if tab.url?.absoluteString == "about:blank" && webView.url == nil {
                break
            }

            // To prevent spoofing, only change the URL immediately if the new URL is on
            // the same origin as the current URL. Otherwise, do nothing and wait for
            // didCommitNavigation to confirm the page load.
            if tab.url?.origin == webView.url?.origin {
                tab.url = webView.url

                if tab === tabManager.selectedTab {
                    updateUIForReaderHomeStateForTab(tab)
                }
                // Catch history pushState navigation, but ONLY for same origin navigation,
                // for reasons above about URL spoofing risk.
                navigateInTab(tab: tab, webViewStatus: .url)
            }
        case .title:
            // Ensure that the tab title *actually* changed to prevent repeated calls
            // to navigateInTab(tab:).
            guard let title = tab.title else { break }
            if !title.isEmpty && title != tab.lastTitle {
                tab.lastTitle = title
                navigateInTab(tab: tab, webViewStatus: .title)
            }
            TelemetryWrapper.recordEvent(category: .action, method: .navigate, object: .tab)
        case .canGoBack:
            guard tab === tabManager.selectedTab,
                  let canGoBack = change?[.newKey] as? Bool
            else { break }
            navigationToolbar.updateBackStatus(canGoBack)
        case .canGoForward:
            guard tab === tabManager.selectedTab,
                  let canGoForward = change?[.newKey] as? Bool
            else { break }
            navigationToolbar.updateForwardStatus(canGoForward)
        default:
            assertionFailure("Unhandled KVO key: \(keyPath ?? "nil")")
        }
    }

    func updateUIForReaderHomeStateForTab(_ tab: Tab, focusUrlBar: Bool = false) {
        updateURLBarDisplayURL(tab)

        if let url = tab.url {
            if url.isReaderModeURL {
                showReaderModeBar(animated: false)
            } else {
                hideReaderModeBar(animated: false)
            }

            updateInContentHomePanel(url as URL, focusUrlBar: focusUrlBar)
        }
    }

    /// Updates the URL bar text and button states.
    /// Call this whenever the page URL changes.
    fileprivate func updateURLBarDisplayURL(_ tab: Tab) {
        if tab == tabManager.selectedTab, let displayUrl = tab.url?.displayURL, urlBar.currentURL != displayUrl {
            let searchData = tab.metadataManager?.tabGroupData ?? LegacyTabGroupData()
            searchData.tabAssociatedNextUrl = displayUrl.absoluteString
            tab.metadataManager?.updateTimerAndObserving(
                state: .tabNavigatedToDifferentUrl,
                searchData: searchData,
                isPrivate: tab.isPrivate)
        }
        urlBar.currentURL = tab.url?.displayURL
        urlBar.locationView.tabDidChangeContentBlocking(tab)
        urlBar.locationView.updateShoppingButtonVisibility(for: tab)
        let isPage = tab.url?.displayURL?.isWebPage() ?? false
        navigationToolbar.updatePageStatus(isPage)
    }

    // MARK: Opening New Tabs

    /// ⚠️ !! WARNING !! ⚠️
    /// This function opens up x number of new tabs in the background.
    /// This is meant to test memory overflows with tabs on a device.
    /// DO NOT USE unless you're explicitly testing this feature.
    /// It should only be used from the debug menu.
    func debugOpen(numberOfNewTabs: Int?, at url: URL) {
        guard let numberOfNewTabs = numberOfNewTabs,
              numberOfNewTabs > 0
        else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(500), execute: {
            self.tabManager.addTab(URLRequest(url: url))
            self.debugOpen(numberOfNewTabs: numberOfNewTabs - 1, at: url)
        })
    }

    func presentSignInViewController(_ fxaOptions: FxALaunchParams,
                                     flowType: FxAPageType = .emailLoginFlow,
                                     referringPage: ReferringPage = .none) {
        let vcToPresent = FirefoxAccountSignInViewController.getSignInOrFxASettingsVC(fxaOptions,
                                                                                      flowType: flowType,
                                                                                      referringPage: referringPage,
                                                                                      profile: profile)
        (vcToPresent as? FirefoxAccountSignInViewController)?.qrCodeNavigationHandler = navigationHandler
        presentThemedViewController(navItemLocation: .Left,
                                    navItemText: .Close,
                                    vcBeingPresented: vcToPresent,
                                    topTabsVisible: UIDevice.current.userInterfaceIdiom == .pad)
    }

    func handle(query: String) {
       openBlankNewTab(focusLocationField: false)
       urlBar(urlBar, didSubmitText: query)
    }

    func handle(url: URL?, isPrivate: Bool, options: Set<Route.SearchOptions>? = nil) {
        if let url = url {
            if options?.contains(.switchToNormalMode) == true {
                switchToPrivacyMode(isPrivate: false)
            }
            switchToTabForURLOrOpen(url, isPrivate: isPrivate)
        } else {
            openBlankNewTab(focusLocationField: options?.contains(.focusLocationField) == true, isPrivate: isPrivate)
        }
    }

    func handle(url: URL?, tabId: String, isPrivate: Bool = false) {
        if let url = url {
            switchToTabForURLOrOpen(url, uuid: tabId, isPrivate: isPrivate)
        } else {
            openBlankNewTab(focusLocationField: true, isPrivate: isPrivate)
        }
    }

    func handleQRCode() {
        if CoordinatorFlagManager.isQRCodeCoordinatorEnabled {
            navigationHandler?.showQRCode(delegate: self)
        } else {
            let qrCodeViewController = QRCodeViewController()
            qrCodeViewController.qrCodeDelegate = self
            presentedViewController?.dismiss(animated: true)
            present(UINavigationController(rootViewController: qrCodeViewController), animated: true, completion: nil)
        }
    }

    func handleClosePrivateTabs() {
        tabManager.removeTabs(tabManager.privateTabs)
        guard let tab = mostRecentTab(inTabs: tabManager.normalTabs) else {
            tabManager.selectTab(tabManager.addTab())
            return
        }
        tabManager.selectTab(tab)
    }

    func switchToPrivacyMode(isPrivate: Bool) {
        if let tabTrayController = self.gridTabTrayController, tabTrayController.tabDisplayManager.isPrivate != isPrivate {
            tabTrayController.didTogglePrivateMode(isPrivate)
        }
        topTabsViewController?.applyUIMode(isPrivate: isPrivate, theme: themeManager.currentTheme)
    }

    func switchToTabForURLOrOpen(_ url: URL, uuid: String? = nil, isPrivate: Bool = false) {
        guard !isCrashAlertShowing else {
            urlFromAnotherApp = UrlToOpenModel(url: url, isPrivate: isPrivate)
            return
        }
        popToBVC()
        guard !isShowingJSPromptAlert() else {
            tabManager.addTab(URLRequest(url: url), isPrivate: isPrivate)
            return
        }
        openedUrlFromExternalSource = true

        if let uuid = uuid, let tab = tabManager.getTabForUUID(uuid: uuid) {
            tabManager.selectTab(tab)
        } else if let tab = tabManager.getTabForURL(url) {
            tabManager.selectTab(tab)
        } else {
            openURLInNewTab(url, isPrivate: isPrivate)
        }
    }

    @discardableResult
    func openURLInNewTab(_ url: URL?, isPrivate: Bool = false) -> Tab {
        if let selectedTab = tabManager.selectedTab {
            screenshotHelper.takeScreenshot(selectedTab)
        }
        let request: URLRequest?
        if let url = url {
            request = URLRequest(url: url)
        } else {
            request = nil
        }

        switchToPrivacyMode(isPrivate: isPrivate)
        let tab = tabManager.addTab(request, isPrivate: isPrivate)
        tabManager.selectTab(tab)
        return tab
    }

    func focusLocationTextField(forTab tab: Tab?, setSearchText searchText: String? = nil) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            // Without a delay, the text field fails to become first responder
            // Check that the newly created tab is still selected.
            // This let's the user spam the Cmd+T button without lots of responder changes.
            guard tab == self.tabManager.selectedTab else { return }

            self.urlBar.tabLocationViewDidTapLocation(self.urlBar.locationView)
            if let text = searchText {
                self.urlBar.setLocation(text, search: true)
            }
        }
    }

    func openNewTabFromMenu(focusLocationField: Bool, isPrivate: Bool) {
        overlayManager.openNewTab(url: nil, newTabSettings: newTabSettings)
        openBlankNewTab(focusLocationField: focusLocationField, isPrivate: isPrivate)
    }

    func openBlankNewTab(focusLocationField: Bool, isPrivate: Bool = false, searchFor searchText: String? = nil) {
        popToBVC()
        guard !isShowingJSPromptAlert() else {
            tabManager.addTab(nil, isPrivate: isPrivate)
            return
        }
        openedUrlFromExternalSource = true

        let freshTab = openURLInNewTab(nil, isPrivate: isPrivate)
        freshTab.metadataManager?.updateTimerAndObserving(state: .newTab, isPrivate: freshTab.isPrivate)
        if focusLocationField {
            focusLocationTextField(forTab: freshTab, setSearchText: searchText)
        }
    }

    func openSearchNewTab(isPrivate: Bool = false, _ text: String) {
        popToBVC()

        guard let engine = profile.searchEngines.defaultEngine,
              let searchURL = engine.searchURLForQuery(text)
        else {
            DefaultLogger.shared.log("Error handling URL entry: \"\(text)\".", level: .warning, category: .tabs)
            return
        }

        openURLInNewTab(searchURL, isPrivate: isPrivate)

        if let tab = tabManager.selectedTab {
            let searchData = LegacyTabGroupData(searchTerm: text,
                                                searchUrl: searchURL.absoluteString,
                                                nextReferralUrl: "")
            tab.metadataManager?.updateTimerAndObserving(state: .navSearchLoaded, searchData: searchData, isPrivate: tab.isPrivate)
        }
    }

    fileprivate func popToBVC() {
        guard let currentViewController = navigationController?.topViewController else { return }
        // Avoid dismissing JSPromptAlert that causes the crash because completionHandler was not called
        if !isShowingJSPromptAlert() {
            currentViewController.dismiss(animated: true, completion: nil)
        }

        if currentViewController != self {
            _ = self.navigationController?.popViewController(animated: true)
        }
    }

    private func isShowingJSPromptAlert() -> Bool {
        return navigationController?.topViewController?.presentedViewController as? JSPromptAlertController != nil
    }

    fileprivate func postLocationChangeNotificationForTab(_ tab: Tab, navigation: WKNavigation?) {
        let notificationCenter = NotificationCenter.default
        var info = [AnyHashable: Any]()
        info["url"] = tab.url?.displayURL
        info["title"] = tab.title
        if let visitType = self.getVisitTypeForTab(tab, navigation: navigation)?.rawValue {
            info["visitType"] = visitType
        }
        info["isPrivate"] = tab.isPrivate
        notificationCenter.post(name: .OnLocationChange, object: self, userInfo: info)
    }

    /// Enum to represent the WebView observation or delegate that triggered calling `navigateInTab`
    enum WebViewUpdateStatus {
        case title
        case url
        case finishedNavigation
    }

    func navigateInTab(tab: Tab, to navigation: WKNavigation? = nil, webViewStatus: WebViewUpdateStatus) {
        tabManager.expireSnackbars()

        guard let webView = tab.webView else { return }

        if let url = webView.url {
            if tab === tabManager.selectedTab {
                urlBar.locationView.tabDidChangeContentBlocking(tab)
            }

            if (!InternalURL.isValid(url: url) || url.isReaderModeURL) && !url.isFileURL {
                postLocationChangeNotificationForTab(tab, navigation: navigation)
                tab.readabilityResult = nil
                webView.evaluateJavascriptInDefaultContentWorld("\(ReaderModeNamespace).checkReadability()")
            }

            // Update Fakespot sidebar if necessary
            if webViewStatus == .url {
                updateFakespot(tab: tab)
            }

            TabEvent.post(.didChangeURL(url), for: tab)
        }

        // Represents WebView observation or delegate update that called this function

        if webViewStatus == .finishedNavigation {
            // A delay of 500 milliseconds is added when we take screenshot
            // as we don't know exactly when wkwebview is rendered
            let delayedTimeInterval = DispatchTimeInterval.milliseconds(500)

            if tab !== tabManager.selectedTab, let webView = tab.webView {
                // To Screenshot a tab that is hidden we must add the webView,
                // then wait enough time for the webview to render.
                webView.frame = contentContainer.frame
                view.insertSubview(webView, at: 0)
                // This is kind of a hacky fix for Bug 1476637 to prevent webpages from focusing the
                // touch-screen keyboard from the background even though they shouldn't be able to.
                webView.resignFirstResponder()

                // We need a better way of identifying when webviews are finished rendering
                // There are cases in which the page will still show a loading animation or nothing when the screenshot is being taken,
                // depending on internet connection
                // Issue created: https://github.com/mozilla-mobile/firefox-ios/issues/7003
                DispatchQueue.main.asyncAfter(deadline: .now() + delayedTimeInterval) {
                    self.screenshotHelper.takeScreenshot(tab)
                    if webView.superview == self.view {
                        webView.removeFromSuperview()
                    }
                }
            } else if tab.webView != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + delayedTimeInterval) {
                    self.screenshotHelper.takeScreenshot(tab)
                }
            }
        }
    }

    internal func updateFakespot(tab: Tab) {
        guard let webView = tab.webView, let url = webView.url else {
            // We're on homepage or a blank tab
            store.dispatch(FakespotAction.setAppearanceTo(false))
            return
        }

        let environment = featureFlags.isCoreFeatureEnabled(.useStagingFakespotAPI) ? FakespotEnvironment.staging : .prod
        let product = ShoppingProduct(url: url, client: FakespotClient(environment: environment))

        guard product.product != nil, !tab.isPrivate else {
            store.dispatch(FakespotAction.setAppearanceTo(false))

            // Quick fix: make sure to sidebar is hidden when opened from deep-link
            // Relates to FXIOS-7844
            contentStackView.hideSidebar(self)
            return
        }

        if contentStackView.isSidebarVisible {
            // Sidebar is visible, update content
            navigationHandler?.updateFakespotSidebar(productURL: url,
                                                     sidebarContainer: contentStackView,
                                                     parentViewController: self)
        } else if FakespotUtils().shouldDisplayInSidebar(),
                  let fakespotState = browserViewControllerState?.fakespotState,
                  fakespotState.isOpen {
            // Sidebar should be displayed and Fakespot is open, display Fakespot
            handleFakespotFlow(productURL: url)
        } else if let fakespotState = browserViewControllerState?.fakespotState,
                  fakespotState.sidebarOpenForiPadLandscape {
            // Sidebar should be displayed, display Fakespot
            store.dispatch(FakespotAction.setAppearanceTo(true))
        }
    }

    // MARK: Autofill

    private func creditCardInitialSetupTelemetry() {
        // Credit card autofill status telemetry
        let userDefaults = UserDefaults.standard
        let key = PrefsKeys.KeyAutofillCreditCardStatus
        // Default value is true for autofill credit card input
        let autofillStatus = userDefaults.value(forKey: key) as? Bool ?? true
        TelemetryWrapper.recordEvent(
            category: .information,
            method: .settings,
            object: .creditCardAutofillEnabled,
            extras: [
                TelemetryWrapper.ExtraKey.isCreditCardAutofillEnabled.rawValue: autofillStatus
            ]
        )

        // Credit card sync telemetry
        self.profile.hasSyncAccount { [unowned self] hasSync in
            logger.log("User has sync account setup \(hasSync)",
                       level: .debug,
                       category: .setup)

            guard hasSync else { return }
            let syncStatus = self.profile.syncManager.checkCreditCardEngineEnablement()
            TelemetryWrapper.recordEvent(
                category: .information,
                method: .settings,
                object: .creditCardSyncEnabled,
                extras: [
                    TelemetryWrapper.ExtraKey.isCreditCardSyncEnabled.rawValue: syncStatus
                ]
            )
        }
    }

    private func creditCardAutofillSetup(_ tab: Tab, didCreateWebView webView: WKWebView) {
        let userDefaults = UserDefaults.standard
        let keyCreditCardAutofill = PrefsKeys.KeyAutofillCreditCardStatus

        let autofillCreditCardStatus = featureFlags.isFeatureEnabled(
            .creditCardAutofillStatus, checking: .buildOnly)
        let formAutofillHelper = FormAutofillHelper(tab: tab)
        tab.addContentScript(formAutofillHelper, name: FormAutofillHelper.name())
        formAutofillHelper.foundFieldValues = { [weak self] fieldValues, type, frame in
            guard let tabWebView = tab.webView,
                  let type = type,
                  userDefaults.object(forKey: keyCreditCardAutofill) as? Bool ?? true
            else { return }

            // FXIOS-7150: Telemetry for form input regardless of feature flag status
            if type == .formInput {
                TelemetryWrapper.recordEvent(category: .action,
                                             method: .tap,
                                             object: .creditCardFormDetected)
            }

            // Perform autofill operations based on feature flag status
            guard autofillCreditCardStatus else { return }
            switch type {
            case .formInput:
                self?.profile.autofill.listCreditCards(completion: { cards, error in
                    guard let cards = cards, !cards.isEmpty, error == nil else { return }
                    DispatchQueue.main.async {
                        tabWebView.accessoryView.reloadViewFor(.creditCard)
                        tabWebView.reloadInputViews()
                    }
                })
            case .formSubmit:
                self?.showCreditCardAutofillSheet(fieldValues: fieldValues)
                break
            case .fillAddressForm:
                // TODO: FXIOS-7670 Address Autofill UX
                return
            case .captureAddressForm:
                // TODO: FXIOS-7670 Address Autofill UX
                return
            }

            tabWebView.accessoryView.savedCardsClosure = {
                DispatchQueue.main.async { [weak self] in
                    // Dismiss keyboard
                    webView.resignFirstResponder()
                    // Authenticate and show bottom sheet with select a card flow
                    self?.authenticateSelectCreditCardBottomSheet(fieldValues: fieldValues,
                                                                  frame: frame)
                }
            }
        }
    }

    private func authenticateSelectCreditCardBottomSheet(fieldValues: UnencryptedCreditCardFields,
                                                         frame: WKFrameInfo? = nil) {
        appAuthenticator.getAuthenticationState { [unowned self] state in
            switch state {
            case .deviceOwnerAuthenticated:
                // Note: Since we are injecting card info, we pass on the frame
                // for special iframe cases
                self.navigationHandler?.showCreditCardAutofill(creditCard: nil,
                                                               decryptedCard: nil,
                                                               viewType: .selectSavedCard,
                                                               frame: frame,
                                                               alertContainer: self.contentContainer)
            case .deviceOwnerFailed:
                break // Keep showing bvc
            case .passCodeRequired:
                self.navigationHandler?.showRequiredPassCode()
            }
        }
    }

    func showCreditCardAutofillSheet(fieldValues: UnencryptedCreditCardFields) {
        self.profile.autofill.checkForCreditCardExistance(cardNumber: fieldValues.ccNumberLast4) { existingCard, error in
            guard let existingCard = existingCard else {
                DispatchQueue.main.async {
                    self.navigationHandler?.showCreditCardAutofill(creditCard: nil,
                                                                   decryptedCard: fieldValues,
                                                                   viewType: .save,
                                                                   frame: nil,
                                                                   alertContainer: self.contentContainer)
                }
                return
            }

            // card already saved should update if any of its other values are different
            if !fieldValues.isEqualToCreditCard(creditCard: existingCard) {
                DispatchQueue.main.async {
                    self.navigationHandler?.showCreditCardAutofill(creditCard: existingCard,
                                                                   decryptedCard: fieldValues,
                                                                   viewType: .update,
                                                                   frame: nil,
                                                                   alertContainer: self.contentContainer)
                }
            }
        }
    }

    // MARK: Themeable
    func applyTheme() {
        let currentTheme = themeManager.currentTheme
        statusBarOverlay.hasTopTabs = shouldShowTopTabsForTraitCollection(traitCollection)
        keyboardBackdrop?.backgroundColor = currentTheme.colors.layer1
        setNeedsStatusBarAppearanceUpdate()

        // Update the `background-color` of any blank webviews.
        let webViews = tabManager.tabs.compactMap({ $0.webView })
        webViews.forEach({ $0.applyTheme(theme: currentTheme) })

        let tabs = tabManager.tabs
        tabs.forEach {
            $0.applyTheme(theme: currentTheme)
        }

        guard let contentScript = tabManager.selectedTab?.getContentScript(name: ReaderMode.name()) else { return }
        applyThemeForPreferences(profile.prefs, contentScript: contentScript)
    }

    // MARK: - LibraryPanelDelegate

    func libraryPanel(didSelectURL url: URL, visitType: VisitType) {
        guard let tab = tabManager.selectedTab else { return }

        // Handle keyboard shortcuts from homepage with url selection (ex: Cmd + Tap on Link; which is a cell in this case)
        if navigateLinkShortcutIfNeeded(url: url) {
            return
        }

        finishEditingAndSubmit(url, visitType: visitType, forTab: tab)
    }

    func libraryPanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool) {
        let tab = self.tabManager.addTab(URLRequest(url: url), afterTab: self.tabManager.selectedTab, isPrivate: isPrivate)
        // If we are showing toptabs a user can just use the top tab bar
        // If in overlay mode switching doesnt correctly dismiss the homepanels
        guard !topTabsVisible, !self.urlBar.inOverlayMode else { return }
        // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
        let viewModel = ButtonToastViewModel(labelText: .ContextMenuButtonToastNewTabOpenedLabelText,
                                             buttonText: .ContextMenuButtonToastNewTabOpenedButtonText)
        let toast = ButtonToast(viewModel: viewModel,
                                theme: themeManager.currentTheme,
                                completion: { buttonPressed in
            if buttonPressed {
                self.tabManager.selectTab(tab)
            }
        })
        self.show(toast: toast)
    }

    // MARK: - RecentlyClosedPanelDelegate

    func openRecentlyClosedSiteInSameTab(_ url: URL) {
        tabTrayOpenRecentlyClosedTab(url)
    }

    func openRecentlyClosedSiteInNewTab(_ url: URL, isPrivate: Bool) {
        tabManager.selectTab(tabManager.addTab(URLRequest(url: url)))
    }

    // MARK: - QRCodeViewControllerDelegate

    func didScanQRCodeWithURL(_ url: URL) {
        guard let tab = tabManager.selectedTab else { return }
        finishEditingAndSubmit(url, visitType: VisitType.typed, forTab: tab)
        TelemetryWrapper.recordEvent(category: .action, method: .scan, object: .qrCodeURL)
    }

    func didScanQRCodeWithText(_ text: String) {
        TelemetryWrapper.recordEvent(category: .action, method: .scan, object: .qrCodeText)
        let defaultAction: () -> Void = { [weak self] in
            guard let tab = self?.tabManager.selectedTab else { return }
            self?.submitSearchText(text, forTab: tab)
        }
        let content = TextContentDetector.detectTextContent(text)
        switch content {
        case .some(.link(let url)):
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        case .some(.phoneNumber(let phoneNumber)):
            if let url = URL(string: "tel:\(phoneNumber)", invalidCharacters: false) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            } else {
                defaultAction()
            }
        default:
            defaultAction()
        }
    }
}

extension BrowserViewController: ClipboardBarDisplayHandlerDelegate {
    func shouldDisplay(clipBoardURL url: URL) {
        let viewModel = ButtonToastViewModel(labelText: .GoToCopiedLink,
                                             descriptionText: url.absoluteDisplayString,
                                             buttonText: .GoButtonTittle)
        let toast = ButtonToast(viewModel: viewModel,
                                theme: themeManager.currentTheme,
                                completion: { [weak self] buttonPressed in
            if buttonPressed {
                let isPrivate = self?.tabManager.selectedTab?.isPrivate ?? false
                self?.openURLInNewTab(url, isPrivate: isPrivate)
            }
        })
        clipboardBarDisplayHandler?.clipboardToast = toast
        show(toast: toast, duration: ClipboardBarDisplayHandler.UX.toastDelay)
    }
}

/**
 * History visit management.
 * TODO: this should be expanded to track various visit types; see Bug 1166084.
 */
extension BrowserViewController {
    func ignoreNavigationInTab(_ tab: Tab, navigation: WKNavigation) {
        self.ignoredNavigation.insert(navigation)
    }

    func recordNavigationInTab(_ tab: Tab, navigation: WKNavigation, visitType: VisitType) {
        self.typedNavigation[navigation] = visitType
    }

    /**
     * Untrack and do the right thing.
     */
    func getVisitTypeForTab(_ tab: Tab, navigation: WKNavigation?) -> VisitType? {
        guard let navigation = navigation else {
            // See https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/NavigationState.mm#L390
            return VisitType.link
        }

        if self.ignoredNavigation.remove(navigation) != nil {
            return nil
        }

        return self.typedNavigation.removeValue(forKey: navigation) ?? VisitType.link
    }
}

// MARK: - LegacyTabDelegate
extension BrowserViewController: LegacyTabDelegate {
    func tab(_ tab: Tab, didCreateWebView webView: WKWebView) {
        // Observers that live as long as the tab. Make sure these are all cleared in willDeleteWebView below!
        KVOs.forEach { webView.addObserver(self, forKeyPath: $0.rawValue, options: .new, context: nil) }
        webView.scrollView.addObserver(self.scrollController, forKeyPath: KVOConstants.contentSize.rawValue, options: .new, context: nil)
        webView.uiDelegate = self

        let formPostHelper = FormPostHelper(tab: tab)
        tab.addContentScript(formPostHelper, name: FormPostHelper.name())

        let readerMode = ReaderMode(tab: tab)
        readerMode.delegate = self
        tab.addContentScript(readerMode, name: ReaderMode.name())

        // only add the logins helper if the tab is not a private browsing tab
        if !tab.isPrivate {
            let logins = LoginsHelper(
                tab: tab,
                profile: profile,
                theme: themeManager.currentTheme
            )
            tab.addContentScript(logins, name: LoginsHelper.name())
        }

        // Credit card autofill setup and callback
        creditCardAutofillSetup(tab, didCreateWebView: webView)

        let contextMenuHelper = ContextMenuHelper(tab: tab)
        tab.addContentScript(contextMenuHelper, name: ContextMenuHelper.name())

        let errorHelper = ErrorPageHelper(certStore: profile.certStore)
        tab.addContentScript(errorHelper, name: ErrorPageHelper.name())

        let sessionRestoreHelper = SessionRestoreHelper(tab: tab)
        sessionRestoreHelper.delegate = self
        tab.addContentScriptToPage(sessionRestoreHelper, name: SessionRestoreHelper.name())

        let findInPageHelper = FindInPageHelper(tab: tab)
        findInPageHelper.delegate = self
        tab.addContentScript(findInPageHelper, name: FindInPageHelper.name())

        let adsHelper = AdsTelemetryHelper(tab: tab)
        tab.addContentScript(adsHelper, name: AdsTelemetryHelper.name())

        let noImageModeHelper = NoImageModeHelper(tab: tab)
        tab.addContentScript(noImageModeHelper, name: NoImageModeHelper.name())

        let downloadContentScript = DownloadContentScript(tab: tab)
        tab.addContentScript(downloadContentScript, name: DownloadContentScript.name())

        let printHelper = PrintHelper(tab: tab)
        tab.addContentScriptToPage(printHelper, name: PrintHelper.name())

        let nightModeHelper = NightModeHelper(tab: tab)
        tab.addContentScript(nightModeHelper, name: NightModeHelper.name())

        // XXX: Bug 1390200 - Disable NSUserActivity/CoreSpotlight temporarily
        // let spotlightHelper = SpotlightHelper(tab: tab)
        // tab.addHelper(spotlightHelper, name: SpotlightHelper.name())

        tab.addContentScript(LocalRequestHelper(), name: LocalRequestHelper.name())

        let blocker = FirefoxTabContentBlocker(tab: tab, prefs: profile.prefs)
        tab.contentBlocker = blocker
        tab.addContentScript(blocker, name: FirefoxTabContentBlocker.name())

        tab.addContentScript(FocusHelper(tab: tab), name: FocusHelper.name())
    }

    func tab(_ tab: Tab, willDeleteWebView webView: WKWebView) {
        DispatchQueue.main.async { [unowned self] in
            KVOs.forEach { webView.removeObserver(self, forKeyPath: $0.rawValue) }
            webView.scrollView.removeObserver(self.scrollController, forKeyPath: KVOConstants.contentSize.rawValue)
            webView.uiDelegate = nil
            webView.scrollView.delegate = nil
            webView.removeFromSuperview()
        }
    }

    func tab(_ tab: Tab, didSelectFindInPageForSelection selection: String) {
        updateFindInPageVisibility(visible: true)
        findInPageBar?.text = selection
    }

    func tab(_ tab: Tab, didSelectSearchWithFirefoxForSelection selection: String) {
        openSearchNewTab(isPrivate: tab.isPrivate, selection)
    }

    // MARK: Snack bar

    func tab(_ tab: Tab, didAddSnackbar bar: SnackBar) {
        // If the Tab that had a SnackBar added to it is not currently
        // the selected Tab, do nothing right now. If/when the Tab gets
        // selected later, we will show the SnackBar at that time.
        guard tab == tabManager.selectedTab else { return }
        bar.applyTheme(theme: themeManager.currentTheme)
        bottomContentStackView.addArrangedViewToBottom(bar, completion: {
            self.view.layoutIfNeeded()
        })
    }

    func tab(_ tab: Tab, didRemoveSnackbar bar: SnackBar) {
        bottomContentStackView.removeArrangedView(bar)
    }
}

// MARK: HomePanelDelegate
extension BrowserViewController: HomePanelDelegate {
    func homePanelDidRequestToOpenLibrary(panel: LibraryPanelType) {
        showLibrary(panel: panel)
        view.endEditing(true)
    }

    func homePanel(didSelectURL url: URL, visitType: VisitType, isGoogleTopSite: Bool) {
        guard let tab = tabManager.selectedTab else { return }
        if isGoogleTopSite {
            tab.urlType = .googleTopSite
            searchTelemetry?.shouldSetGoogleTopSiteSearch = true
        }

        // Handle keyboard shortcuts from homepage with url selection (ex: Cmd + Tap on Link; which is a cell in this case)
        if navigateLinkShortcutIfNeeded(url: url) {
            return
        }

        finishEditingAndSubmit(url, visitType: visitType, forTab: tab)
    }

    func homePanelDidRequestToOpenInNewTab(_ url: URL, isPrivate: Bool, selectNewTab: Bool = false) {
        let tab = tabManager.addTab(URLRequest(url: url), afterTab: tabManager.selectedTab, isPrivate: isPrivate)
        // Select new tab automatically if needed
        guard !selectNewTab else {
            tabManager.selectTab(tab)
            return
        }

        // If we are showing toptabs a user can just use the top tab bar
        guard !topTabsVisible else { return }

        // We're not showing the top tabs; show a toast to quick switch to the fresh new tab.
        let viewModel = ButtonToastViewModel(labelText: .ContextMenuButtonToastNewTabOpenedLabelText,
                                             buttonText: .ContextMenuButtonToastNewTabOpenedButtonText)
        let toast = ButtonToast(viewModel: viewModel,
                                theme: themeManager.currentTheme,
                                completion: { buttonPressed in
            if buttonPressed {
                self.tabManager.selectTab(tab)
            }
        })
        show(toast: toast)
    }

    func homePanelDidRequestToOpenTabTray(withFocusedTab tabToFocus: Tab?, focusedSegment: TabTrayPanelType?) {
        showTabTray(withFocusOnUnselectedTab: tabToFocus, focusedSegment: focusedSegment)
    }

    func homePanelDidRequestToOpenSettings(at settingsPage: Route.SettingsSection) {
        navigationHandler?.show(settings: settingsPage)
    }
}

// MARK: - SearchViewController
extension BrowserViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didSelectURL url: URL, searchTerm: String?) {
        guard let tab = tabManager.selectedTab else { return }

        let searchData = LegacyTabGroupData(searchTerm: searchTerm ?? "",
                                            searchUrl: url.absoluteString,
                                            nextReferralUrl: "")
        tab.metadataManager?.updateTimerAndObserving(state: .navSearchLoaded, searchData: searchData, isPrivate: tab.isPrivate)
        searchTelemetry?.shouldSetUrlTypeSearch = true
        finishEditingAndSubmit(url, visitType: VisitType.typed, forTab: tab)
    }

    // In searchViewController when user selects an open tabs and switch to it
    func searchViewController(_ searchViewController: SearchViewController, uuid: String) {
        overlayManager.switchTab(shouldCancelLoading: true)
        if let tab = tabManager.getTabForUUID(uuid: uuid) {
            tabManager.selectTab(tab)
        }
    }

    func presentSearchSettingsController() {
        let searchSettingsTableViewController = SearchSettingsTableViewController(profile: profile)

        // Update search icon when the searchengine changes
        searchSettingsTableViewController.updateSearchIcon = {
            self.urlBar.searchEnginesDidUpdate()
            self.searchController?.reloadSearchEngines()
            self.searchController?.reloadData()
        }
        let navController = ModalSettingsNavigationController(rootViewController: searchSettingsTableViewController)
        self.present(navController, animated: true, completion: nil)
    }

    func searchViewController(_ searchViewController: SearchViewController, didHighlightText text: String, search: Bool) {
        self.urlBar.setLocation(text, search: search)
    }

    func searchViewController(_ searchViewController: SearchViewController, didAppend text: String) {
        self.urlBar.setLocation(text, search: false)
    }
}

extension BrowserViewController: TabManagerDelegate {
    func tabManager(_ tabManager: TabManager, didSelectedTabChange selected: Tab?, previous: Tab?, isRestoring: Bool) {
        // Remove the old accessibilityLabel. Since this webview shouldn't be visible, it doesn't need it
        // and having multiple views with the same label confuses tests.
        if let webView = previous?.webView {
            webView.endEditing(true)
            webView.accessibilityLabel = nil
            webView.accessibilityElementsHidden = true
            webView.accessibilityIdentifier = nil
            webView.removeFromSuperview()
        }

        if let tab = selected, let webView = tab.webView {
            updateURLBarDisplayURL(tab)

            if previous == nil || tab.isPrivate != previous?.isPrivate {
                applyTheme()

                let ui: [PrivateModeUI?] = [toolbar, topTabsViewController, urlBar]
                ui.forEach { $0?.applyUIMode(isPrivate: tab.isPrivate, theme: themeManager.currentTheme) }
            } else {
                // Theme is applied to the tab and webView in the else case
                // because in the if block is applied already to all the tabs and web views
                tab.applyTheme(theme: themeManager.currentTheme)
                webView.applyTheme(theme: themeManager.currentTheme)
            }

            readerModeCache = tab.isPrivate ? MemoryReaderModeCache.sharedInstance : DiskReaderModeCache.sharedInstance
            if let privateModeButton = topTabsViewController?.privateModeButton, previous != nil && previous?.isPrivate != tab.isPrivate {
                privateModeButton.setSelected(tab.isPrivate, animated: true)
            }
            ReaderModeHandlers.readerModeCache = readerModeCache

            scrollController.tab = tab

            webView.accessibilityLabel = .WebViewAccessibilityLabel
            webView.accessibilityIdentifier = "contentView"
            webView.accessibilityElementsHidden = false

            browserDelegate?.show(webView: webView)

            if webView.url == nil {
                // The web view can go gray if it was zombified due to memory pressure.
                // When this happens, the URL is nil, so try restoring the page upon selection.
                tab.reload()
            }

            // Update Fakespot sidebar if necessary
            updateFakespot(tab: tab)
        }

        updateTabCountUsingTabManager(tabManager)

        bottomContentStackView.removeAllArrangedViews()
        if let bars = selected?.bars {
            bars.forEach { bar in
                bottomContentStackView.addArrangedViewToBottom(bar, completion: { self.view.layoutIfNeeded() })
            }
        }

        updateFindInPageVisibility(visible: false, tab: previous)
        setupMiddleButtonStatus(isLoading: selected?.loading ?? false)
        navigationToolbar.updateBackStatus(selected?.canGoBack ?? false)
        navigationToolbar.updateForwardStatus(selected?.canGoForward ?? false)
        if let url = selected?.webView?.url, !InternalURL.isValid(url: url) {
            self.urlBar.updateProgressBar(Float(selected?.estimatedProgress ?? 0))
        }

        if let readerMode = selected?.getContentScript(name: ReaderMode.name()) as? ReaderMode {
            urlBar.updateReaderModeState(readerMode.state, hideReloadButton: shouldUseiPadSetup())
            if readerMode.state == .active {
                showReaderModeBar(animated: false)
            } else {
                hideReaderModeBar(animated: false)
            }
        } else {
            urlBar.updateReaderModeState(ReaderModeState.unavailable, hideReloadButton: shouldUseiPadSetup())
        }

        if topTabsVisible {
            topTabsDidChangeTab()
        }

       /// If the selectedTab is showing an error page trigger a reload
        if let url = selected?.url, let internalUrl = InternalURL(url), internalUrl.isErrorPage {
            selected?.reloadPage()
            return
        }
        updateInContentHomePanel(selected?.url as URL?, focusUrlBar: true)
    }

    func tabManager(_ tabManager: TabManager, didAddTab tab: Tab, placeNextToParentTab: Bool, isRestoring: Bool) {
        // If we are restoring tabs then we update the count once at the end
        if !isRestoring {
            updateTabCountUsingTabManager(tabManager)
        }
        tab.tabDelegate = self
    }

    func tabManager(_ tabManager: TabManager, didRemoveTab tab: Tab, isRestoring: Bool) {
        if let url = tab.lastKnownUrl, !(InternalURL(url)?.isAboutURL ?? false), !tab.isPrivate {
            profile.recentlyClosedTabs.addTab(url as URL,
                                              title: tab.lastTitle,
                                              lastExecutedTime: tab.lastExecutedTime)
        }
        updateTabCountUsingTabManager(tabManager)
    }

    func tabManagerDidAddTabs(_ tabManager: TabManager) {
        updateTabCountUsingTabManager(tabManager)
    }

    func tabManagerDidRestoreTabs(_ tabManager: TabManager) {
        updateTabCountUsingTabManager(tabManager)
        openUrlAfterRestore()
    }

    func openUrlAfterRestore() {
        guard let url = urlFromAnotherApp?.url else { return }
        openURLInNewTab(url, isPrivate: urlFromAnotherApp?.isPrivate ?? false)
        urlFromAnotherApp = nil
    }

    func show(toast: Toast,
              afterWaiting delay: DispatchTimeInterval = Toast.UX.toastDelayBefore,
              duration: DispatchTimeInterval? = Toast.UX.toastDismissAfter) {
        if let downloadToast = toast as? DownloadToast {
            self.downloadToast = downloadToast
        }

        // If BVC isn't visible hold on to this toast until viewDidAppear
        if self.view.window == nil {
            self.pendingToast = toast
            return
        }

        toast.showToast(viewController: self, delay: delay, duration: duration) { toast in
            [
                toast.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                toast.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                toast.bottomAnchor.constraint(equalTo: self.bottomContentStackView.bottomAnchor)
            ]
        }
    }

    func tabManagerDidRemoveAllTabs(_ tabManager: TabManager, toast: ButtonToast?) {
        guard let toast = toast, !(tabManager.selectedTab?.isPrivate ?? false) else { return }
        // The toast is created from TabManager which doesn't have access to themeManager
        // The whole toast system needs some rework so as compromised solution before the rework I create the toast
        // with light theme and force apply theme with real theme before showing
        toast.applyTheme(theme: themeManager.currentTheme)
        show(toast: toast, afterWaiting: ButtonToast.UX.delay)
    }

    func updateTabCountUsingTabManager(_ tabManager: TabManager, animated: Bool = true) {
        if let selectedTab = tabManager.selectedTab {
            let count = selectedTab.isPrivate ? tabManager.privateTabs.count : tabManager.normalTabs.count
            toolbar.updateTabCount(count, animated: animated)
            urlBar.updateTabCount(count, animated: !urlBar.inOverlayMode)
            topTabsViewController?.updateTabCount(count, animated: animated)
        }
    }

    func tabManagerUpdateCount() {
        updateTabCountUsingTabManager(self.tabManager)
    }
}

// MARK: - UIPopoverPresentationControllerDelegate

extension BrowserViewController: UIPopoverPresentationControllerDelegate {
    func popoverPresentationControllerDidDismissPopover(_ popoverPresentationController: UIPopoverPresentationController) {
        displayedPopoverController = nil
        updateDisplayedPopoverProperties = nil
    }
}

extension BrowserViewController: UIAdaptivePresentationControllerDelegate {
    // Returning None here makes sure that the Popover is actually presented as a Popover and
    // not as a full-screen modal, which is the default on compact device classes.
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none
    }
}

extension BrowserViewController {
    /// Used to get the context menu save image in the context menu, shown from long press on webview links
    fileprivate func getImageData(_ url: URL, success: @escaping (Data) -> Void) {
        makeURLSession(
            userAgent: UserAgent.fxaUserAgent,
            configuration: URLSessionConfiguration.default).dataTask(with: url
            ) { (data, response, error) in
            if validatedHTTPResponse(response, statusCode: 200..<300) != nil,
               let data = data {
                success(data)
            }
        }.resume()
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        keyboardPressesHandler().handlePressesBegan(presses, with: event)
        super.pressesBegan(presses, with: event)
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        keyboardPressesHandler().handlePressesEnded(presses, with: event)
        super.pressesEnded(presses, with: event)
    }
}

extension BrowserViewController {
    // no-op - relates to UIImageWriteToSavedPhotosAlbum
    @objc
    func image(_ image: UIImage, didFinishSavingWithError error: NSError?, contextInfo: UnsafeRawPointer) { }
}

extension BrowserViewController: KeyboardHelperDelegate {
    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillShowWithState state: KeyboardState) {
        keyboardState = state
        updateViewConstraints()

        UIView.animate(
            withDuration: state.animationDuration,
            delay: 0,
            options: [UIView.AnimationOptions(rawValue: UInt(state.animationCurve.rawValue << 16))],
            animations: {
                self.bottomContentStackView.layoutIfNeeded()
            })
    }

    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillHideWithState state: KeyboardState) {
        keyboardState = nil
        updateViewConstraints()

        UIView.animate(
            withDuration: state.animationDuration,
            delay: 0,
            options: [UIView.AnimationOptions(rawValue: UInt(state.animationCurve.rawValue << 16))],
            animations: {
                self.bottomContentStackView.layoutIfNeeded()
            })

        finishEditionMode()
    }

    func keyboardHelper(_ keyboardHelper: KeyboardHelper, keyboardWillChangeWithState state: KeyboardState) {
        keyboardState = state
        updateViewConstraints()
    }

    private func finishEditionMode() {
        // If keyboard is dismiss leave edition mode Homepage case is handled in HomepageVC
        let newTabChoice = NewTabAccessors.getNewTabPage(profile.prefs)
        if newTabChoice != .topSites, newTabChoice != .blankPage {
            overlayManager.finishEditing(shouldCancelLoading: false)
        }
    }
}

extension BrowserViewController: SessionRestoreHelperDelegate {
    func sessionRestoreHelper(_ helper: SessionRestoreHelper, didRestoreSessionForTab tab: Tab) {
        if let tab = tabManager.selectedTab, tab.webView === tab.webView {
            updateUIForReaderHomeStateForTab(tab)
        }

        clipboardBarDisplayHandler?.didRestoreSession()
    }
}

extension BrowserViewController: TabTrayDelegate {
    func tabTrayDidCloseLastTab(toast: ButtonToast) {
        toast.applyTheme(theme: themeManager.currentTheme)
        show(toast: toast, afterWaiting: ButtonToast.UX.delay)
    }

    func tabTrayOpenRecentlyClosedTab(_ url: URL) {
        guard let tab = self.tabManager.selectedTab else { return }
        self.finishEditingAndSubmit(url, visitType: .link, forTab: tab)
    }

    // This function animates and resets the tab chrome transforms when
    // the tab tray dismisses.
    func tabTrayDidDismiss(_ tabTray: LegacyGridTabViewController) {
        resetBrowserChrome()
    }

    func tabTrayDidAddTab(_ tabTray: LegacyGridTabViewController, tab: Tab) {}

    func tabTrayDidAddBookmark(_ tab: Tab) {
        guard let url = tab.url?.absoluteString, !url.isEmpty else { return }
        let tabState = tab.tabState
        addBookmark(url: url, title: tabState.title)
        TelemetryWrapper.recordEvent(category: .action, method: .add, object: .bookmark, value: .tabTray)
    }

    func tabTrayDidAddToReadingList(_ tab: Tab) -> ReadingListItem? {
        guard let url = tab.url?.absoluteString, !url.isEmpty else { return nil }
        return profile.readingList.createRecordWithURL(url, title: tab.title ?? url, addedBy: UIDevice.current.name).value.successValue
    }

    func tabTrayDidRequestTabsSettings() {
        navigationHandler?.show(settings: .tabs)
    }
}

extension BrowserViewController: JSPromptAlertControllerDelegate {
    func promptAlertControllerDidDismiss(_ alertController: JSPromptAlertController) {
        showQueuedAlertIfAvailable()
    }
}

extension BrowserViewController: TopTabsDelegate {
    func topTabsDidPressTabs() {
        // Technically is not changing tabs but is loosing focus on urlbar
        overlayManager.switchTab(shouldCancelLoading: true)
        self.urlBarDidPressTabs(urlBar)
    }

    func topTabsDidPressNewTab(_ isPrivate: Bool) {
        openBlankNewTab(focusLocationField: true, isPrivate: isPrivate)
        overlayManager.openNewTab(url: nil,
                                  newTabSettings: newTabSettings)
    }

    func topTabsDidChangeTab() {
        // Only for iPad leave overlay mode on tab change
        overlayManager.switchTab(shouldCancelLoading: true)
        updateZoomPageBarVisibility(visible: false)
    }

    func topTabsDidPressPrivateMode() {
        updateZoomPageBarVisibility(visible: false)
    }
}

extension BrowserViewController: DevicePickerViewControllerDelegate, InstructionsViewDelegate {
    func dismissInstructionsView() {
        self.navigationController?.presentedViewController?.dismiss(animated: true)
        self.popToBVC()
    }

    func devicePickerViewControllerDidCancel(_ devicePickerViewController: DevicePickerViewController) {
        self.popToBVC()
    }

    func devicePickerViewController(_ devicePickerViewController: DevicePickerViewController, didPickDevices devices: [RemoteDevice]) {
        guard let shareItem = devicePickerViewController.shareItem else { return }

        guard shareItem.isShareable else {
            let alert = UIAlertController(title: .SendToErrorTitle, message: .SendToErrorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: .SendToErrorOKButton, style: .default) { _ in self.popToBVC() })
            present(alert, animated: true, completion: nil)
            return
        }
        profile.sendItem(shareItem, toDevices: devices).uponQueue(.main) { _ in
            self.popToBVC()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                SimpleToast().showAlertWithText(.AppMenu.AppMenuTabSentConfirmMessage,
                                                bottomContainer: self.contentContainer,
                                                theme: self.themeManager.currentTheme)
            }
        }
    }
}

extension BrowserViewController {
    func trackTelemetry() {
        trackAccessibility()
        trackNotificationPermission()
    }

    func trackAccessibility() {
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .voiceOver,
                                     object: .app,
                                     extras: [TelemetryWrapper.EventExtraKey.isVoiceOverRunning.rawValue: UIAccessibility.isVoiceOverRunning.description])
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .switchControl,
                                     object: .app,
                                     extras: [TelemetryWrapper.EventExtraKey.isSwitchControlRunning.rawValue: UIAccessibility.isSwitchControlRunning.description])
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .reduceTransparency,
                                     object: .app,
                                     extras: [TelemetryWrapper.EventExtraKey.isReduceTransparencyEnabled.rawValue: UIAccessibility.isReduceTransparencyEnabled.description])
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .reduceMotion,
                                     object: .app,
                                     extras: [TelemetryWrapper.EventExtraKey.isReduceMotionEnabled.rawValue: UIAccessibility.isReduceMotionEnabled.description])
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .invertColors,
                                     object: .app,
                                     extras: [TelemetryWrapper.EventExtraKey.isInvertColorsEnabled.rawValue: UIAccessibility.isInvertColorsEnabled.description])
        TelemetryWrapper.recordEvent(category: .action,
                                     method: .dynamicTextSize,
                                     object: .app,
                                     extras: [
                                        TelemetryWrapper.EventExtraKey.isAccessibilitySizeEnabled.rawValue: UIApplication.shared.preferredContentSizeCategory.isAccessibilityCategory.description,
                                        TelemetryWrapper.EventExtraKey.preferredContentSizeCategory.rawValue: UIApplication.shared.preferredContentSizeCategory.rawValue.description])
    }

    func trackNotificationPermission() {
        NotificationManager().getNotificationSettings(sendTelemetry: true) { _ in }
    }
}
