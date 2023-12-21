// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift
import Web3Core
import BigInt

public class EtherWallet {
    private static let shared = EtherWallet()
    public static let account: AccountService = EtherWallet.shared
    public static let balance: BalanceService = EtherWallet.shared
    public static let info: InfoService = EtherWallet.shared
    public static let transaction: TransactionService = EtherWallet.shared
    public static let history: HistoryService = EtherWallet.shared
    public static let util: UtilService = EtherWallet.shared
    public static let etherScanAPI = EtherScanAPI.shared
    public static let etherPriceApi = CoinGecoAPI.shared
    
//    private let web3Main = Web3.InfuraMainnetWeb3()
    let keystoreDirectoryName = "/keystore"
    let keystoreFileName = "/key.json"
    let mnemonicsKeystoreKey = "mnemonicsKeystoreKey"
    let defaultGasLimitForTokenTransfer = 100000
    
//    var options: Web3Options
//    var transactionOptions: TransactionOptions
    var keystoreCache: EthereumKeystoreV3?
    
//    var web3Instance: Web3 {
//        return web3Main
//    }
    
    private init() {
//        options = Web3
//        options.gasLimit = BigUInt(defaultGasLimitForTokenTransfer)
//        
//        transactionOptions = TransactionOptions.defaultOptions
//        transactionOptions.gasLimit = .limited(BigUInt(defaultGasLimitForTokenTransfer))
        
        setupOptionsFrom()
    }
    
    func setupOptionsFrom() {
        //        if let address = address {
        //            options.from = EthereumAddress(address)
        //            transactionOptions.from = EthereumAddress(address)
        //        } else {
        //            options.from = nil
        //            transactionOptions.from = nil
        //        }
    }
}


