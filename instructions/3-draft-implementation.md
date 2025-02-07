# Text-Based Drafting Implementation Checklist

## Overview
This checklist outlines the implementation steps for the text-based drafting functionality in Pastport. This feature allows users to create, edit, and manage draft stories with multimedia attachments, which will later be used for AI video generation.

## Implementation Steps

### 1. Models & Storage Setup
- [x] Create Draft model for SwiftData
  - Title, content, creation date, last modified date
  - Arrays for image URLs, video URLs, reference texts
  - Category (Historical/Myth/Lore) and subcategory
  - Status (draft/published)
  - User ID reference
- [x] Create corresponding Firestore schema for drafts
- [x] Set up Firebase Storage structure for draft attachments
- [x] Implement Draft-User relationship in SwiftData

### 2. Create Tab UI Updates
- [x] Add segmented control to Create tab (Video/AI Draft)
- [x] Design and implement AI draft creation form
  - Text input for main content
  - Image attachment section (max 4)
  - Video attachment section (max 2)
  - Reference text input fields (max 2)
  - Category selection
- [x] Implement attachment preview/review UI
- [x] Add draft saving functionality

### 3. Profile Integration
- [x] Add Drafts tab to Profile view
- [x] Implement drafts list view
  - Show title, date, category, attachment count
  - Add draft status indicator
- [x] Create draft detail view
  - Display all content and attachments
  - Add edit/delete options
- [x] Implement draft editing functionality

### 4. Storage & Sync Implementation
- [x] Implement Firebase Storage upload for attachments
  - Image upload with compression
  - Video upload with proper metadata
- [x] Set up Firestore draft document creation/update

### 5. Draft Management Features
- [x] Implement draft deletion (both local and remote)
- [x] Add attachment management
  - Add/remove images
  - Add/remove videos
  - Update reference texts
- [x] Implement draft status updates

### 6. Testing & Polish
- [x] Test attachment limits
- [x] Add loading states and error handling
- [x] Implement proper cleanup of unused attachments

### 7. Future AI Integration Preparation
- [ ] Add fields for AI generation preferences
- [ ] Implement draft-to-AI-request conversion structure
- [ ] Add placeholder UI for future AI features

## Implementation Notes
- Start with Models & Storage Setup to establish the foundation
- UI implementation should follow a mobile-first approach
- Ensure proper error handling and loading states throughout
- Maintain offline-first capability with SwiftData
- Follow existing app architecture patterns
- Keep AI integration in mind while designing the data structures 