// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core

public protocol InfoService {
    func decimalsForTokenSync(address: String) async throws -> Int
    func decimalsForToken(address: String, completion: @escaping (Int?) -> ())
    func symbolForTokenSync(address: String) async throws -> String
    func symbolForToken(address: String, completion: @escaping (String?) -> ())
}

extension EtherWallet: InfoService {
    public func decimalsForTokenSync(address: String) async throws -> Int {
        let contract = try await erc20contract(address: address)
        let parameters = [AnyObject]()
        
        guard 
            let decimalsInfo = try? await contract.createReadOperation("decimals", parameters: parameters, extraData: Data())?.callContractMethod(),
            let decimals = decimalsInfo["0"]
        else {
            throw WalletError.networkFailure
        }
        
        guard let result = decimals as? Int else {
            throw WalletError.unexpectedResult
        }
        
        return result
    }
    
    public func decimalsForToken(address: String, completion: @escaping (Int?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let decimals = try? await self.decimalsForTokenSync(address: address)
                DispatchQueue.main.async {
                    completion(decimals)
                }
            }
        }
    }
    
    public func symbolForTokenSync(address: String) async throws -> String {
        let contract = try await erc20contract(address: address)
        let parameters = [AnyObject]()
        
        guard let symbolInfo = try? await contract.createReadOperation("symbol", parameters: parameters, extraData: Data())?.callContractMethod(), let symbol = symbolInfo["0"] as? String else {
            throw WalletError.networkFailure
        }
        
        if symbol.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) != nil {
            throw WalletError.unexpectedResult
        }
        
        return symbol
    }
    
    
    public func symbolForToken(address: String, completion: @escaping (String?) -> ()) {
        DispatchQueue.global().async {
            Task {
                let symbol = try? await self.symbolForTokenSync(address: address)
                DispatchQueue.main.async {
                    completion(symbol)
                }
            }
        }
    }
    
    private func erc20contract(address: String) async throws -> Web3.Contract {
        let contractEthreumAddress = EthereumAddress(address)
        guard let contract = try await Web3.InfuraMainnetWeb3().contract(Web3.Utils.erc20ABI, at: contractEthreumAddress) else { throw WalletError.contractFailure }
        
        return contract
    }
}
