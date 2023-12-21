// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

public enum WalletError: Error, LocalizedError {
    case accountDoesNotExist
    case invalidPath
    case invalidKey
    case invalidMnemonics
    case invalidAddress
    case malformedKeystore
    case networkFailure
    case conversionFailure
    case notEnoughBalance
    case contractFailure
    case unexpectedResult
    
    public var errorDescription: String? {
        switch self {
        case .accountDoesNotExist:
            return "Account does not exist"
        case .invalidPath:
            return "Invalid key path"
        case .invalidKey:
            return "Invalid key"
        case .invalidMnemonics:
            return "Invalid mnemonics"
        case .invalidAddress:
            return "Invalid address"
        case .malformedKeystore:
            return "Malformed keystore"
        case .networkFailure:
            return "Network failure"
        case .conversionFailure:
            return "Conversion failure"
        case .notEnoughBalance:
            return "Not enough balance"
        case .contractFailure:
            return "Contract failure"
        case .unexpectedResult:
            return "Unexpected result"
        }
    }
}
