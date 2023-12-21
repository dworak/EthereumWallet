// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    // Add more HTTP methods as needed
}

public class EtherScanAPI {
    static let shared = EtherScanAPI()
    
    let baseURL = "https://api.etherscan.io/api"
    
    struct Constants {
        static let apiKey = ""
    }
    
    private init() {}
    
    private func fetchData(url: URL, completion: @escaping (Result<ApiResponse, Error>) -> Void) {
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
                    let apiResponse = try decoder.decode(ApiResponse.self, from: data)
                    completion(.success(apiResponse))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    private func request(url: URL, method: HTTPMethod, parameters: [String: Any]? = nil, completion: @escaping (Result<ApiResponse, Error>) -> Void) {
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
                    let apiResponse = try decoder.decode(ApiResponse.self, from: data)
                    completion(.success(apiResponse))
                } catch {
                    completion(.failure(error))
                }
            }
        }
        
        task.resume()
    }
    
    func fetchDataAsync(url: URL) async throws -> ApiResponse {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ApiResponse, Error>) in
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

extension EtherScanAPI {
    func transactionUrl(for address: String) -> URL {
        return URL(string: "\(baseURL)?module=account&action=txlist&address=\(address)&startblock=0&endblock=latest&sort=desc&apikey=\(Constants.apiKey)")!
    }
    
    func getTransactionList(for address: String, completion: @escaping (Result<ApiResponse, Error>) -> Void) {
        request(url: transactionUrl(for: address), method: .get, completion: completion)
    }
    
    func getTransactionList(for address: String) async throws -> [Transaction] {
        return try await fetchDataAsync(url: transactionUrl(for: address)).result
    }
}
