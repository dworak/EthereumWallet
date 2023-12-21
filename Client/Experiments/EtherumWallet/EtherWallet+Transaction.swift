// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core
import BigInt

public protocol TransactionService {
    func sendEtherSync(to address: String, amount: String, password: String) async throws -> String
    func sendEtherSync(to address: String, amount: String, password: String, gasPrice: String?) async throws -> String
    func sendEther(to address: String, amount: String, password: String, completion: @escaping (String?) -> ())
    func sendEther(to address: String, amount: String, password: String, gasPrice: String?, completion: @escaping (String?) -> ())
    func sendTokenSync(to toAddress: String, contractAddress: String, amount: String, password: String, decimal: Int) async throws -> String
    func sendTokenSync(to toAddress: String, contractAddress: String, amount: String, password: String, decimal: Int, gasPrice: String?) async throws -> String
    func sendToken(to toAddress: String, contractAddress: String, amount: String, password: String, decimal:Int, completion: @escaping (String?) -> ())
    func sendToken(to toAddress: String, contractAddress: String, amount: String, password: String, decimal:Int, gasPrice: String?, completion: @escaping (String?) -> ())
}

extension EtherWallet: TransactionService {
    public func sendEtherSync(to address: String, amount: String, password: String) async throws -> String {
        return try await sendEtherSync(to: address, amount: amount, password: password, gasPrice: nil)
    }
    
    public func sendEtherSync(to address: String, amount: String, password: String, gasPrice: String?) async throws -> String {
        guard let toAddress = EthereumAddress(address) else { throw WalletError.invalidAddress }
        let keystore = try loadKeystore()
        
        
        let etherBalance = try await etherBalanceSync()
        guard let etherBalanceInDouble = Double(etherBalance) else { throw WalletError.conversionFailure }
        guard let amountInDouble = Double(amount) else { throw WalletError.conversionFailure }
        guard etherBalanceInDouble >= amountInDouble else { throw WalletError.notEnoughBalance }
        
        let keystoreManager = KeystoreManager([keystore])
        let web3Instance = try await Web3.InfuraMainnetWeb3()
        web3Instance.addKeystoreManager(keystoreManager)
        
        let allAddresses = try await web3Instance.eth.ownedAccounts()
        let parameters: [Any] = []
        
        guard 
            let contract = web3Instance.contract(Web3.Utils.coldWalletABI, at: toAddress, abiVersion: 2)
        else {
            throw WalletError.contractFailure
        }
        
        let sendTx = contract.createWriteOperation("fallback", parameters: parameters)!
        
        let valueToSend = Utilities.parseToBigUInt(amount, units: .ether)!
        sendTx.transaction.value = valueToSend
        sendTx.transaction.from = allAddresses[0]
        
        let result = try await sendTx.writeToChain(password: password, sendRaw: false)
        
        return Data.fromHex(result.hash.stripHexPrefix())!.toHexString()
    }
    
    public func sendEther(to address: String, amount: String, password: String, completion: @escaping (String?) -> ()) {
        sendEther(to: address, amount: amount, password: password, gasPrice: nil, completion: completion)
    }
    
    public func sendEther(to address: String, amount: String, password: String, gasPrice: String?, completion: @escaping (String?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let txHash = try? await self.sendEtherSync(to: address, amount: amount, password: password, gasPrice: gasPrice)
                DispatchQueue.main.async {
                    completion(txHash)
                }
            }
        }
    }
    
    public func sendTokenSync(to toAddress: String, contractAddress: String, amount: String, password: String, decimal: Int) async throws -> String {
        return try await sendTokenSync(to: toAddress, contractAddress: contractAddress, amount: amount, password: password, decimal: decimal, gasPrice: nil)
    }
    
    public func sendTokenSync(to toAddress: String, contractAddress: String, amount: String, password: String, decimal: Int, gasPrice: String?) async throws -> String {
        guard let tokenAddress = EthereumAddress(contractAddress) else { throw WalletError.invalidAddress }
        guard let fromAddress = address else { throw WalletError.accountDoesNotExist }
        guard let fromEthereumAddress = EthereumAddress(fromAddress) else { throw WalletError.invalidAddress }
        guard let toEthereumAddress = EthereumAddress(toAddress) else { throw WalletError.invalidAddress }
        
        let keystore = try loadKeystore()
        let keystoreManager = KeystoreManager([keystore])
        let web3Instance = try await Web3.InfuraMainnetWeb3()
        web3Instance.addKeystoreManager(keystoreManager)
        
        guard let tokenAmount = Utilities.parseToBigUInt(amount, decimals: decimal) else { throw WalletError.conversionFailure }
        let parameters = [toEthereumAddress, tokenAmount] as [AnyObject]
        
        guard let contract = web3Instance.contract(Web3.Utils.erc20ABI, at: tokenAddress, abiVersion: 2) else { throw WalletError.contractFailure }
        
        let allAddresses = try await web3Instance.eth.ownedAccounts()

        let sendTx = contract.createWriteOperation("transfer", parameters: parameters)!
        
        let valueToSend = Utilities.parseToBigUInt(amount, units: .ether)!
        sendTx.transaction.value = valueToSend
        sendTx.transaction.from = allAddresses[0]
        
        let result = try await sendTx.writeToChain(password: password, sendRaw: false)
        
        return Data.fromHex(result.hash.stripHexPrefix())!.toHexString()
    }
    
    public func sendToken(to toAddress: String, contractAddress: String, amount: String, password: String, decimal: Int, completion: @escaping (String?) -> ()) {
        sendToken(to: toAddress, contractAddress: contractAddress, amount: amount, password: password, decimal: decimal, gasPrice: nil, completion: completion)
    }
    
    public func sendToken(to toAddress: String, contractAddress: String, amount: String, password: String, decimal:Int, gasPrice: String?, completion: @escaping (String?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let txHash = try? await self.sendTokenSync(to: toAddress, contractAddress: contractAddress, amount: amount, password: password, decimal: decimal, gasPrice: gasPrice)
                DispatchQueue.main.async {
                    completion(txHash)
                }
            }
        }
    }
}
