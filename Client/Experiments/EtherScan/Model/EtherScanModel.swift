// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import SwiftUI

public struct ApiResponse: Codable {
    let status: String
    let message: String
    let result: [Transaction]
}

public struct Transaction: Codable, Hashable {
    let blockNumber: String
    let timeStamp: String
    let hash: String
    let nonce: String
    let blockHash: String
    let transactionIndex: String
    let from: String
    let to: String
    let value: String
    let gas: String
    let gasPrice: String
    let isError: String
    let txreceipt_status: String
    let input: String
    let contractAddress: String
    let cumulativeGasUsed: String
    let gasUsed: String
    let confirmations: String
    let methodId: String
    let functionName: String
}

extension Transaction {
    func date() -> Date? {
        guard let timeInterval = Double(timeStamp) else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    func ethAmount() -> Double? {
        guard let gwei = Double(value) else { return nil }
        return gwei / 1_000_000_000_000_000_000
    }
    
    func ethAmountFormatted() -> String? {
        guard let eth = ethAmount() else { return nil }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        
        guard let formatted = formatter.string(from: NSNumber(value: eth)) else { return nil}
        
        return "\(formatted) ETH"
    }
    
    func fromPreview() -> String {
        from.prefix(4) + "..." + from.suffix(4)
    }
    
    func toPreview() -> String {
        to.prefix(4) + "..." + to.suffix(4)
    }
    
    func description(address: String) -> String {
        (isOutgoing(address: address) ? "Sent" : "Received") +  " \(ethAmountFormatted() ?? "")"
    }
    
    func secondaryDescription(address: String) -> String {
        isOutgoing(address: address) ? toPreview() : fromPreview()
    }
    
    func isOutgoing(address: String) -> Bool {
        from.compare(address, options: .caseInsensitive) == .orderedSame
    }
    
    func image(address: String) -> Image {
        isOutgoing(address: address) ? Asset.arrowNarrowRight.swiftUIImage : Asset.arrowNarrowLeft.swiftUIImage
    }
}
