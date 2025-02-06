# Pastport - TikTok for Historical & Mythological Storytelling

## Implemented Features

### 1. User Authentication & Profiles ✅
- Email-based authentication using Firebase Auth
- Profile creation with username, picture, bio
- Profile editing functionality
- Sign out capability
- Profile video grid display
- Profile video playback integration

### 2. Video Upload & Processing ✅
- Video recording with device camera
- Video upload to Firebase Storage
- Video metadata storage in Firestore
- Video playback with caching
- Vertical scrolling feed with paging behavior
- Auto-play/pause on scroll
- Performance optimized video loading
- Proper aspect ratio handling
- Video thumbnail generation and caching
- Grid layout for video discovery
- Video metadata display (views, likes, comments)

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