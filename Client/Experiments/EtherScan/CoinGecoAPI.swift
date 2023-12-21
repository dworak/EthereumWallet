// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

public class CoinGecoAPI {
    static let shared = CoinGecoAPI()
    
    let baseURL = "https://api.coingecko.com/api/v3/simple/"

    
    struct Constants {
        static let apiKey = ""
    }
    
    private init() {}
    
    private func fetchData(url: URL, completion: @escaping (Result<EthPriceResponse, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: url) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let error = NSError(domain: "NetworkError", code: statusCode, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let apiResponse = try decoder.decode(EthPriceResponse.self, from: data)
                    completion(.success(apiResponse))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    private func request(url: URL, method: HTTPMethod, parameters: [String: Any]? = nil, completion: @escaping (Result<EthPriceResponse, Error>) -> Void) {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        
        if let parameters = parameters {
            request.httpBody = try? JSONSerialization.data(withJSONObject: parameters)
        }
        
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
                let error = NSError(domain: "NetworkError", code: statusCode, userInfo: nil)
                completion(.failure(error))
                return
            }
            
            if let data = data {
                do {
                    let decoder = JSONDecoder()
                    let apiResponse = try decoder.decode(EthPriceResponse.self, from: data)
                    completion(.success(apiResponse))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func fetchDataAsync(url: URL) async throws -> EthPriceResponse {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EthPriceResponse, Error>) in
            fetchData(url: url) { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

extension CoinGecoAPI {
    private func ehtPriceUrl() -> URL {
        return URL(string: "\(baseURL)price?ids=ethereum&vs_currencies=usd")!
    }
    
    func getEthPrice(completion: @escaping (Result<EthPriceResponse, Error>) -> Void) {
        request(url: ehtPriceUrl(), method: .get, completion: completion)
    }
    
    func getEthPrice() async throws -> EthPriceResponse {
        return try await fetchDataAsync(url: ehtPriceUrl())
    }
}
