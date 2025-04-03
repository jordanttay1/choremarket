import SwiftUI
import Firebase
import FirebaseAuth
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: FirebaseAuth.User? = nil
    @Published var isAuthenticated: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isLoading: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check initial authentication state
        self.user = Auth.auth().currentUser
        self.isAuthenticated = user != nil
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] (_, user: FirebaseAuth.User?) in
            guard let self = self else { return }
            self.user = user
            self.isAuthenticated = user != nil
        }
    }
    
    // MARK: - Sign In
    func signIn(email: String, password: String) async {
        do {
            isLoading = true
            errorMessage = nil
            
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            self.user = result.user
            self.isAuthenticated = true
            
            isLoading = false
        } catch {
            print("Sign In Error: \(error.localizedDescription)")
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Sign Up
    func signUp(email: String, password: String, name: String) async {
        do {
            isLoading = true
            errorMessage = nil
            
            // Validate inputs
            guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
                throw NSError(domain: "AuthError", code: -1, userInfo: [NSLocalizedDescriptionKey: "All fields are required"])
            }
            
            // Check password strength
            guard password.count >= 6 else {
                throw NSError(domain: "AuthError", code: -2, userInfo: [NSLocalizedDescriptionKey: "Password must be at least 6 characters"])
            }
            
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            print(result)
            
            // Update profile
            let changeRequest = result.user.createProfileChangeRequest()
            changeRequest.displayName = name
            try await changeRequest.commitChanges()
            
            self.user = result.user
            self.isAuthenticated = true
            
            print("Sign Up Successful for: \(email)")
            isLoading = false
        } catch {
            print("Sign Up Error: \(error.localizedDescription)")
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.user = nil
            self.isAuthenticated = false
            self.errorMessage = nil
        } catch {
            print("Sign Out Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Reset Password
    func resetPassword(email: String) async {
        do {
            isLoading = true
            errorMessage = nil
            
            try await Auth.auth().sendPasswordReset(withEmail: email)
            
            isLoading = false
        } catch {
            print("Password Reset Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    // MARK: - Update User Profile
    func updateUserProfile(displayName: String, photoURL: URL? = nil) async {
        guard let user = Auth.auth().currentUser else {
            self.errorMessage = "No user is signed in"
            return
        }
        
        do {
            isLoading = true
            errorMessage = nil
            
            let changeRequest = user.createProfileChangeRequest()
            
            if !displayName.isEmpty {
                changeRequest.displayName = displayName
            }
            
            if let photoURL = photoURL {
                changeRequest.photoURL = photoURL
            }
            
            try await changeRequest.commitChanges()
            
            // Refresh user to get updated profile
            self.user = Auth.auth().currentUser
            
            isLoading = false
        } catch {
            print("Update Profile Error: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
