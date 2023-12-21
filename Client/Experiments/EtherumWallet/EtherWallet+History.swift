// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import web3swift

public protocol HistoryService {
    func getTransactionList(for address: String) async throws -> [Transaction]
    func getEthPrice() async throws -> EthPriceResponse
}

extension EtherWallet: HistoryService {
    public func getTransactionList(for address: String) async throws -> [Transaction] {
        return try await EtherWallet.etherScanAPI.getTransactionList(for: address)
    }
    
    public func getEthPrice() async throws -> EthPriceResponse {
        return try await EtherWallet.etherPriceApi.getEthPrice()
    }
}
