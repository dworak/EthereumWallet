// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit
#elseif os(iOS)
  import UIKit
#elseif os(tvOS) || os(watchOS)
  import UIKit
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "ImageAsset.Image", message: "This typealias will be removed in SwiftGen 7.0")
internal typealias AssetImageTypeAlias = ImageAsset.Image

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Asset Catalogs

// swiftlint:disable identifier_name line_length nesting type_body_length type_name
internal enum Asset {
  internal static let addSearch = ImageAsset(name: "AddSearch")
  internal static let errorAutofill = ImageAsset(name: "error_autofill")
  internal static let logoAmex = ImageAsset(name: "logo_amex")
  internal static let logoDiners = ImageAsset(name: "logo_diners")
  internal static let logoDiscover = ImageAsset(name: "logo_discover")
  internal static let logoJcb = ImageAsset(name: "logo_jcb")
  internal static let logoMastercard = ImageAsset(name: "logo_mastercard")
  internal static let logoMir = ImageAsset(name: "logo_mir")
  internal static let logoUnionpay = ImageAsset(name: "logo_unionpay")
  internal static let logoVisa = ImageAsset(name: "logo_visa")
  internal static let breachedWebsite = ImageAsset(name: "Breached Website")
  internal static let accountConnected = ImageAsset(name: "account-connected")
  internal static let arrowNarrowDown = ImageAsset(name: "arrow-narrow-down")
  internal static let arrowNarrowLeft = ImageAsset(name: "arrow-narrow-left")
  internal static let arrowNarrowRight = ImageAsset(name: "arrow-narrow-right")
  internal static let arrowSmLeft = ImageAsset(name: "arrow-sm-left")
  internal static let arrowSmRight = ImageAsset(name: "arrow-sm-right")
  internal static let cash = ImageAsset(name: "cash")
  internal static let cheveronDown = ImageAsset(name: "cheveron-down")
  internal static let clock = ImageAsset(name: "clock")
  internal static let copy = ImageAsset(name: "copy")
  internal static let ethIcon = ImageAsset(name: "ethIcon")
  internal static let externalLink = ImageAsset(name: "external-link")
  internal static let home = ImageAsset(name: "home")
  internal static let refresh = ImageAsset(name: "refresh")
  internal static let userCircle = ImageAsset(name: "user-circle")
  internal static let actionShare = ImageAsset(name: "action_share")
  internal static let markAsRead = ImageAsset(name: "MarkAsRead")
  internal static let markAsUnread = ImageAsset(name: "MarkAsUnread")
  internal static let readerModeActive = ImageAsset(name: "ReaderModeActive")
  internal static let readerModeAvailable = ImageAsset(name: "ReaderModeAvailable")
  internal static let settingsSansSerif = ImageAsset(name: "SettingsSansSerif")
  internal static let settingsSerif = ImageAsset(name: "SettingsSerif")
  internal static let addToReadingList = ImageAsset(name: "addToReadingList")
  internal static let brightnessMax = ImageAsset(name: "brightnessMax")
  internal static let brightnessMin = ImageAsset(name: "brightnessMin")
  internal static let bugUpdate = ImageAsset(name: "bugUpdate")
  internal static let darkModeUpdate = ImageAsset(name: "darkModeUpdate")
  internal static let onboardingBackground = ImageAsset(name: "onboardingBackground")
  internal static let onboardingDock = ImageAsset(name: "onboardingDock")
  internal static let onboardingNotification = ImageAsset(name: "onboardingNotification")
  internal static let onboardingNotificationsCTD = ImageAsset(name: "onboardingNotificationsCTD")
  internal static let onboardingSearchWidget = ImageAsset(name: "onboardingSearchWidget")
  internal static let onboardingSync = ImageAsset(name: "onboardingSync")
  internal static let onboardingSyncCTD = ImageAsset(name: "onboardingSyncCTD")
  internal static let onboardingWelcome = ImageAsset(name: "onboardingWelcome")
  internal static let onboardingWelcomeCTD = ImageAsset(name: "onboardingWelcomeCTD")
  internal static let signinSync = ImageAsset(name: "signin-sync")
  internal static let shoppingLarge = ImageAsset(name: "shoppingLarge")
  internal static let shoppingNoAnalysisImage = ImageAsset(name: "shoppingNoAnalysisImage")
  internal static let shoppingOptInCardImage = ImageAsset(name: "shoppingOptInCardImage")
  internal static let starEmpty = ImageAsset(name: "starEmpty")
  internal static let starFill = ImageAsset(name: "starFill")
  internal static let starHalf = ImageAsset(name: "starHalf")
  internal static let navRefresh = ImageAsset(name: "nav-refresh")
  internal static let navShare = ImageAsset(name: "nav-share")
  internal static let navSummarize = ImageAsset(name: "nav-summarize")
  internal static let appMenuLarge = ImageAsset(name: "appMenuLarge")
  internal static let appendUpLarge = ImageAsset(name: "appendUpLarge")
  internal static let avatarCircleLarge = ImageAsset(name: "avatarCircleLarge")
  internal static let backLarge = ImageAsset(name: "backLarge")
  internal static let badgeMask = ImageAsset(name: "badge-mask")
  internal static let bookmarkBadgeFillMediumBlue50 = ImageAsset(name: "bookmarkBadgeFillMediumBlue50")
  internal static let bookmarkFillLarge = ImageAsset(name: "bookmarkFillLarge")
  internal static let bookmarkHalfLarge = ImageAsset(name: "bookmarkHalfLarge")
  internal static let bookmarkLarge = ImageAsset(name: "bookmarkLarge")
  internal static let bookmarkSlashLarge = ImageAsset(name: "bookmarkSlashLarge")
  internal static let bookmarkTrayFillLarge = ImageAsset(name: "bookmarkTrayFillLarge")
  internal static let checkmarkLarge = ImageAsset(name: "checkmarkLarge")
  internal static let chevronDownLarge = ImageAsset(name: "chevronDownLarge")
  internal static let chevronLeftLarge = ImageAsset(name: "chevronLeftLarge")
  internal static let chevronRightLarge = ImageAsset(name: "chevronRightLarge")
  internal static let chevronUpLarge = ImageAsset(name: "chevronUpLarge")
  internal static let clipboardLarge = ImageAsset(name: "clipboardLarge")
  internal static let competitivenessLarge = ImageAsset(name: "competitivenessLarge")
  internal static let contextPocket = ImageAsset(name: "context_pocket")
  internal static let creditCardLarge = ImageAsset(name: "creditCardLarge")
  internal static let criticalFillLarge = ImageAsset(name: "criticalFillLarge")
  internal static let crossCircleFillExtraLarge = ImageAsset(name: "crossCircleFillExtraLarge")
  internal static let crossLarge = ImageAsset(name: "crossLarge")
  internal static let crossMedium = ImageAsset(name: "crossMedium")
  internal static let deleteLarge = ImageAsset(name: "deleteLarge")
  internal static let deviceDesktopLarge = ImageAsset(name: "deviceDesktopLarge")
  internal static let deviceDesktopSendLarge = ImageAsset(name: "deviceDesktopSendLarge")
  internal static let deviceMobileLarge = ImageAsset(name: "deviceMobileLarge")
  internal static let deviceTypeTablet = ImageAsset(name: "deviceTypeTablet")
  internal static let downloadLarge = ImageAsset(name: "downloadLarge")
  internal static let editLarge = ImageAsset(name: "editLarge")
  internal static let emptySync = ImageAsset(name: "emptySync")
  internal static let faviconFox = ImageAsset(name: "faviconFox")
  internal static let file = ImageAsset(name: "file")
  internal static let folderLarge = ImageAsset(name: "folderLarge")
  internal static let forwardLarge = ImageAsset(name: "forwardLarge")
  internal static let fxHomeHeaderLogoBall = ImageAsset(name: "fxHomeHeaderLogoBall")
  internal static let fxHomeHeaderLogoText = ImageAsset(name: "fxHomeHeaderLogoText")
  internal static let globeLarge = ImageAsset(name: "globeLarge")
  internal static let helpCircleLarge = ImageAsset(name: "helpCircleLarge")
  internal static let historyLarge = ImageAsset(name: "historyLarge")
  internal static let homeLarge = ImageAsset(name: "homeLarge")
  internal static let homepagePocket = ImageAsset(name: "homepage-pocket")
  internal static let imageLarge = ImageAsset(name: "imageLarge")
  internal static let largePrivateMask = ImageAsset(name: "largePrivateMask")
  internal static let lightbulbLarge = ImageAsset(name: "lightbulbLarge")
  internal static let linkLarge = ImageAsset(name: "linkLarge")
  internal static let lockLarge = ImageAsset(name: "lockLarge")
  internal static let lockSlashLarge = ImageAsset(name: "lockSlashLarge")
  internal static let loginLarge = ImageAsset(name: "loginLarge")
  internal static let loginSelected = ImageAsset(name: "loginSelected")
  internal static let loginUnselected = ImageAsset(name: "loginUnselected")
  internal static let logoFirefoxLarge = ImageAsset(name: "logoFirefoxLarge")
  internal static let menuBadge = ImageAsset(name: "menuBadge")
  internal static let menuWarning = ImageAsset(name: "menuWarning")
  internal static let packagingLarge = ImageAsset(name: "packagingLarge")
  internal static let pinBadgeFillSmall = ImageAsset(name: "pinBadgeFillSmall")
  internal static let pinLarge = ImageAsset(name: "pinLarge")
  internal static let pinSlashLarge = ImageAsset(name: "pinSlashLarge")
  internal static let plusLarge = ImageAsset(name: "plusLarge")
  internal static let priceLarge = ImageAsset(name: "priceLarge")
  internal static let privateModeBadge = ImageAsset(name: "privateModeBadge")
  internal static let qrCodeIconWhite = ImageAsset(name: "qr-code-icon-white")
  internal static let qrCodeLarge = ImageAsset(name: "qrCodeLarge")
  internal static let qualityLarge = ImageAsset(name: "qualityLarge")
  internal static let quickSearch = ImageAsset(name: "quickSearch")
  internal static let quickActionLastTab = ImageAsset(name: "quick_action_last_tab")
  internal static let quickActionNewPrivateTab = ImageAsset(name: "quick_action_new_private_tab")
  internal static let quickActionReadingList = ImageAsset(name: "quick_action_reading_list")
  internal static let reader = ImageAsset(name: "reader")
  internal static let search = ImageAsset(name: "search")
  internal static let settings = ImageAsset(name: "settings")
  internal static let shippingLarge = ImageAsset(name: "shippingLarge")
  internal static let smallPrivateMask = ImageAsset(name: "smallPrivateMask")
  internal static let splash = ImageAsset(name: "splash")
  internal static let sponsoredStar = ImageAsset(name: "sponsored-star")
  internal static let subtract = ImageAsset(name: "subtract")
  internal static let syncOpenTab = ImageAsset(name: "sync_open_tab")
  internal static let syncedDevices = ImageAsset(name: "synced_devices")
  internal static let tabTrayLarge = ImageAsset(name: "tabTrayLarge")
  internal static let themeBrightness = ImageAsset(name: "themeBrightness")
  internal static let topTabsCloseTabs = ImageAsset(name: "topTabs-closeTabs")
  internal static let trackingProtectionActiveBlockDark = ImageAsset(name: "tracking-protection-active-block-dark")
  internal static let trackingProtectionActiveBlock = ImageAsset(name: "tracking-protection-active-block")
  internal static let trackingProtectionOff = ImageAsset(name: "tracking-protection-off")
  internal static let trackingProtection = ImageAsset(name: "tracking-protection")
  internal static let warningMask = ImageAsset(name: "warning-mask")
  internal static let warningFillLarge = ImageAsset(name: "warningFillLarge")
  internal static let whatsnew = ImageAsset(name: "whatsnew")
}
// swiftlint:enable identifier_name line_length nesting type_body_length type_name

