// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

public enum WalletError: Error {
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
}
