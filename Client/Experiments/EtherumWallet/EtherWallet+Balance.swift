// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core

public protocol BalanceService {
    func etherBalanceSync() async throws -> String
    func etherBalance(completion: @escaping (String?) -> ())
    func tokenBalanceSync(contractAddress: String) async throws -> String
    func tokenBalance(contractAddress: String, completion: @escaping (String?) -> ())
}

extension EtherWallet: BalanceService {
    public func etherBalanceSync() async throws -> String {
        guard let address = address else { throw WalletError.accountDoesNotExist }
        guard let ethereumAddress = EthereumAddress(address) else { throw WalletError.invalidAddress }
        
        guard let balanceInWei = try? await Web3.InfuraMainnetWeb3().eth.getBalance(for: ethereumAddress) else {
            throw WalletError.networkFailure
        }
        
        let balanceInEtherUnitStr = Utilities.formatToPrecision(balanceInWei, formattingDecimals: 8, decimalSeparator: ".", fallbackToScientific: false)
        
        return balanceInEtherUnitStr
    }
    
    public func etherBalance(completion: @escaping (String?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let balance = try? await self.etherBalanceSync()
                DispatchQueue.main.async {
                    completion(balance)
                }
            }
        }
    }
    
    public func tokenBalanceSync(contractAddress: String) async throws -> String {
        let contractEthreumAddress = EthereumAddress(contractAddress)
        guard let contract = try await Web3.InfuraMainnetWeb3().contract(Web3.Utils.erc20ABI, at: contractEthreumAddress) else { throw
            WalletError.invalidAddress
        }
        guard let address = address else { throw WalletError.accountDoesNotExist }
        
        let balance = try await contract.web3.eth.getBalance(for: contractEthreumAddress!)
        
        return "\(balance)"
    }
    
    public func tokenBalance(contractAddress: String, completion: @escaping (String?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let balance = try? await self.tokenBalanceSync(contractAddress: contractAddress)
                DispatchQueue.main.async {
                    completion(balance)
                }
            }
        }
    }
}
