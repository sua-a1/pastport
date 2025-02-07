import SwiftUI
import FirebaseFirestore

struct ReferenceTextSelectionView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var references: [ReferenceText] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var selectedReferenceForEdit: ReferenceText?
    let onSelect: (ReferenceText) -> Void
    
    var body: some View {
        List {
            ForEach(references) { reference in
                ReferenceTextRow(reference: reference)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        print("DEBUG: Selected reference: \(reference.id)")
                        onSelect(reference)
                        dismiss()
                    }
                    .swipeActions {
                        Button("Edit") {
                            selectedReferenceForEdit = reference
                        }
                        .tint(.blue)
                        
                        Button("Delete", role: .destructive) {
                            Task {
                                await deleteReference(reference)
                            }
                        }
                    }
            }
        }
        .overlay {
            if isLoading {
                ProgressView()
            } else if references.isEmpty {
                ContentUnavailableView(
                    "No References",
                    systemImage: "text.book.closed",
                    description: Text("Create a new reference to get started")
                )
            }
        }
        .navigationTitle("Select Reference")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Create New") {
                    showCreateSheet = true
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            ReferenceTextCreateView(userId: userId) { reference in
                references.append(reference)
                showCreateSheet = false
                onSelect(reference)
                dismiss()
            }
        }
        .sheet(item: $selectedReferenceForEdit) { reference in
            NavigationStack {
                ReferenceTextEditView(reference: reference) { updatedReference in
                    if let index = references.firstIndex(where: { $0.id == updatedReference.id }) {
                        references[index] = updatedReference
                    }
                }
            }
        }
        .task {
            await fetchReferences()
        }
    }
    
    private func fetchReferences() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let db = Firestore.firestore()
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("referenceTexts")
                .getDocuments()
            
            // Filter out references that have no associated drafts
            references = snapshot.documents.compactMap { doc -> ReferenceText? in
                guard let reference = ReferenceText.fromFirestore(doc.data(), id: doc.documentID),
                      !reference.draftIds.isEmpty else {
                    // Delete orphaned reference
                    Task {
                        try? await doc.reference.delete()
                    }
                    return nil
                }
                return reference
            }
        } catch {
            print("DEBUG: Failed to fetch references: \(error)")
            errorMessage = error.localizedDescription
        }
    }
    
    private func deleteReference(_ reference: ReferenceText) async {
        do {
            let db = Firestore.firestore()
            
            // Delete the reference
            try await db.collection("users")
                .document(userId)
                .collection("referenceTexts")
                .document(reference.id)
                .delete()
            
            // Update all drafts that use this reference
            for draftId in reference.draftIds {
                let draftRef = db.collection("users")
                    .document(userId)
                    .collection("drafts")
                    .document(draftId)
                
                let draftDoc = try? await draftRef.getDocument()
                if var draftData = draftDoc?.data(),
                   var referenceIds = draftData["referenceTextIds"] as? [String] {
                    referenceIds.removeAll { $0 == reference.id }
                    draftData["referenceTextIds"] = referenceIds
                    draftData["updatedAt"] = Date()
                    try? await draftRef.setData(draftData, merge: true)
                }
            }
            
            // Remove from local array
            references.removeAll { $0.id == reference.id }
        } catch {
            print("DEBUG: Failed to delete reference: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

struct ReferenceTextCreateView: View {
    let userId: String
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var content = ""
    @State private var source = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onCreated: (ReferenceText) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(height: 100)
                    TextField("Source (Optional)", text: $source)
                }
            }
            .navigationTitle("New Reference")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await saveReference()
                        }
                    }
                    .disabled(title.isEmpty || content.isEmpty)
                }
            }
            .disabled(isSaving)
            .overlay {
                if isSaving {
                    ProgressView()
                }
            }
        }
    }
    
    private func saveReference() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            let reference = ReferenceText(
                userId: userId,
                title: title,
                content: content,
                source: source.isEmpty ? nil : source,
                draftIds: [], // Initialize with empty array as required by Firestore rules
                createdAt: Date(),
                updatedAt: Date()
            )
            
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(userId)
                .collection("referenceTexts")
                .document(reference.id)
                .setData(reference.toFirestore())
            
            onCreated(reference)
            dismiss()
        } catch {
            print("DEBUG: Failed to save reference: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

struct ReferenceTextEditView: View {
    let reference: ReferenceText
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    @State private var source: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    let onSaved: (ReferenceText) -> Void
    
    init(reference: ReferenceText, onSaved: @escaping (ReferenceText) -> Void) {
        self.reference = reference
        self.onSaved = onSaved
        _title = State(initialValue: reference.title)
        _content = State(initialValue: reference.content)
        _source = State(initialValue: reference.source ?? "")
    }
    
    var body: some View {
        Form {
            Section {
                TextField("Title", text: $title)
                TextEditor(text: $content)
                    .frame(height: 100)
                TextField("Source (Optional)", text: $source)
            }
        }
        .navigationTitle("Edit Reference")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    dismiss()
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    Task {
                        await saveReference()
                    }
                }
                .disabled(title.isEmpty || content.isEmpty)
            }
        }
        .disabled(isSaving)
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
    }
    
    private func saveReference() async {
        isSaving = true
        defer { isSaving = false }
        
        do {
            var updatedReference = reference
            updatedReference.title = title
            updatedReference.content = content
            updatedReference.source = source.isEmpty ? nil : source
            updatedReference.updatedAt = Date()
            
            let db = Firestore.firestore()
            try await db.collection("users")
                .document(reference.userId)
                .collection("referenceTexts")
                .document(reference.id)
                .setData(updatedReference.toFirestore(), merge: true)
            
            onSaved(updatedReference)
            dismiss()
        } catch {
            print("DEBUG: Failed to save reference: \(error)")
            errorMessage = error.localizedDescription
        }
    }
}

private struct ReferenceTextRow: View {
    let reference: ReferenceText
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(reference.title)
                .font(.headline)
            Text(reference.content)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if let source = reference.source {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
} 