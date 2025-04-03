import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
class ChoreViewModel: ObservableObject {
    
    private let db = Firestore.firestore()
    private var listeners: [ListenerRegistration] = []
    
    @Published var chores: [Chore] = []
    @Published var userChores: [Chore] = []
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    
    deinit {
        // Remove all listeners when ViewModel is deallocated
        listeners.forEach { $0.remove() }
    }
    
    // Fetch chores for a household with real-time updates
    func fetchChores(householdId: String) {
        isLoading = true
        
        // Clear previous listeners
        listeners.forEach { $0.remove() }
        listeners = []
        
        // Create a new listener for real-time updates
        let listener = db.collection("chores")
            .whereField("householdId", isEqualTo: householdId)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    self.chores = []
                    self.isLoading = false
                    return
                }
                
                self.chores = documents.compactMap { doc -> Chore? in
                    try? doc.data(as: Chore.self)
                }
                
                // Also filter for user's chores if logged in
                if let userId = Auth.auth().currentUser?.uid {
                    self.userChores = self.chores.filter { $0.assignedUserId == userId }
                }
                
                self.isLoading = false
            }
        
        listeners.append(listener)
    }
    
    // Create a new chore record in Firestore
    func createChore(chore: Chore) {
        Task {
            do {
                isLoading = true
                // Convert to dictionary if needed:
                let data = try Firestore.Encoder().encode(chore)
                
                // Generate a new document
                let newDocRef = db.collection("chores").document(chore.id)
                try await newDocRef.setData(data)
                isLoading = false
                
                // No need to re-fetch as the listener will update automatically
            } catch {
                isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // Update an existing chore
    func updateChore(chore: Chore) {
        Task {
            do {
                isLoading = true
                let data = try Firestore.Encoder().encode(chore)
                try await db.collection("chores").document(chore.id).updateData(data)
                isLoading = false
                // No need to re-fetch with listeners
            } catch {
                isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }
    
    // Example "steal" action: reassign chore to the current user, adjust points, etc.
    func stealChore(chore: Chore, newUserId: String) {
        var updated = chore
        updated.assignedUserId = newUserId
        updated.basePoints = max(1, chore.basePoints - 1) // Prevent negative points
        updated.lastUpdated = Date()
        updateChore(chore: updated)
    }
    
    // Example "force"
    func forceChore(chore: Chore, newUserId: String) {
        var updated = chore
        updated.assignedUserId = newUserId
        updated.basePoints = chore.basePoints + 1
        updated.lastUpdated = Date()
        updateChore(chore: updated)
    }
    
    // Complete a chore
    func completeChore(chore: Chore) {
        var updated = chore
        updated.status = "completed"
        updated.lastUpdated = Date()
        
        // If needed, also handle recurring chores by creating the next occurrence
        if chore.frequency != "once" {
            scheduleNextChoreOccurrence(completedChore: updated)
        }
        
        updateChore(chore: updated)
    }
    
    // Handle recurring chores by scheduling the next occurrence
    private func scheduleNextChoreOccurrence(completedChore: Chore) {
        var nextDate = completedChore.nextDueDate
        
        // Calculate next due date based on frequency
        switch completedChore.frequency {
        case "daily":
            nextDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        case "weekly":
            nextDate = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
        case "monthly":
            nextDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()
        default:
            return // Not recurring, no need to schedule next
        }
        
        // Create new chore with next date
        let newChore = Chore(
            title: completedChore.title,
            description: completedChore.description,
            basePoints: completedChore.basePoints,
            frequency: completedChore.frequency,
            nextDueDate: nextDate,
            assignedUserId: completedChore.assignedUserId,
            creationUserId: completedChore.creationUserId
        )
        
        createChore(chore: newChore)
    }
}
