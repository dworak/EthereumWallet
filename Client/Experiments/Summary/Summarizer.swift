// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

internal class Summarizer {    
    class func summarizeWithStream(text: String, completion: @escaping (String) -> Void) {
        Task {
            do {
                let stream = try await GPTAPI.askWithStream(text)
                var all = ""
                for try await line in stream {
                    all += line
                    completion(all)
                }
            } catch {
                print(error.localizedDescription)
            }
        }
    }
    
    class func summarize(text: String, completion: @escaping (String) -> Void) {
        GPTAPI.ask(text, completion: completion)
    }
}
