// swiftlint:disable all
// Generated using SwiftGen — https://github.com/SwiftGen/SwiftGen

#if os(macOS)
  import AppKit.NSFont
#elseif os(iOS) || os(tvOS) || os(watchOS)
  import UIKit.UIFont
#endif
#if canImport(SwiftUI)
  import SwiftUI
#endif

// Deprecated typealiases
@available(*, deprecated, renamed: "FontConvertible.Font", message: "This typealias will be removed in SwiftGen 7.0")
private typealias Font = FontConvertible.Font

// swiftlint:disable superfluous_disable_command file_length implicit_return

// MARK: - Fonts

// swiftlint:disable identifier_name line_length type_body_length
internal enum Fonts {
  internal enum Karla {
    internal static let bold = FontConvertible(name: "Karla-Bold", family: "Karla", path: "Karla-Bold.ttf")
    internal static let boldItalic = FontConvertible(name: "Karla-BoldItalic", family: "Karla", path: "Karla-BoldItalic.ttf")
    internal static let extraBold = FontConvertible(name: "Karla-ExtraBold", family: "Karla", path: "Karla-ExtraBold.ttf")
    internal static let extraBoldItalic = FontConvertible(name: "Karla-ExtraBoldItalic", family: "Karla", path: "Karla-ExtraBoldItalic.ttf")
    internal static let extraLight = FontConvertible(name: "Karla-ExtraLight", family: "Karla", path: "Karla-ExtraLight.ttf")
    internal static let extraLightItalic = FontConvertible(name: "Karla-ExtraLightItalic", family: "Karla", path: "Karla-ExtraLightItalic.ttf")
    internal static let italic = FontConvertible(name: "Karla-Italic", family: "Karla", path: "Karla-Italic.ttf")
    internal static let light = FontConvertible(name: "Karla-Light", family: "Karla", path: "Karla-Light.ttf")
    internal static let lightItalic = FontConvertible(name: "Karla-LightItalic", family: "Karla", path: "Karla-LightItalic.ttf")
    internal static let medium = FontConvertible(name: "Karla-Medium", family: "Karla", path: "Karla-Medium.ttf")
    internal static let mediumItalic = FontConvertible(name: "Karla-MediumItalic", family: "Karla", path: "Karla-MediumItalic.ttf")
    internal static let regular = FontConvertible(name: "Karla-Regular", family: "Karla", path: "Karla-Regular.ttf")
    internal static let semiBold = FontConvertible(name: "Karla-SemiBold", family: "Karla", path: "Karla-SemiBold.ttf")
    internal static let semiBoldItalic = FontConvertible(name: "Karla-SemiBoldItalic", family: "Karla", path: "Karla-SemiBoldItalic.ttf")
    internal static let all: [FontConvertible] = [bold, boldItalic, extraBold, extraBoldItalic, extraLight, extraLightItalic, italic, light, lightItalic, medium, mediumItalic, regular, semiBold, semiBoldItalic]
  }
  internal enum NewYorkMedium {
    internal static let bold = FontConvertible(name: "NewYorkMedium-Bold", family: "New York Medium", path: "NewYorkMedium-Bold.otf")
    internal static let boldItalic = FontConvertible(name: "NewYorkMedium-BoldItalic", family: "New York Medium", path: "NewYorkMedium-BoldItalic.otf")
    internal static let regular = FontConvertible(name: "NewYorkMedium-Regular", family: "New York Medium", path: "NewYorkMedium-Regular.otf")
    internal static let regularItalic = FontConvertible(name: "NewYorkMedium-RegularItalic", family: "New York Medium", path: "NewYorkMedium-RegularItalic.otf")
    internal static let all: [FontConvertible] = [bold, boldItalic, regular, regularItalic]
  }
  internal static let allCustomFonts: [FontConvertible] = [Karla.all, NewYorkMedium.all].flatMap { $0 }
  internal static func registerAllCustomFonts() {
    allCustomFonts.forEach { $0.register() }
  }
}
// swiftlint:enable identifier_name line_length type_body_length

// MARK: - Implementation Details

internal struct FontConvertible {
  internal let name: String
  internal let family: String
  internal let path: String

  #if os(macOS)
  internal typealias Font = NSFont
  #elseif os(iOS) || os(tvOS) || os(watchOS)
  internal typealias Font = UIFont
  #endif

  internal func font(size: CGFloat) -> Font {
    guard let font = Font(font: self, size: size) else {
      fatalError("Unable to initialize font '\(name)' (\(family))")
    }
    return font
  }

  #if canImport(SwiftUI)
  @available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
  internal func swiftUIFont(size: CGFloat) -> SwiftUI.Font {
    return SwiftUI.Font.custom(self, size: size)
  }

  @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
  internal func swiftUIFont(fixedSize: CGFloat) -> SwiftUI.Font {
    return SwiftUI.Font.custom(self, fixedSize: fixedSize)
  }

  @available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
  internal func swiftUIFont(size: CGFloat, relativeTo textStyle: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
    return SwiftUI.Font.custom(self, size: size, relativeTo: textStyle)
  }
  #endif

  internal func register() {
    // swiftlint:disable:next conditional_returns_on_newline
    guard let url = url else { return }
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
  }

  fileprivate func registerIfNeeded() {
    #if os(iOS) || os(tvOS) || os(watchOS)
    if !UIFont.fontNames(forFamilyName: family).contains(name) {
      register()
    }
    #elseif os(macOS)
    if let url = url, CTFontManagerGetScopeForURL(url as CFURL) == .none {
      register()
    }
    #endif
  }

  fileprivate var url: URL? {
    // swiftlint:disable:next implicit_return
    return BundleToken.bundle.url(forResource: path, withExtension: nil)
  }
}

internal extension FontConvertible.Font {
  convenience init?(font: FontConvertible, size: CGFloat) {
    font.registerIfNeeded()
    self.init(name: font.name, size: size)
  }
}

#if canImport(SwiftUI)
@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
internal extension SwiftUI.Font {
  static func custom(_ font: FontConvertible, size: CGFloat) -> SwiftUI.Font {
    font.registerIfNeeded()
    return custom(font.name, size: size)
  }
}

@available(iOS 14.0, tvOS 14.0, watchOS 7.0, macOS 11.0, *)
internal extension SwiftUI.Font {
  static func custom(_ font: FontConvertible, fixedSize: CGFloat) -> SwiftUI.Font {
    font.registerIfNeeded()
    return custom(font.name, fixedSize: fixedSize)
  }

  static func custom(
    _ font: FontConvertible,
    size: CGFloat,
    relativeTo textStyle: SwiftUI.Font.TextStyle
  ) -> SwiftUI.Font {
    font.registerIfNeeded()
    return custom(font.name, size: size, relativeTo: textStyle)
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
