import Alamofire

class APIManager {
    static let shared = APIManager()

    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let serverURL = URL(string: "http://your-backend-server.com/transcribe")!
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileURL, withName: "audio")
        }, to: serverURL).responseJSON { response in
            if let json = response.value as? [String: Any], let transcription = json["transcription"] as? String {
                completion(.success(transcription))
            } else {
                completion(.failure(NSError(domain: "Transcription failed", code: -1, userInfo: nil)))
            }
        }
    }
}
