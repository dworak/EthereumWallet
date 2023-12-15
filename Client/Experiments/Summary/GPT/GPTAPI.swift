// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation


enum GPTAPI {
    struct Constants {
        #warning("Please add your API_KEY")
        static let apiKey = ""
        static let organizationId = "org-8Gv3r6kesNowTuOqLxMH0tOC"
        static let model =  "gpt-3.5-turbo"
    }
    
    static let apiURL = "https://api.openai.com/v1/chat/completions"
}

extension GPTAPI {
    static func ask(_ text: String, completion: @escaping (String) -> Void) {
        guard let apiUrl = URL(string: "https://api.openai.com/v1/chat/completions") else {
            debugPrint("Invalid API URL")
            return
        }
        
        let apiKey = Constants.apiKey
        
        var request = URLRequest(url: apiUrl)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        
        let message = Messages(role: "user", content: "Summarize this text \(text)")
        
        let requestData = RequestData(model: Constants.model, messages: [message])
        
        let encoder = JSONEncoder()
        
        guard let httpBody = try? encoder.encode(requestData) else {
            debugPrint("Error encoding JSON data")
            return
        }
        
        request.httpBody = httpBody
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                debugPrint("Error: \(error)")
                return
            }
            
            guard let data = data else {
                debugPrint("No data received")
                return
            }
            
            do {
                let decodedResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
                completion(decodedResponse.resultText)
            } catch let error {
                debugPrint("Error decoding: ", error)
                completion(String(data: data, encoding: .utf8) ?? "")
            }
        }
        
        task.resume()
    }
    
    static func askWithStream(_ problem: String) async throws -> AsyncThrowingStream<String, Swift.Error> {
        let messages: [[String: Any]] = [
            [
                "role": "user",
                "content": problem
            ],
        ]
        
        let json: [String: Any] = [
            "model": Constants.model,
            "messages": messages,
            "temperature": 0.5,
            "stream": true
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: json) else {
            throw "Wrong parameters"
        }
        
        let url = URL(string: apiURL)!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (result, rsp) = try await URLSession.shared.bytes(for: request)
        
        guard let response = rsp as? HTTPURLResponse else {
            throw "Network Error"
        }
        
        guard 200...299 ~= response.statusCode else {
            throw "Invalid response"
        }
        
        return AsyncThrowingStream<String, Swift.Error> { continuation in
            Task(priority: .userInitiated) {
                do {
                    for try await line in result.lines {
                        
                        guard line.hasPrefix("data: "),
                              let data = line.dropFirst(6).data(using: .utf8)
                        else {
                            continue
                        }
                        
                        let jsonDecoder = JSONDecoder()
                        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
                        
                        
                        if let content = try? jsonDecoder.decode(StreamCompletionResponse.self, from: data) {
                            continuation.yield(content.choices.first?.delta.content ?? "")
                        }
                        
                        if let finishReason = try? jsonDecoder.decode(TranslationResponse.self, from: data), finishReason.choices.first?.finish_reason == "stop" {
                            break
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
                
                continuation.onTermination = { @Sendable status in
                    print("Stream terminated with status: \(status)")
                }
            }
        }
    }
}
