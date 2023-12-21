// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core

public protocol UtilService {
    func createWallet() throws -> WalletInfo?
    func importWallet(with mnemonic: String) throws -> WalletInfo?
}

public struct WalletInfo {
    let address: String
    let mnemonics: String
    let privateKey: Data
    
    var addressPreview: String {
        address.prefix(4) + "..." + address.suffix(4)
    }
}

extension EtherWallet: UtilService {
    public func createWallet() throws -> WalletInfo? {
        let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let web3KeystoreManager = KeystoreManager.managerForPath(userDir + "/keystore")
        
        guard web3KeystoreManager?.addresses?.count ?? 0 >= 0 else {
            return nil
        }
        
        let tempMnemonics = try BIP39.generateMnemonics(bitsOfEntropy: 256, language: .english)
        guard let tMnemonics = tempMnemonics else {
            throw "We are unable to create wallet"
        }
        
        guard
            let tempWalletAddress = try BIP32Keystore(mnemonics: tMnemonics, password: "", prefixPath: "m/44'/77777'/0'/0"),
            let walletAddress = tempWalletAddress.addresses?.first
        else {
            throw "Unable to create wallet"
        }
        
        let address = walletAddress.address
        let privateKey = try tempWalletAddress.UNSAFE_getPrivateKeyData(password: "", account: walletAddress)

        let keyData = try JSONEncoder().encode(tempWalletAddress.keystoreParams)
        FileManager.default.createFile(atPath: userDir + "/keystore" + "/key.json", contents: keyData, attributes: nil)
        
        return WalletInfo(address: address, mnemonics: tMnemonics, privateKey: privateKey)
    }
    
    public func importWallet(with mnemonic: String) throws -> WalletInfo? {
        let keystore = try BIP32Keystore(mnemonics: mnemonic, password: "", mnemonicsPassword: "")
        guard let myWeb3KeyStore = keystore else {
            return nil
        }
        
        let manager = KeystoreManager([myWeb3KeyStore])
     
        guard let walletAddress = keystore?.addresses?.first else {
            return nil
        }
        
        let privateKey = try manager.UNSAFE_getPrivateKeyData(password: "", account: walletAddress)
        
        return WalletInfo(address: walletAddress.address, mnemonics: mnemonic, privateKey: privateKey)
    }
}
