// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core
import KeychainWrapper

public protocol AccountService {
    var hasAccount: Bool { get }
    var address: String? { get }
    var mnemonics: String? { get set }
    func privateKey(password: String) throws -> String
    func verifyPassword(_ password: String) -> Bool
    func generateAccount(password: String) throws
    func importAccount(privateKey: String, password: String) throws
    func importAccount(mnemonics: String, password: String) throws
}

extension EtherWallet: AccountService {
    public var hasAccount: Bool {
        return (try? loadKeystore()) != nil
    }
    
    public var address: String? {
        guard let keystore = try? loadKeystore() else { return nil }
        return keystore.getAddress()?.address
    }
    
    public var mnemonics: String? {
        get {
            return KeychainWrapper.default.string(forKey: mnemonicsKeystoreKey)
        }
        set {
            if let newValue = newValue {
                KeychainWrapper.default.set(newValue, forKey: mnemonicsKeystoreKey)
            } else {
                KeychainWrapper.default.removeObject(forKey: mnemonicsKeystoreKey)
            }
        }
    }
    
    public func privateKey(password: String) throws -> String {
        let keystore = try loadKeystore()
        guard let address = keystore.getAddress()?.address else {
            throw WalletError.malformedKeystore
        }
        guard let ethereumAddress = EthereumAddress(address) else {
            throw  WalletError.invalidAddress
        }
        let privateKeyData = try keystore.UNSAFE_getPrivateKeyData(password: password, account: ethereumAddress)
        
        return privateKeyData.toHexString()
    }
    
    public func verifyPassword(_ password: String) -> Bool {
        return (try? privateKey(password: password)) != nil
    }
    
    public func generateAccount(password: String) throws {
        guard let mnemonics = try BIP39.generateMnemonics(bitsOfEntropy: 128) else {
            throw WalletError.unexpectedResult
        }
        
        try importAccount(mnemonics: mnemonics, password: password)
    }
    
    public func importAccount(privateKey: String, password: String) throws {
        guard let privateKeyData = Data.fromHex(privateKey) else {
            throw WalletError.invalidKey
        }
        guard let keystore = try EthereumKeystoreV3(privateKey: privateKeyData, password: password) else {
            throw WalletError.malformedKeystore
        }
        
        try saveKeystore(keystore)
        self.mnemonics = nil
    }
    
    public func importAccount(mnemonics: String, password: String) throws {
        guard let keystore = (try? BIP32Keystore(mnemonics: mnemonics, password: password)) ?? nil else {
            throw WalletError.invalidMnemonics
        }
        
        guard let address = keystore.addresses?.first else {
            throw WalletError.malformedKeystore
        }
        
        guard let privateKey = try? keystore.UNSAFE_getPrivateKeyData(password: password, account: address).toHexString() else {
            throw WalletError.malformedKeystore
        }
        
        try importAccount(privateKey: privateKey, password: password)
        self.mnemonics = mnemonics
    }
    
    private func saveKeystore(_ keystore: EthereumKeystoreV3) throws {
        keystoreCache = keystore
        
        guard let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            throw WalletError.invalidPath
        }
        guard let keystoreParams = keystore.keystoreParams else {
            throw WalletError.malformedKeystore
        }
        guard let keystoreData = try? JSONEncoder().encode(keystoreParams) else {
            throw WalletError.malformedKeystore
        }
        if !FileManager.default.fileExists(atPath: userDir + keystoreDirectoryName) {
            do {
                try FileManager.default.createDirectory(atPath: userDir + keystoreDirectoryName, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw WalletError.invalidPath
            }
        }
        
        FileManager.default.createFile(atPath: userDir + keystoreDirectoryName + keystoreFileName, contents: keystoreData, attributes: nil)
        
        setupOptionsFrom()
    }
    
    func loadKeystore() throws -> EthereumKeystoreV3 {
        if let keystore = keystoreCache {
            return keystore
        }
        
        guard let userDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first else {
            throw WalletError.invalidPath
        }
        guard let keystoreManager = KeystoreManager.managerForPath(userDir + keystoreDirectoryName) else {
            throw WalletError.malformedKeystore
        }
        guard let address = keystoreManager.addresses?.first else {
            throw WalletError.malformedKeystore
        }
        guard let keystore = keystoreManager.walletForAddress(address) as? EthereumKeystoreV3 else {
            throw WalletError.malformedKeystore
        }
        
        keystoreCache = keystore
        
        return keystore
    }
}