// MARK: - Implementation Details

internal struct ImageAsset {
  internal fileprivate(set) var name: String

  #if os(macOS)
  internal typealias Image = NSImage
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Image = UIImage
  #endif

  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, macOS 10.7, *)
  internal var image: Image {
    let bundle = BundleToken.bundle
    #if os(iOS) || os(tvOS)
    let image = Image(named: name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    let name = NSImage.Name(self.name)
    let image = (bundle == .main) ? NSImage(named: name) : bundle.image(forResource: name)
    #elseif os(watchOS)
    let image = Image(named: name)
    #endif
    guard let result = image else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }

  #if os(iOS) || os(tvOS)
  @available(iOS 8.0, tvOS 9.0, *)
  internal func image(compatibleWith traitCollection: UITraitCollection) -> Image {
    let bundle = BundleToken.bundle
    guard let result = Image(named: name, in: bundle, compatibleWith: traitCollection) else {
      fatalError("Unable to load image asset named \(name).")
    }
    return result
  }
  #endif

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal var swiftUIImage: SwiftUI.Image {
    SwiftUI.Image(asset: self)
  }
  #endif
}

internal extension ImageAsset.Image {
  @available(iOS 8.0, tvOS 9.0, watchOS 2.0, *)
  @available(macOS, deprecated,
    message: "This initializer is unsafe on macOS, please use the ImageAsset.image property")
  convenience init?(asset: ImageAsset) {
    #if os(iOS) || os(tvOS)
    let bundle = BundleToken.bundle
    self.init(named: asset.name, in: bundle, compatibleWith: nil)
    #elseif os(macOS)
    self.init(named: NSImage.Name(asset.name))
    #elseif os(watchOS)
    self.init(named: asset.name)
    #endif
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Image {
  init(asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle)
  }

  init(asset: ImageAsset, label: Text) {
    let bundle = BundleToken.bundle
    self.init(asset.name, bundle: bundle, label: label)
  }

  init(decorative asset: ImageAsset) {
    let bundle = BundleToken.bundle
    self.init(decorative: asset.name, bundle: bundle)
  }
}
#endif

// swiftlint:disable convenience_type
private final class BundleToken {
  static let bundle: Bundle = {
    #if SWIFT_PACKAGE
    return Bundle.module
    #else
    return Bundle(for: BundleToken.self)
    #endif
  }()
}
// swiftlint:enable convenience_type
