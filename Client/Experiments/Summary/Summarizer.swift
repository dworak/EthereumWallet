// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import NaturalLanguage
import WebKit

internal class Summarizer {
    
    struct Constants {
        #warning("Please add your API_KEY")
        static let apiKey = ""
        static let model =  "gpt-3.5-turbo"
    }
    
    class func summarize(text: String, completion: @escaping (String) -> Void) {
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
            
            DispatchQueue.main.async {
                do {
                    let decodedResponse = try JSONDecoder().decode(TranslationResponse.self, from: data)
                    completion(decodedResponse.resultText)
                } catch let error {
                    debugPrint("Error decoding: ", error)
                    completion(String(data: data, encoding: .utf8) ?? "")
                }
            }
        }
        
        task.resume()
    }
    
    func summerizeTextWithNLP(_ text: String) {
        let tagger = NLTagger(tagSchemes: [.tokenType, .language, .lexicalClass, .sentimentScore])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        let range = text.startIndex..<text.endIndex
        
        tagger.enumerateTags(in: range, unit: .paragraph, scheme: .sentimentScore) { tag, tokenRange in
            if let tag = tag {
                debugPrint("Sentiment: \(tag.rawValue)")
            }
            return true
        }
        
        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        
        sentenceTokenizer.enumerateTokens(in: range) { (tokenRange, _) in
            let sentence = String(text[tokenRange])
            let sentenceAnalysis = sentenceAnalysis(sentence)
            debugPrint("Sentence: \(sentence)")
            debugPrint("Analysis: \(sentenceAnalysis)")
            debugPrint("---")
            return true
        }
    }
    
    func sentenceAnalysis(_ sentence: String) -> String {
        let tagger = NLTagger(tagSchemes: [.tokenType, .language, .lexicalClass])
        tagger.string = sentence
        
        var keywords = [String]()
        
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .omitOther]
        
        tagger.enumerateTags(in: sentence.startIndex..<sentence.endIndex, unit: .word, scheme: .nameTypeOrLexicalClass, options: options) { tag, tokenRange in
            if let tag = tag, tag == .noun {
                keywords.append(String(sentence[tokenRange]))
            }
            return true
        }
        
        let summary = "Keywords: \(keywords.joined(separator: ", "))"
        
        return summary
    }
    
    class func convertHTMLToPlainText(htmlString: String) -> String? {
        guard let data = htmlString.data(using: .utf8) else {
            return nil
        }
        
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        
        do {
            let attributedString = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return attributedString.string
                .trimmed()
                .replacingOccurrences(of: "\n", with: " ")
                .replacingOccurrences(of: "\t", with: " ")
        } catch {
            print("Error converting HTML to plain text: \(error)")
            return nil
        }
    }
    
    class func getContent(from webView: WKWebView, completion: @escaping (String?) -> Void) {
        webView.evaluateJavascriptInDefaultContentWorld("document.documentElement.outerHTML") { response in
            switch response {
            case .success(let result):
                if let html = result as? String, let text = self.convertHTMLToPlainText(htmlString: html) {
                    completion(text)
                }
            case .failure(let error):
                debugPrint(error.localizedDescription)
                completion(nil)
            }
        }
    }
    
}

struct RequestData: Codable {
    var model: String
    var messages: [Messages]
    
}
struct Messages: Codable {
    let role: String
    let content: String
}

struct TranslationResponse: Decodable {
    var id: String
    var object: String
    var created: Int
    var choices: [TextCompletionChoice]
    
    var resultText: String {
        choices.map(\.message.content).joined(separator: "\n")
    }
}

extension TranslationResponse {
    struct TextCompletionChoice: Decodable{
        var index: Int
        var message: Messages
        var finish_reason: String
    }
}

extension String {
    func trimmed() -> String {
        return trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}
