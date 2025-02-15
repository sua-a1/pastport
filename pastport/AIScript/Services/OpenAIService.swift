import Foundation

/// Service for interacting with OpenAI's API
actor OpenAIService {
    // MARK: - Types
    
    /// Errors that can occur during OpenAI operations
    enum OpenAIError: LocalizedError {
        case missingAPIKey
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse
        case generationFailed(String)
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "OpenAI API key is not configured. Please set OPENAI_API_KEY in your environment."
            case .invalidAPIKey:
                return "Invalid OpenAI API key. Please check your API key configuration."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from OpenAI"
            case .generationFailed(let message):
                return "Scene generation failed: \(message)"
            }
        }
    }
    
    /// Structure representing a scene generation request
    struct SceneGenerationRequest: Encodable {
        let model: String = "gpt-4"
        let messages: [Message]
        let temperature: Double = 0.7
        let maxTokens: Int = 2000
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
        
        struct Message: Codable {
            let role: String
            let content: String
        }
    }
    
    /// Structure representing a scene generation response
    struct SceneGenerationResponse: Decodable {
        let id: String
        let choices: [Choice]
        
        struct Choice: Decodable {
            let message: Message
            let finishReason: String
            
            enum CodingKeys: String, CodingKey {
                case message
                case finishReason = "finish_reason"
            }
        }
        
        struct Message: Decodable {
            let role: String
            let content: String
        }
    }
    
    /// Structure representing the generated scenes
    struct GeneratedScenes: Decodable {
        let scriptOverview: String
        let scenes: [SceneContent]
        
        struct SceneContent: Decodable {
            let content: String
            let visualDescription: String
            let startKeyframePrompt: String
            let endKeyframePrompt: String
        }
    }
    
    // MARK: - Constants
    private enum Constants {
        static let baseUrl = "https://api.openai.com/v1/chat/completions"
    }
    
    // MARK: - Properties
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let apiKey: String
    
    // MARK: - Initialization
    init(session: URLSession = .shared) throws {
        self.session = session
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            throw OpenAIError.missingAPIKey
        }
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    
    /// Generate scenes from a story draft
    /// - Parameters:
    ///   - content: The story content
    ///   - referenceTexts: Optional array of reference texts
    ///   - characterDescription: Optional character description
    /// - Returns: Generated scenes with script overview
    func generateScenes(
        content: String,
        referenceTexts: [String]? = nil,
        characterDescription: String? = nil
    ) async throws -> GeneratedScenes {
        print("DEBUG: Starting OpenAI scene generation")
        print("DEBUG: Content length: \(content.count)")
        print("DEBUG: Number of reference texts: \(referenceTexts?.count ?? 0)")
        
        guard !apiKey.isEmpty else {
            throw OpenAIError.missingAPIKey
        }
        
        // Build the system prompt
        var systemPrompt = """
        You are a professional screenwriter and storyboard artist. Your task is to break down a story into exactly 3 distinct scenes \
        that can be visualized. Each scene should be exactly 5 seconds long and have a clear visual description and specific prompts \
        for generating start and end keyframe images. The total video will be exactly 15 seconds long.

        Rules:
        1. Generate EXACTLY 3 scenes - no more, no less
        2. Each scene must be precisely 5 seconds long - write scenes that can be realistically shown in this timeframe
        3. Keep actions simple and focused - one clear motion or transformation per scene
        4. Each scene should be a logical progression of the story
        5. Visual descriptions must explicitly describe dynamic actions, movements, and poses that can be completed in 5 seconds
        6. Start and end keyframes must show clear cause-and-effect progression within the 5-second timeframe
        7. Start keyframes should capture the initiating action or moment
        8. End keyframes should show the culmination or result of the scene's action
        9. Maintain consistency in character appearance while varying poses and expressions
        10. Total story is exactly 15 seconds (3 scenes × 5 seconds each)
        11. Focus on dramatic, visually impactful moments that show clear motion or action
        12. Avoid complex dialogue or multiple simultaneous actions
        13. Write scene descriptions that are concise and action-focused
        14. Provide a concise but powerful overview of the entire script that captures its essence and themes

        Output format:
        Return a JSON object with:
        {
          "scriptOverview": "A concise but powerful overview of the entire script that captures its essence, themes, and visual style",
          "scenes": [
            {
              "content": "Scene description and action (must be achievable in 5 seconds)",
              "visualDescription": "Detailed visual description emphasizing dynamic elements and movements within 5-second timeframe",
              "startKeyframePrompt": "Prompt capturing the initiating action or moment, with specific character poses and expressions",
              "endKeyframePrompt": "Prompt showing the scene's culmination, with clear progression from the start keyframe"
            }
          ]
        }
        """
        
        if let characterDescription = characterDescription {
            systemPrompt += "\n\nCharacter Description:\n\(characterDescription)"
        }
        
        // Build the user prompt
        var userPrompt = content
        
        if let referenceTexts = referenceTexts, !referenceTexts.isEmpty {
            userPrompt += "\n\nReference Material:\n" + referenceTexts.joined(separator: "\n\n")
        }
        
        // Create the request
        let messages = [
            SceneGenerationRequest.Message(role: "system", content: systemPrompt),
            SceneGenerationRequest.Message(role: "user", content: userPrompt)
        ]
        
        let request = SceneGenerationRequest(messages: messages)
        
        // Send request
        let generatedContent = try await sendRequest(request)
        print("DEBUG: Successfully generated content with \(generatedContent.scenes.count) scenes")
        print("DEBUG: Script overview: \(generatedContent.scriptOverview)")
        
        return generatedContent
    }
    
    // MARK: - Private Methods
    
    /// Send a request to the OpenAI API
    private func sendRequest(_ request: SceneGenerationRequest) async throws -> GeneratedScenes {
        guard let url = URL(string: Constants.baseUrl) else {
            print("ERROR: Invalid OpenAI API URL")
            throw OpenAIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let encodedData = try encoder.encode(request)
            urlRequest.httpBody = encodedData
            
            // Add debug logging
            print("DEBUG: Sending request to OpenAI")
            print("DEBUG: API Key length: \(apiKey.count)")
            if let requestBody = String(data: encodedData, encoding: .utf8) {
                print("DEBUG: Request structure: \(requestBody)")
            }
        } catch {
            print("ERROR: Failed to encode request: \(error)")
            throw OpenAIError.networkError(error)
        }
        
        do {
            // Send request with error handling
            print("DEBUG: Sending HTTP request to OpenAI")
            let (data, response) = try await session.data(for: urlRequest)
            
            // Add debug logging for response
            print("DEBUG: Response status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
            if let responseBody = String(data: data, encoding: .utf8) {
                print("DEBUG: Response body: \(responseBody)")
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ERROR: Invalid response type from OpenAI")
                throw OpenAIError.invalidResponse
            }
            
            // Handle response status codes
            switch httpResponse.statusCode {
            case 200:
                print("DEBUG: Successfully received 200 response from OpenAI")
                let generationResponse = try decoder.decode(SceneGenerationResponse.self, from: data)
                
                guard let content = generationResponse.choices.first?.message.content,
                      let jsonData = content.data(using: .utf8) else {
                    print("ERROR: Failed to extract content from OpenAI response")
                    throw OpenAIError.invalidResponse
                }
                
                print("DEBUG: Attempting to decode scenes from response")
                let generatedScenes = try decoder.decode(GeneratedScenes.self, from: jsonData)
                return generatedScenes
                
            case 401:
                print("ERROR: Invalid API key (401)")
                throw OpenAIError.invalidAPIKey
                
            case 400...499:
                print("ERROR: Client error from OpenAI: \(httpResponse.statusCode)")
                throw OpenAIError.generationFailed("Client error: \(httpResponse.statusCode)")
                
            case 500...599:
                print("ERROR: Server error from OpenAI: \(httpResponse.statusCode)")
                throw OpenAIError.generationFailed("Server error: \(httpResponse.statusCode)")
                
            default:
                throw OpenAIError.generationFailed("Unexpected status code: \(httpResponse.statusCode)")
            }
        } catch {
            print("ERROR: Request failed: \(error)")
            throw OpenAIError.networkError(error)
        }
    }
} 