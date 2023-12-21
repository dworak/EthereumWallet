// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import SwiftUI

struct WalletView: View {
    enum Mode {
        case new
        case existing(String)
    }
    
    @State private var selectedPage: Page = .home
    @State private var wallet: WalletInfo?
    @State private var transactions: [Transaction] = []
    
    var mode: Mode

    var body: some View {
        GeometryReader { geometryProxy in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Image("account-connected")
                        .padding(.leading, 12)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Your Wallet")
                            .font(Fonts.Karla.bold.swiftUIFont(size: 14))
                            .foregroundColor(Color(hex: "424242").opacity(0.9))
                            .tracking(-0.14)
                        HStack {
                            Text(wallet?.addressPreview ?? "")
                                .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                                .foregroundColor(Color(hex: "424242").opacity(0.6))
                                .tracking(-0.14)
                            Image("copy")
                            Spacer()
                        }
                    }
                    .padding(.leading, 6)
                    Spacer()
                    HStack(spacing: 8) {
                        ForEach(Page.allCases, id: \.self) { item in
                            Button(action: {
                                selectedPage = item
                            }) {
                                item.image
                            }
                            .frame(width: 44, height: 44)
                            .background(selectedPage == item ? Color(hex: "424242").opacity(0.05) : Color.white)
                            .cornerRadius(7)
                        }
                    }
                    .padding(.trailing, 12)
                }
                .frame(height: 68)
                .background(Color.white)
                .cornerRadius(7)
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 24, trailing: 24))
                
                switch selectedPage {
                case .home:
                    homeContent(with: geometryProxy)
                case .swap:
                    Spacer()
                case .history:
                    historyContent()
                }
            }
            .frame(
                width: geometryProxy.size.width,
                height: geometryProxy.size.height,
                alignment: .topLeading
            )
            .background(Color(hex: "F8F8F8"))
        }.onAppear(perform: initialize)
    }
    
    @ViewBuilder
    func homeContent(with geometryProxy: GeometryProxy) -> some View {
        VStack {
            VStack {
                Text("$404.18")
                    .font(Fonts.Karla.bold.swiftUIFont(size: 32))
                    .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 1)))
                Text("+12.44%")
                    .font(Fonts.Karla.medium.swiftUIFont(size: 18))
                    .foregroundColor(Color(#colorLiteral(red: 0.23, green: 0.8, blue: 0.42, alpha: 1)))
                    .tracking(-0.18)
            }
        }
        .frame(width: geometryProxy.size.width - 48, height: 119)
        .background(Color.white)
        .cornerRadius(7)
        .padding(EdgeInsets(top: 0, leading: 24, bottom: 24, trailing: 24))
        
        HStack(spacing: 12) {
            Spacer()
            Button(action: {}) {
                HStack(spacing: 12) {
                    Asset.arrowSmRight.swiftUIImage
                    Text("Send")
                        .font(Fonts.Karla.bold.swiftUIFont(size: 15))
                        .foregroundColor(Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)))
                        .tracking(-0.15)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(width: 86, height: 32)
            .background(Color(hex: "424242"))
            .cornerRadius(7)
            Button(action: {}) {
                Image("cash")
                Text("Deposit")
                    .font(Fonts.Karla.bold.swiftUIFont(size: 15))
                    .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 1)))
                    .tracking(-0.15).multilineTextAlignment(.center)
            }
            .frame(width: 104, height: 36)
            .cornerRadiusWithBorder(radius: 7, borderLineWidth: 2, borderColor: Color(hex: "424242").opacity(0.25))
        }.padding(.trailing, 24)
        
        HStack {
            Text("Assets")
                .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                .foregroundColor(Color(hex: "424242").opacity(0.6))
                .tracking(-0.14)
            Spacer()
        }
        .padding(24)
        
        HStack {
            Group {
                Asset.ethIcon.swiftUIImage
            }
        }
        
        Spacer()
    }
    
    @ViewBuilder
    func historyContent() -> some View {
        VStack {
            HStack {
                Text("Activity")
                    .font(Fonts.Karla.bold.swiftUIFont(size: 24))
                    .foregroundColor(Color(hex: "424242"))
                    .tracking(-0.24)
                Spacer()
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Text("Export")
                            .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                            .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                            .tracking(-0.14)
                        Image("file")
                    }
                }
            }
            .padding(.bottom, 16)
            ScrollView {
                ForEach(transactions, id: \.self) { transaction in
                    VStack(spacing: 0) {
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Group {
                                transaction.image(address: wallet?.address ?? "")
                            }
                            .frame(width: 40, height: 40)
                            .background(Color.white)
                            .cornerRadius(7)
                            
                            VStack(alignment: .leading, spacing: 0) {
                                Text(transaction.description(address: wallet?.address ?? ""))
                                    .font(Fonts.Karla.bold.swiftUIFont(fixedSize: 16))
                                    .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 1)))
                                HStack {
                                    Button(action: {}) {
                                        HStack(spacing: 6) {
                                            Text(transaction.secondaryDescription(address: wallet?.address ?? ""))
                                                .font(Fonts.Karla.medium.swiftUIFont(fixedSize: 14))
                                                .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                                                .tracking(-0.14)
                                            Asset.copy.swiftUIImage
                                        }
                                    }
                                    Text(transaction.date()?.formatted() ?? "")
                                        .font(Fonts.Karla.medium.swiftUIFont(fixedSize: 14))
                                        .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: {}) {
                                Asset.externalLink.swiftUIImage
                            }
                        }
                        Spacer()
                        
                        Divider().background(Color(hex: "E4E3FF"))
                    }.frame(height: 77)
                }
            }
        }
        .padding(EdgeInsets(top: 0, leading: 24, bottom: 24, trailing: 24)  )
        .onAppear {
            if let wallet = wallet {
                Task {
                    let transationList = try await EtherWallet.history.getTransactionList(for: wallet.address)
                    transactions = transationList
                }
            }
        }
    }
    
    func initialize() {
        switch mode {
        case .new:
            do {
                if let walletInfo = try EtherWallet.util.createWallet() {
                    debugPrint(walletInfo)
                    wallet = walletInfo
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        case .existing(let mnemonics):
            do {
                if let walletInfo = try EtherWallet.util.importWallet(with: mnemonics) {
                    debugPrint(walletInfo)
                    wallet = walletInfo
                }
            } catch {
                debugPrint(error.localizedDescription)
            }
        }
    }
}

fileprivate struct ModifierCornerRadiusWithBorder: ViewModifier {
    var radius: CGFloat
    var borderLineWidth: CGFloat = 1
    var borderColor: Color = .gray
    var antialiased: Bool = true
    
    func body(content: Content) -> some View {
        content
            .cornerRadius(self.radius, antialiased: self.antialiased)
            .overlay(
                RoundedRectangle(cornerRadius: self.radius)
                    .inset(by: self.borderLineWidth)
                    .strokeBorder(self.borderColor, lineWidth: self.borderLineWidth, antialiased: self.antialiased)
            )
    }
}

enum Page: CaseIterable {
    case home
    case swap
    case history
    
    var image: Image {
        switch self {
        case .home:
            Image("home")
        case .swap:
            Image("refresh")
        case .history:
            Image("clock")
        }
    }
}

extension View {
    func cornerRadiusWithBorder(radius: CGFloat, borderLineWidth: CGFloat = 1, borderColor: Color = .gray, antialiased: Bool = true) -> some View {
        modifier(ModifierCornerRadiusWithBorder(radius: radius, borderLineWidth: borderLineWidth, borderColor: borderColor, antialiased: antialiased))
    }
}
