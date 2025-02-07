import Foundation

actor LumaAIService {
    // MARK: - Types
    struct ReferenceImage: Codable {
        let url: String
        let prompt: String?
        let weight: Double
    }
    
    enum LumaError: LocalizedError {
        case invalidURL
        case invalidResponse
        case requestFailed(String)
        case generationFailed(String)
        case generationTimeout
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid URL"
            case .invalidResponse:
                return "Invalid response from server"
            case .requestFailed(let message):
                return "Request failed: \(message)"
            case .generationFailed(let message):
                return "Generation failed: \(message)"
            case .generationTimeout:
                return "Generation timed out"
            }
        }
    }
    
    struct GenerationRequest: Encodable {
        let prompt: String
        let image_ref: [ReferenceImage]?
        let character_ref: [String: CharacterIdentity]?
        let model: String = "photon-1"
        let aspect_ratio: String = "1:1"
        let num_images: Int
        let guidance_scale: Double
        let steps: Int
        let negative_prompt: String = "blurry, low quality, distorted, deformed"
    }
    
    struct CharacterIdentity: Encodable {
        let images: [String]
    }
    
    struct GenerationResponse: Decodable {
        let id: String
        let state: String
        let images: [String]?
        let error: String?
        let failure_reason: String?
        let assets: Assets?
        
        struct Assets: Decodable {
            let image: String?
            let images: [String]?
            let video: String?
        }
        
        var allImages: [String] {
            if let images = assets?.images, !images.isEmpty {
                return images
            } else if let image = assets?.image {
                return [image]
            } else if let images = images, !images.isEmpty {
                return images
            }
            return []
        }
    }
    
    // MARK: - Constants
    private enum Constants {
        static let baseUrl = "https://api.lumalabs.ai/dream-machine/v1"
        static let apiKey = "luma-06baadf0-2cd5-4248-828b-4fe02a133104-cef3cdb8-b368-445c-81c6-fd6f877d332d"
    }
    
    // MARK: - Properties
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    // MARK: - Initialization
    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    // MARK: - Public Methods
    func generateImage(
        prompt: String,
        references: [ReferenceImage]? = nil,
        characterReferences: [String]? = nil,
        numOutputs: Int = 4,
        guidanceScale: Double = 12.0,
        steps: Int = 50
    ) async throws -> [String] {
        print("DEBUG: Starting image generation with prompt: \(prompt)")
        
        // Validate reference URLs
        if let refs = references {
            for ref in refs {
                guard let url = URL(string: ref.url), url.scheme != nil else {
                    throw LumaError.requestFailed("Invalid reference image URL: \(ref.url)")
                }
            }
        }
        
        if let charRefs = characterReferences {
            for ref in charRefs {
                guard let url = URL(string: ref), url.scheme != nil else {
                    throw LumaError.requestFailed("Invalid character reference URL: \(ref)")
                }
            }
        }
        
        // Adjust reference weights to be more conservative
        let adjustedReferences = references?.map { ref in
            ReferenceImage(
                url: ref.url,
                prompt: ref.prompt,
                weight: min(max(ref.weight, 0.3), 0.7) // Ensure weight is between 0.3 and 0.7
            )
        }
        
        var uniqueImages = Set<String>()
        var attempts = 0
        let maxAttempts = 4 // Maximum number of attempts to get unique images
        
        while uniqueImages.count < numOutputs && attempts < maxAttempts {
            // Create generation with enhanced prompt
            let generationId = try await createGeneration(
                prompt: prompt,
                references: adjustedReferences,
                characterReferences: characterReferences,
                numOutputs: 1,
                guidanceScale: min(guidanceScale, 15.0), // Cap guidance scale
                steps: min(max(steps, 40), 60) // Ensure steps are between 40 and 60
            )
            print("DEBUG: Generation created with ID: \(generationId)")
            
            // Poll for completion
            let images = try await pollGeneration(id: generationId)
            uniqueImages.formUnion(images)
            
            attempts += 1
            print("DEBUG: Attempt \(attempts): Got \(images.count) images, total unique: \(uniqueImages.count)")
            
            if uniqueImages.count < numOutputs {
                // Add a small delay between requests
                try await Task.sleep(for: .seconds(2)) // Increased delay
            }
        }
        
        let finalImages = Array(uniqueImages.prefix(numOutputs))
        print("DEBUG: Generation completed with \(finalImages.count) unique images")
        return finalImages
    }
    
    // MARK: - Private Methods
    private func createGeneration(
        prompt: String,
        references: [ReferenceImage]?,
        characterReferences: [String]?,
        numOutputs: Int,
        guidanceScale: Double,
        steps: Int
    ) async throws -> String {
        guard let url = URL(string: "\(Constants.baseUrl)/generations/image") else {
            throw LumaError.invalidURL
        }
        
        // Enhance prompt with quality modifiers
        var enhancedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if !enhancedPrompt.lowercased().contains("high quality") {
            enhancedPrompt += ", high quality"
        }
        if !enhancedPrompt.lowercased().contains("detailed") {
            enhancedPrompt += ", detailed"
        }
        if !enhancedPrompt.lowercased().contains("professional") {
            enhancedPrompt += ", professional"
        }
        
        // Add some randomness to the prompt to encourage variation
        let randomSeed = Int.random(in: 1...1000000)
        let promptWithSeed = "\(enhancedPrompt) #seed:\(randomSeed)"
        
        // Format character references according to API spec
        let formattedCharacterRefs: [String: CharacterIdentity]? = characterReferences.map { urls in
            ["identity0": CharacterIdentity(images: urls)]
        }
        
        // Create request
        let request = GenerationRequest(
            prompt: promptWithSeed,
            image_ref: references,
            character_ref: formattedCharacterRefs,
            num_images: numOutputs,
            guidance_scale: guidanceScale,
            steps: steps
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let encodedData = try encoder.encode(request)
            urlRequest.httpBody = encodedData
            
            // Add debug logging
            print("DEBUG: Sending request to URL: \(url.absoluteString)")
            if let requestBody = String(data: encodedData, encoding: .utf8) {
                print("DEBUG: Request body: \(requestBody)")
            }
        } catch {
            throw LumaError.requestFailed("Failed to encode request: \(error.localizedDescription)")
        }
        
        // Send request with error handling
        let (data, response) = try await session.data(for: urlRequest)
        
        // Add debug logging for response
        print("DEBUG: Response status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("DEBUG: Response body: \(responseBody)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaError.invalidResponse
        }
        
        // Handle response status codes
        switch httpResponse.statusCode {
        case 200, 201:
            let generationResponse = try decoder.decode(GenerationResponse.self, from: data)
            
            // Check for immediate failure
            if let failureReason = generationResponse.failure_reason {
                throw LumaError.generationFailed(failureReason)
            }
            
            if generationResponse.state == "failed" {
                throw LumaError.generationFailed(generationResponse.error ?? "Generation failed immediately")
            }
            
            return generationResponse.id
            
        case 400...499:
            // Client error
            if let error = try? decoder.decode(GenerationResponse.self, from: data) {
                throw LumaError.requestFailed(error.error ?? error.failure_reason ?? "Client error \(httpResponse.statusCode)")
            }
            throw LumaError.requestFailed("Request failed with status code \(httpResponse.statusCode)")
            
        case 500...599:
            // Server error
            throw LumaError.requestFailed("Server error: \(httpResponse.statusCode)")
            
        default:
            throw LumaError.requestFailed("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
    
    private func pollGeneration(id: String) async throws -> [String] {
        guard let url = URL(string: "\(Constants.baseUrl)/generations/\(id)") else {
            throw LumaError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        
        // Poll with exponential backoff
        var attempt = 0
        let maxAttempts = 30 // 5 minutes total with exponential backoff
        
        while attempt < maxAttempts {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Add debug logging for polling
            print("DEBUG: Polling response: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LumaError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let error = try? decoder.decode(GenerationResponse.self, from: data)
                throw LumaError.requestFailed(error?.error ?? "Unknown error")
            }
            
            let generationResponse = try decoder.decode(GenerationResponse.self, from: data)
            
            if let failureReason = generationResponse.failure_reason {
                throw LumaError.generationFailed(failureReason)
            }
            
            switch generationResponse.state {
            case "completed":
                let images = generationResponse.allImages
                if !images.isEmpty {
                    return images
                } else {
                    throw LumaError.generationFailed("No images in completed response")
                }
            case "failed":
                throw LumaError.generationFailed(generationResponse.failure_reason ?? "Generation failed")
            case "queued", "processing", "dreaming":
                // Continue polling
                break
            default:
                print("DEBUG: Unknown state: \(generationResponse.state)")
            }
            
            // Exponential backoff with jitter
            let baseDelay = Double(1 << min(attempt, 6)) // Max 64 seconds
            let jitter = Double.random(in: 0...0.5)
            let delay = baseDelay + jitter
            
            try await Task.sleep(for: .seconds(delay))
            attempt += 1
        }
        
        throw LumaError.generationTimeout
    }
    
    private func deleteGeneration(id: String) async throws {
        guard let url = URL(string: "\(Constants.baseUrl)/generations/\(id)") else {
            throw LumaError.invalidURL
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(Constants.apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let error = try? decoder.decode(GenerationResponse.self, from: data)
            throw LumaError.requestFailed(error?.error ?? "Unknown error")
        }
    }
} 