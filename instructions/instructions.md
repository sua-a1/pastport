**Pastport** TikTok for Historical & Mythological Storytelling

## Purpose and Scope
Pastport is a TikTok-like platform that allows creators to engage in historical, mythological, and speculative storytelling. The app enables users to write, categorize, and share short-form historical and mythological narratives, enriched with multimedia and persistent character profiles. The platform will also support AI-generated storytelling videos in Week 2.

**Scope:**

    - Week 1: Build the vertical creator flow – focusing on user-uploaded video functionality, text-based draft system, categorization, character profiles, and engagement features.

    - Week 2: AI-powered enhancements – Implement AI-generated storytelling videos, character consistency in AI generation, and speculative 'What If' scenarios.

**Target Platform:**
- iOS (iPhone)
**Dependencies:**
 - **Frontend:** SwiftUI for UI components
 - **OS services:** iOS Camera, Photos, and Video services
 - **Authentication:** Firebase Auth
 - **Networking** URLSession or AlamoFire for network calls
 - **Database:** Firebase Firestore for data storage
 - **Storage:** Firebase Storage for media storage
 - **Cloud services:** Cloudinary for video processing
 - **AI services:** Luma AI for character generation

## Implemented Features & User Stories

### 1. User Authentication & Profiles
**User Story:** "As a user, I want to sign up and manage my profile so I can create and interact with content."

**Implemented:**
- Email-based authentication using Firebase Auth
- Profile creation with username, picture, and bio
- Profile editing functionality
- Profile video grid display
- Profile video playback integration

### 2. Video Creation & Upload
**User Story:** "As a creator, I want to record and upload videos to share my historical stories."

**Implemented:**
- In-app video recording with device camera
- Video upload to Firebase Storage
- Video compression and optimization
- Video metadata storage in Firestore
- Video playback with caching

### 3. Character Creation
**User Story:** "As a creator, I want to generate AI characters for my stories using reference images and descriptions, and refine them until they're perfect."

**Implemented:**
- Character creation form with name and description
- Reference image upload (up to 4 images) with individual prompts and weights
- AI-powered character generation using Luma AI
- Character style customization with visual prompts
- Advanced refinement flow:
  - Selection of best generated variations
  - Generation of new poses and expressions
  - Refinement based on selected variations
  - Character consistency preservation
- Character version history and storage
- Character metadata management in Firestore
- Efficient image processing and caching

### 4. Draft Management
**User Story:** "As a creator, I want to save and manage drafts of my stories before publishing."

**Implemented:**
- Text-based draft creation
- Multimedia attachment support
- Draft status tracking
- Draft list view in profile
- Local draft storage with SwiftData

### 5. Creator Video Management
**User Story:** "As a creator, I want to manage my video content effectively with comprehensive playback, sharing, and organization tools."

**Implemented:**
- Profile video grid display with thumbnails
- Full-screen video feed in profile:
  - Vertical scrolling navigation
  - Auto-play/pause on scroll
  - Smooth transitions between videos
- Video management features:
  - Secure video deletion with confirmation
  - Cleanup of associated storage and database records
  - Video sharing functionality
  - Video metadata display
- Performance optimizations:
  - Efficient video loading and caching
  - Thumbnail generation and caching
  - Memory management for smooth playback
- Video organization tools:
  - Grid/List view toggle
  - Sort by date/popularity
  - Category filtering

### 6. Content Organization
**User Story:** "As a creator, I want to organize my content by historical periods and categories."

**Implemented:**
- Historical vs Myth/Lore classification
- Canonical/Speculative/Alternate categories
- Content tagging system
- Category-based content discovery
- Organized profile content display

## Technical Implementation Details

### Firebase Configuration

#### Storage Rules
```javascript
// Videos folder rules
match /videos/{videoId} {
    allow read: if isAuthenticated();
    allow write, create, update: if isAuthenticated() && isValidVideo();
    allow delete: if isAuthenticated() && videoId.matches(request.auth.uid + '_.*');
}
```

#### Firestore Rules
```javascript
// Posts collection rules
match /posts/{postId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
    allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
}
```

## Next Steps
1. Implement AI video generation from text drafts
2. Add character consistency in AI generation
3. Develop speculative "What If" story generator
4. Enhance video feed algorithm
5. Add real-time updates for user interactions

