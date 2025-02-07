**Pastport** TikTok for Historical & Mythological Storytelling

## Purpose and Scope
Pastport is a TikTok-like platform that allows creators to engage in historical, mythological, and speculative storytelling. The app enables users to write, categorize, and share short-form historical and mythological narratives, enriched with multimedia and persistent character profiles. The platform will also support AI-generated storytelling videos in Week 2.

 **Scope:**

    - Week 1: Build the vertical creator flow – focusing on user-uploaded video functionality, text-based draft system, categorization, character profiles, and engagement features.

    - Week 2: AI-powered enhancements – Implement AI-generated storytelling videos, character consistency in AI generation, and speculative ‘What If’ scenarios.

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
 - **AI services:** to be determined

## Core Features

1. User Authentication & Profiles – Secure sign-up/login using Firebase Auth.

2. Video Creation, Upload & Processing – Users upload videos, optimized via Cloudinary.

3. Text-Based Drafting – Users create unpublished text drafts with multimedia attachments. (Fully implementedd in Week 2)

4. Post Categorization & Tagging – Historical vs. Myth/Lore with Canonical/Speculative/Alternate classifications.

5. Character Profiles – Users create characters that persist across stories. (Fully implemented in Week 2)

6. Engagement Features – Likes, comments, and shares.

7. AI-Powered Video Generation (Week 2) – Convert text drafts into AI-generated videos with consistent AI characters.

## Feature Requirements & User Stories

### 1. User Authentication & Profiles

**User Story:** "As a user, I want to sign up and manage my profile so I can create and interact with content."

**Requirements:**

- Google Sign-In & Email-based Authentication.
- Profile creation (username, picture, bio).

### 2. Video Upload & Processing

**User Story:** "As a creator, I want to upload videos and have them optimized for playback."

**Requirements:**

- Upload videos to Firebase Storage.

- Cloudinary processes video for compression & format conversion.

- Store metadata (duration, resolution, timestamp) in Firestore.

### 3. Text-Based Drafting

**User Story:** "As a creator, I want to write and save drafts with resource attachments for AI-based generation later."

**Requirements:**

- Save text drafts in Firestore (not published in Week 1).

- Attach multimedia (images, videos, reference texts).

- Sync drafts to local SwiftData for offline editing.

### 4. Post Categorization & Tagging

**User Story:** "As a creator, I want to categorize my content so users can discover stories by theme."

**Requirements:**

- Users select Historical/Myth/Lore.

- If Historical → Must select Canonical, Speculative, or Alternate.

- If Myth/Lore → Canonical, Speculative, or Alternate.

### 5. Character Profiles

**User Story:** "As a creator, I want to create and tag characters in my stories for consistency."

**Requirements:**

- Users create and manage character profiles.

- Character profiles store name, backstory, visual references.

- Users tag characters in drafts for linked storytelling.

### 6. Engagement Features

**User Story:** "As a user, I want to like, comment, and share content to interact with the community."

**Requirements:**

- Firestore real-time updates for engagement.

- Comments stored in a separate Firestore collection.

### 7. AI-Powered Video Generation (Week 2)

**User Story:** "As a creator, I want AI to convert my text draft into a narrated video with visuals."

**Requirements:**

- AI-generated video with text-to-speech narration.

- AI maintains character consistency.

- Users can select voice & style for narration.

## Technical Stack & Architecture

- Firebase (Auth, Firestore, Cloud Storage) for backend infrastructure.

- SwiftUI for a responsive and native mobile experience.

- Firestore Indexing for optimized search and categorization.

- Cloud Functions for automated content processing and AI integration.

- SwiftData for local persistance.

## Development Roadmap

Week 1 Focus: Build core features: authentication, video upload, text drafts, categorization, character profiles, engagement features.

Week 2 Focus: Implement AI-powered storytelling: text-to-video generation, character consistency in AI, speculative "What If" generator.

