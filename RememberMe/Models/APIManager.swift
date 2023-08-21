import Foundation
import Alamofire

class APIManager {
    static let shared = APIManager()
    private let openAIURL = "https://api.openai.com/v1"
    private let apiKey = "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"

    private init() {}

    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        print("Transcribing audio from file URL: \(fileURL)") // Print the file URL

        let headers: HTTPHeaders = [
            "Authorization": "Bearer \(apiKey)"
        ]

        let url = "\(openAIURL)/audio/transcriptions"

        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileURL, withName: "file")
            multipartFormData.append("whisper-1".data(using: .utf8)!, withName: "model")
        }, to: url, headers: headers).responseJSON { response in
            switch response.result {
            case .success(let value):
                print("Success response:", value) // Print the success response
                if let json = value as? [String: Any], let transcription = json["transcription"] as? String {
                    completion(.success(transcription))
                } else {
                    print("JSON Parsing Error:", response.data ?? "No data") // Print the raw response data
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            case .failure(let error):
                print("Failure response:", error.localizedDescription) // Print the error description
                print("Response:", response.data ?? "No data") // Print the raw response data
                completion(.failure(error))
            }
        }
    }
}
