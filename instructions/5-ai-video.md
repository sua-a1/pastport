1. Draft Detail View UI Updates
[x] Add "Create AI Video" and "Create Script" buttons to the end of the Draft Detail View
[x] Style buttons to match existing UI design
[x] Add appropriate icons and visual feedback states

2. Luma AI Video Generation Service
[x] Create LumaVideoGenerationService class
[x] Implement video generation endpoint integration
[x] Configure API authentication
[x] Set up request parameters (5s duration, resolution, etc.)
[x] Handle response and error states
[x] Create data models for video generation requests/responses
[x] Add proper logging and error handling

3. Draft to Luma Prompt Conversion
[x] Create utility to convert draft content to Luma-compatible format
[x] Implement reference image handling
[x] Format character images for Luma API
[x] Handle multiple reference image weights
[x] Add prompt optimization for video generation
[x] Implement proper error handling for invalid inputs

4. Video Generation Flow
[x] Create VideoGenerationView
[x] Implement loading/progress UI
[x] Show generation status updates
[x] Display error states
[x] Handle video preview after generation
[x] Implement video playback controls

5. Post-Generation Actions
[x] Create action sheet/menu for video options
[x] Save to storage (without posting)
[x] Post to feed
[x] Download to device
[x] Delete
[x] Implement video compression (matching existing flow)
[x] Add encryption handling (matching existing flow)

6. Storage Integration
[x] Create Firebase Storage paths for AI-generated videos
[x] Implement upload functionality
[x] Add proper metadata
[x] Handle upload progress
[x] Implement comprehensive error handling
[x] Create download functionality for device storage

7. Post Creation Integration
[x] Integrate with existing post creation flow
[x] Update Firestore schema if needed
[x] Handle post visibility and permissions

8. Profile Integration
[x] Update profile video grid to handle AI-generated videos

9. Data Models & ViewModels
[x] Create/update models for AI video generation
[x] Create dedicated ViewModel for video generation flow
[x] Update existing ViewModels to handle new functionality

10. Testing & Validation
[ ] Test video generation with various draft types
[ ] Validate compression/encryption
[ ] Test storage upload/download
[ ] Verify post creation and display
[ ] Test error handling and edge cases

11. Performance & Security
[~] Implement proper caching for generated videos
[x] Add rate limiting for API calls
[x] Ensure secure handling of API keys
[ ] Validate file size and format restrictions

12. Analytics & Monitoring
[ ] Add analytics events for video generation
[ ] Track success/failure rates
[ ] Monitor API usage and quotas
[ ] Implement error reporting

Legend:
[x] - Completed
[~] - Partially implemented
[ ] - Not implemented

Implementation Details:

Video Generation:
- Uses Luma AI API for video generation
- 5-second duration with 30fps
- 1080p resolution
- Optimized prompts with style hints and quality modifiers
- Reference image support with weighted influence
- Automatic retry and error handling

Storage & Caching:
- Basic video storage in Firebase
- Basic local caching for preview
- Needs improvements:
  - Proper metadata handling
  - Progress tracking
  - Error handling
  - Cleanup procedures

Security:
- API key stored in environment variables
- Rate limiting implemented in LumaAIService
- Needs improvements:
  - File validation
  - Format restrictions
  - Size limits

UI/UX:
- Progress indication during generation
- Preview with playback controls
- Error states with retry options
- Needs improvements:
  - Download/Delete options
  - AI indicators
  - Progress tracking
