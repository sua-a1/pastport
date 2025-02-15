import Foundation

actor LumaAIService {
    // MARK: - Types
    
    /// Represents a scene in the story with its content and keyframes
    struct StoryScene {
        let content: String
        let startKeyframe: SceneKeyframe
        let endKeyframe: SceneKeyframe
        
        struct SceneKeyframe {
            let prompt: String?
            let url: String
        }
    }
    
    struct ReferenceImage: Codable {
        let url: String
        let prompt: String?
        let weight: Double
    }
    
    enum LumaAIError: LocalizedError {
        case missingAPIKey
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse
        case generationFailed(String)
        case videoGenerationFailed(String)
        case requestFailed(String)
        case missingVideoURL
        
        var errorDescription: String? {
            switch self {
            case .missingAPIKey:
                return "Luma AI API key is not configured. Please set LUMA_API_KEY in your environment."
            case .invalidAPIKey:
                return "Invalid Luma AI API key. Please check your API key configuration."
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .invalidResponse:
                return "Invalid response from Luma AI"
            case .generationFailed(let message):
                return "Image generation failed: \(message)"
            case .videoGenerationFailed(let message):
                return "Video generation failed: \(message)"
            case .requestFailed(let message):
                return "Request failed: \(message)"
            case .missingVideoURL:
                return "No video URL found in the response"
            }
        }
    }
    
    struct GenerationRequest: Encodable {
        let prompt: String
        let image_ref: [ReferenceImage]?
        let character_ref: [String: CharacterIdentity]?
        let style_ref: [ReferenceImage]?
        let model: String = "photon-1"
        let aspect_ratio: String = "9:16"
        let num_images: Int
        let guidance_scale: Double
        let steps: Int
        let negative_prompt: String = "blurry, low quality, distorted, deformed"
    }
    
    struct CharacterIdentity: Encodable {
        let images: [String]
        let weight: Double
        
        init(images: [String], weight: Double = 0.7) {
            self.images = images
            self.weight = weight
        }
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
    
    /// Request for video generation
    struct VideoGenerationRequest: Codable {
        let prompt: String
        let keyframes: [String: Keyframe]
        let loop: Bool = false
    }
    
    /// Response from video generation
    private struct VideoGenerationResponse: Decodable {
        let id: String
        let state: String
        let error: String?
        let failure_reason: String?
        let assets: Assets?
        
        struct Assets: Decodable {
            let video: String?
        }
    }
    
    /// Keyframe for video generation
    struct Keyframe: Codable {
        let type: String
        let url: String
    }
    
    /// Error response from Luma API
    struct ErrorResponse: Decodable {
        let detail: String
        let error_code: String?
        let failure_reason: String?
    }
    
    // MARK: - Constants
    private enum Constants {
        static let baseUrl = "https://api.lumalabs.ai/dream-machine/v1/generations"
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
        
        guard let apiKey = ProcessInfo.processInfo.environment["LUMA_API_KEY"] else {
            throw LumaAIError.missingAPIKey
        }
        self.apiKey = apiKey
    }
    
    // MARK: - Public Methods
    func generateImage(
        prompt: String,
        references: [ReferenceImage]? = nil,
        characterReferences: [String: CharacterIdentity]? = nil,
        styleReferences: [ReferenceImage]? = nil,
        numOutputs: Int = 4,
        guidanceScale: Double = 12.0,
        steps: Int = 50
    ) async throws -> [String] {
        print("DEBUG: Starting Luma AI image generation")
        print("DEBUG: Prompt: \(prompt)")
        print("DEBUG: Number of reference images: \(references?.count ?? 0)")
        print("DEBUG: Number of character references: \(characterReferences?.count ?? 0)")
        
        guard !apiKey.isEmpty else {
            throw LumaAIError.missingAPIKey
        }
        
        // Validate reference URLs
        if let refs = references {
            for ref in refs {
                guard let url = URL(string: ref.url), url.scheme != nil else {
                    throw LumaAIError.generationFailed("Invalid reference image URL: \(ref.url)")
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
                styleReferences: styleReferences,
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
    
    /// Generate a video using Luma AI
    /// - Parameters:
    ///   - prompt: The prompt describing the video
    ///   - keyframes: Dictionary of keyframes with their URLs
    /// - Returns: URL of the generated video
    func generateVideo(prompt: String, keyframes: [String: Keyframe]) async throws -> URL {
        print("DEBUG: Starting Luma AI video generation")
        print("DEBUG: Keyframes: \(keyframes)")
        
        // Create request
        let request = VideoGenerationRequest(
            prompt: prompt,
            keyframes: keyframes
        )
        
        // Encode request
        let encodedData = try encoder.encode(request)
        
        // Create URL request
        var urlRequest = URLRequest(url: URL(string: Constants.baseUrl)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = encodedData
        
        if let requestBody = String(data: encodedData, encoding: .utf8) {
            print("DEBUG: Request body: \(requestBody)")
        }
        
        // Send initial request
        let (data, response) = try await session.data(for: urlRequest)
        
        if let responseBody = String(data: data, encoding: .utf8) {
            print("DEBUG: Response body: \(responseBody)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LumaAIError.requestFailed("Invalid response status code")
        }
        
        // Decode initial response
        let initialResponse = try decoder.decode(GenerationResponse.self, from: data)
        let generationId = initialResponse.id
        
        // Poll for completion
        let pollingUrl = URL(string: "\(Constants.baseUrl)/\(generationId)")!
        var pollingRequest = URLRequest(url: pollingUrl)
        pollingRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Poll with exponential backoff
        var retryCount = 0
        let maxRetries = 30 // 5 minutes total with exponential backoff
        
        while retryCount < maxRetries {
            print("DEBUG: Polling generation status (attempt \(retryCount + 1))")
            
            let (pollData, pollResponse) = try await session.data(for: pollingRequest)
            
            if let responseBody = String(data: pollData, encoding: .utf8) {
                print("DEBUG: Poll response: \(responseBody)")
            }
            
            guard let pollHttpResponse = pollResponse as? HTTPURLResponse,
                  (200...299).contains(pollHttpResponse.statusCode) else {
                throw LumaAIError.requestFailed("Invalid polling response status code")
            }
            
            let generationStatus = try decoder.decode(GenerationResponse.self, from: pollData)
            
            switch generationStatus.state {
            case "completed":
                guard let videoUrl = generationStatus.assets?.video,
                      let url = URL(string: videoUrl) else {
                    throw LumaAIError.missingVideoURL
                }
                print("DEBUG: Video generation completed successfully")
                return url
                
            case "failed":
                let reason = generationStatus.failure_reason ?? "Unknown error"
                print("DEBUG: Video generation failed: \(reason)")
                throw LumaAIError.videoGenerationFailed(reason)
                
            case "queued", "processing", "dreaming":
                print("DEBUG: Generation still in progress (status: \(generationStatus.state))")
                retryCount += 1
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount))) * 1_000_000_000)
                continue
                
            default:
                throw LumaAIError.requestFailed("Unexpected generation state: \(generationStatus.state)")
            }
        }
        
        throw LumaAIError.requestFailed("Generation timed out after \(maxRetries) retries")
    }
    
    // MARK: - Keyframe Generation Methods
    
    /// Generate a keyframe image for a scene
    /// - Parameters:
    ///   - prompt: The keyframe prompt
    ///   - visualDescription: Additional visual description for context
    ///   - references: Optional array of reference images with weights
    ///   - characterReferences: Optional array of character reference URLs
    ///   - styleReference: Optional style reference image URL for consistency
    ///   - isEndKeyframe: Whether this is an end keyframe
    ///   - scriptOverview: Optional script overview for context
    /// - Returns: URL of the generated keyframe image
    func generateKeyframe(
        prompt: String,
        visualDescription: String,
        references: [ReferenceImage]? = nil,
        characterReferences: [String]? = nil,
        styleReference: String? = nil,
        isEndKeyframe: Bool = false,
        scriptOverview: String? = nil
    ) async throws -> String {
        print("DEBUG: Starting keyframe generation")
        print("DEBUG: Prompt: \(prompt)")
        print("DEBUG: Visual Description: \(visualDescription)")
        print("DEBUG: Is End Keyframe: \(isEndKeyframe)")
        print("DEBUG: Style Reference: \(styleReference ?? "none")")
        print("DEBUG: Character references: \(characterReferences?.count ?? 0)")
        print("DEBUG: Script Overview: \(scriptOverview ?? "none")")
        
        // Format character references
        var formattedCharacterRefs: [String: CharacterIdentity]?
        if let charRefs = characterReferences, !charRefs.isEmpty {
            formattedCharacterRefs = ["identity0": CharacterIdentity(images: charRefs, weight: 0.5)]
            print("DEBUG: Formatted character references with identity0 and weight 0.5: \(String(describing: formattedCharacterRefs))")
        }

        // Prepare references with adjusted weights based on keyframe type
        var imageRefs = references?.map { ref in
            ReferenceImage(
                url: ref.url,
                prompt: ref.prompt,
                weight: 0.5 // Set consistent weight for all references
            )
        }

        // Add style reference if provided
        var styleRefs: [ReferenceImage]?
        if let styleUrl = styleReference {
            styleRefs = [
                ReferenceImage(
                    url: styleUrl,
                    prompt: "maintain consistent style and visual elements",
                    weight: 0.5 // Set style reference weight to 0.5
                )
            ]
        }
        
        // Build enhanced prompt for keyframe
        var enhancedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add script overview context if available
        if let overview = scriptOverview {
            enhancedPrompt += "\n\nScript Context: \(overview)"
        }
        
        enhancedPrompt += "\n\nVisual Context: \(visualDescription)"
        
        if isEndKeyframe {
            enhancedPrompt += "\nThis is the end keyframe of the scene, showing the final state. "
            enhancedPrompt += "Capture the essential outcome with absolute minimal complexity. "
            enhancedPrompt += "Focus on the main subject, maintaining exact character appearance."
        } else {
            enhancedPrompt += "\nThis is the start keyframe of the scene, establishing the initial state. "
            enhancedPrompt += "Show characters/objects in a clear, static pose. "
            enhancedPrompt += "Keep the composition simple and focused on essential elements only."
        }

        enhancedPrompt += "\n\nTechnical Requirements:"
        enhancedPrompt += "\n- Clear, sharp details with minimal artifacts"
        enhancedPrompt += "\n- Simple, uncluttered backgrounds"
        enhancedPrompt += "\n- Maximum 1-2 characters/elements"
        enhancedPrompt += "\n- No floating or partial elements"
        enhancedPrompt += "\n- Strong contrast between subjects and background"
        enhancedPrompt += "\n- Centered composition"
        enhancedPrompt += "\n- Essential elements only"
        enhancedPrompt += "\n- Single clear action or pose"
        enhancedPrompt += "\n- Exact character appearance"
        enhancedPrompt += "\n- Static pose"
        enhancedPrompt += "\n- Consistent lighting"
        
        // Add quality and dynamism modifiers
        if !enhancedPrompt.lowercased().contains("high quality") {
            enhancedPrompt += ", high quality"
        }
        if !enhancedPrompt.lowercased().contains("detailed") {
            enhancedPrompt += ", detailed"
        }
        if !enhancedPrompt.lowercased().contains("professional") {
            enhancedPrompt += ", professional"
        }
        if !enhancedPrompt.lowercased().contains("dynamic") {
            enhancedPrompt += ", dynamic composition"
        }
        if !enhancedPrompt.lowercased().contains("dramatic") {
            enhancedPrompt += ", dramatic lighting"
        }
        
        // Generate the keyframe
        let generatedUrls = try await generateImage(
            prompt: enhancedPrompt,
            references: imageRefs,
            characterReferences: formattedCharacterRefs,
            styleReferences: styleRefs,
            numOutputs: 1,
            guidanceScale: 12.0,
            steps: 50
        )
        
        guard let keyframeUrl = generatedUrls.first else {
            throw LumaAIError.generationFailed("No keyframe was generated")
        }
        
        print("DEBUG: Successfully generated keyframe: \(keyframeUrl)")
        return keyframeUrl
    }
    
    /// Generate both start and end keyframes for a scene
    /// - Parameters:
    ///   - startPrompt: The prompt for the start keyframe
    ///   - endPrompt: The prompt for the end keyframe
    ///   - visualDescription: Visual description of the scene
    ///   - references: Optional array of reference images
    ///   - characterReferences: Optional array of character reference URLs
    ///   - previousSceneEndKeyframe: Optional URL of the previous scene's end keyframe
    ///   - scriptOverview: Optional script overview for context
    /// - Returns: Tuple containing URLs for start and end keyframes
    func generateSceneKeyframes(
        startPrompt: String,
        endPrompt: String,
        visualDescription: String,
        references: [ReferenceImage]? = nil,
        characterReferences: [String]? = nil,
        previousSceneEndKeyframe: String? = nil,
        scriptOverview: String? = nil
    ) async throws -> (start: String, end: String) {
        print("DEBUG: Starting scene keyframes generation")
        print("DEBUG: Previous scene end keyframe: \(previousSceneEndKeyframe ?? "none")")
        print("DEBUG: Character references: \(characterReferences?.count ?? 0)")
        print("DEBUG: Script Overview: \(scriptOverview ?? "none")")
        
        // Generate start keyframe, using previous scene's end keyframe as style reference if available
        let startKeyframe = try await generateKeyframe(
            prompt: startPrompt,
            visualDescription: visualDescription,
            references: references,
            characterReferences: characterReferences,
            styleReference: previousSceneEndKeyframe,
            isEndKeyframe: false,
            scriptOverview: scriptOverview
        )
        
        // Generate end keyframe using start keyframe as style reference for consistency
        let endKeyframe = try await generateKeyframe(
            prompt: endPrompt,
            visualDescription: visualDescription,
            references: references,
            characterReferences: characterReferences,
            styleReference: startKeyframe, // Always use start keyframe as style reference
            isEndKeyframe: true,
            scriptOverview: scriptOverview
        )
        
        return (start: startKeyframe, end: endKeyframe)
    }
    
    // MARK: - Scene Video Generation
    
    /// Generate a video for a scene using the start and end keyframes
    /// - Parameters:
    ///   - scene: The scene to generate video for
    ///   - startKeyframe: The starting keyframe
    ///   - endKeyframe: The ending keyframe
    ///   - visualDescription: Visual style description
    /// - Returns: URL of the generated video
    func generateSceneVideo(
        scene: StoryScene,
        startKeyframe: Keyframe,
        endKeyframe: Keyframe,
        visualDescription: String
    ) async throws -> URL {
        // Create a simplified, focused prompt
        let prompt = "\(scene.content) \(visualDescription)"
        
        // Create keyframes dictionary
        let keyframes: [String: Keyframe] = [
            "frame0": .init(type: "image", url: startKeyframe.url),
            "frame1": .init(type: "image", url: endKeyframe.url)
        ]
        
        print("DEBUG: Generating video for scene with prompt: \(prompt)")
        
        // Generate the video
        return try await generateVideo(
            prompt: prompt,
            keyframes: keyframes
        )
    }
    
    /// Get the API key for making Luma AI API requests
    func getApiKeyForRequest() -> String {
        return apiKey
    }
    
    // MARK: - Private Methods
    private func createGeneration(
        prompt: String,
        references: [ReferenceImage]?,
        characterReferences: [String: CharacterIdentity]?,
        styleReferences: [ReferenceImage]? = nil,
        numOutputs: Int,
        guidanceScale: Double,
        steps: Int
    ) async throws -> String {
        print("DEBUG: Creating generation with prompt: \(prompt)")
        print("DEBUG: Character references: \(String(describing: characterReferences))")
        print("DEBUG: Style references: \(String(describing: styleReferences))")
        
        // Format character references to use identity0 as per Luma AI docs
        var formattedCharacterRefs: [String: CharacterIdentity]?
        if let charRefs = characterReferences {
            // Combine all images into identity0 with increased weight
            let allImages = charRefs.values.flatMap { $0.images }
            if !allImages.isEmpty {
                formattedCharacterRefs = ["identity0": CharacterIdentity(images: allImages, weight: 0.7)]
                print("DEBUG: Formatted character references with identity0 and weight 0.7: \(String(describing: formattedCharacterRefs))")
            }
        }
        
        // Ensure style references have appropriate weights
        let adjustedStyleRefs = styleReferences?.map { ref in
            ReferenceImage(
                url: ref.url,
                prompt: ref.prompt ?? "maintain consistent style",
                weight: 0.6 // Reduced weight for more experimentation
            )
        }
        
        let request = GenerationRequest(
            prompt: prompt,
            image_ref: references,
            character_ref: formattedCharacterRefs,
            style_ref: adjustedStyleRefs,
            num_images: numOutputs,
            guidance_scale: guidanceScale,
            steps: steps
        )
        
        guard let url = URL(string: "\(Constants.baseUrl)/image") else {
            throw LumaAIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let encodedData = try encoder.encode(request)
            urlRequest.httpBody = encodedData
            
            // Add debug logging
            print("DEBUG: Sending request to URL: \(url.absoluteString)")
            if let requestBody = String(data: encodedData, encoding: .utf8) {
                print("DEBUG: Request body: \(requestBody)")
            }
        } catch {
            print("DEBUG: Encoding error: \(error)")
            throw LumaAIError.networkError(error)
        }
        
        // Send request with error handling
        let (data, response) = try await session.data(for: urlRequest)
        
        // Add debug logging for response
        print("DEBUG: Response status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("DEBUG: Response body: \(responseBody)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaAIError.invalidResponse
        }
        
        // Handle response status codes
        switch httpResponse.statusCode {
        case 200, 201:
            let generationResponse = try decoder.decode(GenerationResponse.self, from: data)
            
            // Check for immediate failure
            if let failureReason = generationResponse.failure_reason {
                throw LumaAIError.generationFailed(failureReason)
            }
            
            if generationResponse.state == "failed" {
                throw LumaAIError.generationFailed(generationResponse.error ?? "Generation failed immediately")
            }
            
            return generationResponse.id
            
        case 400...499:
            // Client error
            if let error = try? decoder.decode(GenerationResponse.self, from: data) {
                throw LumaAIError.generationFailed(error.error ?? error.failure_reason ?? "Client error \(httpResponse.statusCode)")
            }
            throw LumaAIError.generationFailed("Request failed with status code \(httpResponse.statusCode)")
            
        case 500...599:
            // Server error
            throw LumaAIError.generationFailed("Server error: \(httpResponse.statusCode)")
            
        default:
            throw LumaAIError.generationFailed("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
    
    private func pollGeneration(id: String) async throws -> [String] {
        guard let url = URL(string: "\(Constants.baseUrl)/\(id)") else {
            throw LumaAIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Poll with exponential backoff
        var attempt = 0
        let maxAttempts = 30 // 5 minutes total with exponential backoff
        
        while attempt < maxAttempts {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Add debug logging for polling
            print("DEBUG: Polling response: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LumaAIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let error = try? decoder.decode(GenerationResponse.self, from: data)
                throw LumaAIError.generationFailed(error?.error ?? "Unknown error")
            }
            
            let generationResponse = try decoder.decode(GenerationResponse.self, from: data)
            
            if let failureReason = generationResponse.failure_reason {
                throw LumaAIError.generationFailed(failureReason)
            }
            
            switch generationResponse.state {
            case "completed":
                let images = generationResponse.allImages
                if !images.isEmpty {
                    return images
                } else {
                    throw LumaAIError.generationFailed("No images in completed response")
                }
            case "failed":
                throw LumaAIError.generationFailed(generationResponse.failure_reason ?? "Generation failed")
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
        
        throw LumaAIError.generationFailed("Generation timed out")
    }
    
    private func deleteGeneration(id: String) async throws {
        guard let url = URL(string: "\(Constants.baseUrl)/\(id)") else {
            throw LumaAIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "DELETE"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaAIError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            let error = try? decoder.decode(GenerationResponse.self, from: data)
            throw LumaAIError.generationFailed(error?.error ?? "Unknown error")
        }
    }
    
    private func createVideoGeneration(
        prompt: String,
        references: [ReferenceImage]?,
        characterReferences: [String: CharacterIdentity]?,
        guidanceScale: Double,
        steps: Int
    ) async throws -> String {
        guard let url = URL(string: Constants.baseUrl) else {
            throw LumaAIError.invalidResponse
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
        
        // Extract reference URLs from character references
        let referenceUrls = characterReferences?.values.flatMap { $0.images } ?? []
        
        // Create request with empty keyframes (will be set in generateVideo function)
        let request = VideoGenerationRequest(
            prompt: promptWithSeed,
            keyframes: [:]
        )
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let encodedData = try encoder.encode(request)
            urlRequest.httpBody = encodedData
            
            // Add debug logging
            print("DEBUG: Sending video generation request to URL: \(url.absoluteString)")
            if let requestBody = String(data: encodedData, encoding: .utf8) {
                print("DEBUG: Request body: \(requestBody)")
            }
        } catch {
            throw LumaAIError.networkError(error)
        }
        
        // Send request with error handling
        let (data, response) = try await session.data(for: urlRequest)
        
        // Add debug logging for response
        print("DEBUG: Response status code: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
        if let responseBody = String(data: data, encoding: .utf8) {
            print("DEBUG: Response body: \(responseBody)")
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LumaAIError.invalidResponse
        }
        
        // Handle response status codes
        switch httpResponse.statusCode {
        case 200, 201:
            let generationResponse = try decoder.decode(VideoGenerationResponse.self, from: data)
            
            // Check for immediate failure
            if let failureReason = generationResponse.failure_reason {
                throw LumaAIError.videoGenerationFailed(failureReason)
            }
            
            if generationResponse.state == "failed" {
                throw LumaAIError.videoGenerationFailed(generationResponse.error ?? "Generation failed immediately")
            }
            
            return generationResponse.id
            
        case 400...499:
            // Client error
            if let error = try? decoder.decode(VideoGenerationResponse.self, from: data) {
                throw LumaAIError.videoGenerationFailed(error.error ?? error.failure_reason ?? "Client error \(httpResponse.statusCode)")
            }
            throw LumaAIError.videoGenerationFailed("Request failed with status code \(httpResponse.statusCode)")
            
        case 500...599:
            // Server error
            throw LumaAIError.videoGenerationFailed("Server error: \(httpResponse.statusCode)")
            
        default:
            throw LumaAIError.videoGenerationFailed("Unexpected status code: \(httpResponse.statusCode)")
        }
    }
    
    private func pollVideoGeneration(id: String) async throws -> URL {
        guard let url = URL(string: "\(Constants.baseUrl)/\(id)") else {
            throw LumaAIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        // Poll with exponential backoff
        var attempt = 0
        let maxAttempts = 60 // 10 minutes total with exponential backoff
        
        while attempt < maxAttempts {
            let (data, response) = try await session.data(for: urlRequest)
            
            // Add debug logging for polling
            print("DEBUG: Video polling response: \(String(data: data, encoding: .utf8) ?? "nil")")
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw LumaAIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                let error = try? decoder.decode(VideoGenerationResponse.self, from: data)
                throw LumaAIError.videoGenerationFailed(error?.error ?? "Unknown error")
            }
            
            let generationResponse = try decoder.decode(VideoGenerationResponse.self, from: data)
            
            if let failureReason = generationResponse.failure_reason {
                throw LumaAIError.videoGenerationFailed(failureReason)
            }
            
            switch generationResponse.state {
            case "completed":
                if let videoUrlString = generationResponse.assets?.video,
                   let videoUrl = URL(string: videoUrlString) {
                    return videoUrl
                } else {
                    throw LumaAIError.videoGenerationFailed("No video URL in completed response")
                }
            case "failed":
                throw LumaAIError.videoGenerationFailed(generationResponse.failure_reason ?? "Video generation failed")
            case "queued", "processing", "rendering":
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
        
        throw LumaAIError.videoGenerationFailed("Video generation timed out")
    }
    
    private func formatCharacterReferences(_ characterReferences: [String]) async throws -> [String: CharacterIdentity] {
        var formattedCharacterRefs: [String: CharacterIdentity] = [:]
        for (index, ref) in characterReferences.enumerated() {
            guard let url = URL(string: ref), url.scheme != nil else {
                throw LumaAIError.videoGenerationFailed("Invalid character reference URL: \(ref)")
            }
            let characterId = "character_\(index + 1)"
            formattedCharacterRefs[characterId] = CharacterIdentity(images: [ref])
        }
        print("DEBUG: Formatted character references: \(String(describing: formattedCharacterRefs))")
        return formattedCharacterRefs
    }
    
    /// Extract generation ID from a video URL
    /// - Parameter url: The video URL
    /// - Returns: The generation ID
    func getGenerationIdFromUrl(_ url: URL) async throws -> String {
        print("DEBUG: Extracting generation ID from URL: \(url)")
        
        // First, try to extract from Luma API URL format
        if url.host == "api.lumalabs.ai" {
            let components = url.pathComponents
            guard let generationId = components.last else {
                print("ERROR: Invalid URL format, cannot extract generation ID")
                throw LumaAIError.invalidResponse
            }
            return generationId
        }
        
        // If it's a CDN URL, extract from filename
        // Format: {generationId}_result{hash}.mp4
        let filename = url.lastPathComponent
        let components = filename.split(separator: "_")
        guard components.count >= 2,
              let generationId = components.first else {
            print("ERROR: Invalid CDN URL format")
            throw LumaAIError.invalidResponse
        }
        
        let id = String(generationId)
        print("DEBUG: Extracted generation ID: \(id)")
        
        // No need to verify the ID for CDN URLs as they are already verified
        return id
    }
} 