Initial Planned Schema Breakdown (Firestore NoSQL Structure)
Firestore is a NoSQL database, meaning we should optimize for read-heavy operations while keeping data structured for fast querying.

🔹 Firestore Collections & Documents
📂 users
   📄 {userId}
      ├── username: "Sude"
      ├── email: "sude@example.com"
      ├── profilePicture: "https://storage.firebase..."
      ├── createdPosts: [postId1, postId2, ...]
      ├── createdCharacters: [characterId1, characterId2, ...]

📂 posts
   📄 {postId}
      ├── title: "The Myth of the Nart Sagas"
      ├── content: "Long-form text content here..."
      ├── creatorId: "userId"
      ├── media: ["image1.jpg", "video1.mp4"]
      ├── category: "Myth/Lore"
      ├── classification: "Speculative"
      ├── tags: ["#CircassianMyth", "#NartSagas"]
      ├── characterTags: [characterId1, characterId2]
      ├── timestamp: "2025-02-03T12:00:00Z"
      ├── likes: 10
      ├── comments: 3

📂 characters
   📄 {characterId}
      ├── creatorId: "userId"
      ├── name: "Sosruko"
      ├── backstory: "A Circassian trickster hero from the Nart sagas..."
      ├── historicalEra: "Ancient Circassia"
      ├── visualReferences: ["sosruko1.jpg", "sosruko2.png"]
      ├── linkedPosts: [postId1, postId3]

📂 collections
   📄 {collectionId}
      ├── creatorId: "userId"
      ├── name: "Prehistoric Anthropology Theories"
      ├── description: "A collection of speculative anthropology content."
      ├── posts: [postId2, postId4]
