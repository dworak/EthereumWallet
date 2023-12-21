// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import SwiftUI

struct SendView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var ethAddress: String = ""
    @State private var ethAmmount: String = ""
    @Binding var ethBalance: Double?
    @State var showAlert: Bool = false
    @State var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 10) {
                        Asset.arrowSmLeft.swiftUIImage
                        Text("Back")
                            .font(Fonts.Karla.medium.swiftUIFont(size: 16))
                            .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                            .tracking(-0.16)
                    }
                    .frame(width: 107, height: 48)
                    .background(Color.white)
                    .cornerRadius(7)
                }
                Spacer()
            }
            .padding(24)
            ScrollView {
                HStack {
                    Text("Send Money")
                        .font(Fonts.Karla.bold.swiftUIFont(size: 24))
                        .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 1)))
                        .tracking(-0.24)
                    Spacer()
                }
                .padding(EdgeInsets(top: 12, leading: 24, bottom: 0, trailing: 24))
                
                HStack {
                    TextField("Ux...4w", text: $ethAddress)
                        .font(Fonts.Karla.medium.swiftUIFont(size: 32))
                        .foregroundColor(Color(#colorLiteral(red: 0.07, green: 0.07, blue: 0.07, alpha: 0.4)))
                        .frame(width: 180, height: 49)
                    Spacer()
                }
                .padding(EdgeInsets(top: 32, leading: 24, bottom: 12, trailing: 24))
                
                HStack {
                    Divider()
                        .frame(width: 180, height: 1)
                        .background(Color(hex: "111111").opacity(0.1))
                    Spacer()
                }
                .padding(.leading, 24)
                
                HStack {
                    TextField("0.00", text: $ethAmmount)
                        .font(Fonts.Karla.medium.swiftUIFont(size: 32))
                        .foregroundColor(Color(#colorLiteral(red: 0.07, green: 0.07, blue: 0.07, alpha: 0.4)))
                        .frame(width: 180, height: 49)
                    Spacer()
                }
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 12, trailing: 24))
                
                HStack {
                    Divider()
                        .frame(width: 180, height: 1)
                        .background(Color(hex: "111111").opacity(0.1))
                    Spacer()
                }
                .padding(.leading, 24)
                
                HStack {
                    Text("Asset")
                        .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                        .foregroundColor(Color(hex: "424242").opacity(0.6))
                        .tracking(-0.14)
                    Spacer()
                }
                .padding(24)
                
                HStack(spacing: 0) {
                    Group {
                        Asset.ethIcon.swiftUIImage
                    }
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .cornerRadius(7)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Ethereum")
                            .font(Fonts.Karla.bold.swiftUIFont(size: 16))
                            .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 1)))
                        Text("\(ethBalance ?? 0) ETH")
                            .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                            .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                    }.padding(.leading, 16)
                    
                    Spacer()
                    Button(action: {}) {
                        Asset.cheveronDown.swiftUIImage
                    }
                    
                }.padding(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                
                Divider()
                    .background(Color(hex: "E4E3FF"))
                    .padding(EdgeInsets(top: 0, leading: 24, bottom: 0, trailing: 24))
                
                Button(action: sendAction) {
                    HStack(spacing: 12) {
                        Spacer()
                        Asset.arrowSmRight.swiftUIImage
                        Text("Send Money")
                            .font(Fonts.Karla.bold.swiftUIFont(size: 15))
                            .foregroundColor(Color(#colorLiteral(red: 1, green: 1, blue: 1, alpha: 1)))
                            .tracking(-0.15)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    .frame(height: 48)
                    .background(Color(hex: "424242"))
                    .cornerRadius(7)
                }
                .padding(EdgeInsets(top: 24, leading: 24, bottom: 0, trailing: 24))
                
                HStack(spacing: 0) {
                    Text("Expected Gas Fees: ")
                        .font(Fonts.Karla.bold.swiftUIFont(size: 14))
                        .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.9)))
                        .tracking(-0.14) +
                    Text("0.003 ETH")
                        .font(Fonts.Karla.medium.swiftUIFont(size: 14))
                        .foregroundColor(Color(#colorLiteral(red: 0.26, green: 0.26, blue: 0.26, alpha: 0.6)))
                        .tracking(-0.14)
                    Spacer()
                }.padding(EdgeInsets(top: 12, leading: 24, bottom: 0, trailing: 24))
                
                Spacer()
            }
        }
        .background(Color(hex: "F8F8F8"))
        .navigationBarBackButtonHidden(true)
        .alert(errorMessage ?? "", isPresented: $showAlert) {
            Button("OK", role: .cancel) { }
        }
        .onChange(of: ethAddress, perform: fetchGasPrice)
        .onChange(of: ethAmmount, perform: fetchGasPrice)
    }
    
    private func sendAction() {
        Task {
            do {
                let response = try await EtherWallet.transaction.sendEtherSync(to: ethAddress, amount: ethAmmount, password: "")
                debugPrint(response)
            } catch {
                debugPrint(error.localizedDescription)
                errorMessage = error.localizedDescription
                showAlert = true
            }
        }
    }
    
    private func fetchGasPrice(change: String) {
        Task {
            do {
                if let price = try await EtherWallet.transaction.estimateGasPrice(to: ethAddress, value: ethAmmount) {
                    debugPrint(price)
                }
            } catch {
                errorMessage = error.localizedDescription
                showAlert = true
                debugPrint(error)
            }
        }
    }
    
}
