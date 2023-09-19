import Alamofire

class APIManager {
    static let shared = APIManager()
    
    struct TranscriptionResponse: Decodable {
        let transcription: String?
    }

    func transcribeAudio(fileURL: URL, completion: @escaping (Result<String, Error>) -> Void) {
        let serverURL = URL(string: "https://will-site-dc0779429fbc.herokuapp.com/transcribe_audio")!
        
        print("Starting transcription API call.")  // Debugging line
        
        AF.upload(multipartFormData: { multipartFormData in
            multipartFormData.append(fileURL, withName: "audio")
        }, to: serverURL)
        .uploadProgress { progress in
            print("Upload Progress: \(progress.fractionCompleted)")  // Debugging line
        }
        .responseDecodable(of: TranscriptionResponse.self) { response in
            print("Received API response.")  // Debugging line
            
            if let error = response.error {
                print("API request error: \(error)")  // Debugging line
                completion(.failure(error))
                return
            }
            
            if let transcription = response.value?.transcription {
                print("API request successful. Transcription received.")  // Debugging line
                completion(.success(transcription))
            } else {
                print("API request failed. Transcription not received.")  // Debugging line
                completion(.failure(NSError(domain: "Transcription failed", code: -1, userInfo: nil)))
            }
        }
    }
}
