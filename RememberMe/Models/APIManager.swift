//
//  APIManager.swift
//  Namey
//
//  Created by William Misiaszek on 8/21/23.
//

import Foundation
import Alamofire

class APIManager {
    static let shared = APIManager()
    private let openAIURL = "https://api.openai.com/v1"
    private let apiKey = "sk-t1mby9vJ6sx6iIpb5nhf5T3BlbkFJdpAHp69sn4JNsjjDtawL"

    private init() {}

    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
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
                if let json = value as? [String: Any], let transcription = json["transcription"] as? String {
                    completion(.success(transcription))
                } else {
                    completion(.failure(NSError(domain: "", code: -1, userInfo: nil)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
