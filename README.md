# Pastport - TikTok for Historical & Mythological Storytelling
![image](https://github.com/user-attachments/assets/2b46351c-f0a8-4ccc-808f-81a0792a6bd5)
## Implemented Features

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

## Project Overview

Pastport is a TikTok-like platform that enables creators to engage in historical, mythological, and speculative storytelling. The app allows users to write, categorize, and share short-form historical and mythological narratives, enriched with multimedia and persistent character profiles.

### Development Timeline

#### Week 1 (Current)
- Building the vertical creator flow
- User-uploaded video functionality
- Text-based draft system
- Categorization
- Character profiles
- Engagement features

#### Week 2 (Upcoming)
- AI-powered enhancements
- AI-generated storytelling videos
- Character consistency in AI generation
- Speculative 'What If' scenarios

### Tech Stack

- **Frontend:** SwiftUI for UI components
- **Authentication:** Firebase Auth
- **Database:** Firebase Firestore
- **Storage:** Firebase Storage
- **Cloud Services:** Cloudinary for video processing
- **Local Storage:** SwiftData

### Core Features

1. **User Authentication & Profiles**
   - Secure sign-up/login using Firebase Auth
   - Profile management (username, picture, bio)

2. **Video Creation & Upload**
   - Direct video upload to Firebase Storage
   - Video processing and optimization

3. **Text-Based Drafting** (Week 2)
   - Unpublished text drafts
   - Multimedia attachments
   - Offline editing with SwiftData

4. **Post Categorization**
   - Historical vs. Myth/Lore classification
   - Canonical/Speculative/Alternate categories
   - Searchable hashtags

5. **Character Profiles** (Week 2)
   - Persistent characters across stories
   - Character backstory and visual references
   - Character tagging in stories

6. **Engagement Features**
   - Likes, comments, and shares
   - Real-time updates via Firestore

7. **AI-Powered Video Generation** (Week 2)
   - Text-to-video conversion
   - AI character consistency
   - Voice and style customization

## Getting Started

1. Clone the repository
2. Install dependencies
3. Set up Firebase project and add configuration
4. Run the app in Xcode

## Firebase Configuration

### Storage Rules
```javascript
match /videos/{videoId} {
    allow read: if isAuthenticated();
    allow write, create, update: if isAuthenticated() && isValidVideo();
    allow delete: if isAuthenticated() && videoId.matches(request.auth.uid + '_.*');
}
```

### Firestore Rules
```javascript
match /posts/{postId} {
    allow read: if isAuthenticated();
    allow create: if isAuthenticated() && request.resource.data.userId == request.auth.uid;
    allow update, delete: if isAuthenticated() && resource.data.userId == request.auth.uid;
}
```

## Contributing

Please read our contributing guidelines before submitting pull requests.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 
