//
//  ChoreMarketApp.swift
//  ChoreMarket
//
//  Created by Jordan Taylor on 2/20/25.
//

import SwiftUI

import Foundation
import FirebaseCore
import Firebase
import FirebaseAuth
import FirebaseAppCheck


class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        
        // Setup AppCheck correctly
        #if targetEnvironment(simulator)
        // Use debug provider for simulators
        let providerFactory = AppCheckDebugProviderFactory()
        #else
        // Use DeviceCheck for real devices
        let providerFactory = DeviceCheckProviderFactory()
        #endif
        
        AppCheck.setAppCheckProviderFactory(providerFactory)
        
        return true
    }
}



struct Chore: Identifiable, Codable {
    var id: String
    var title: String
    var description: String
    var basePoints: Int
    var frequency: String
    var nextDueDate: Date
    var assignedUserId: String
    var creationUserId: String
    var status: String
    var biddingState: String
    var lastUpdated: Date
    
    // Constructor with defaults to make creating new chores easier
    init(
        id: String = UUID().uuidString,
        title: String,
        description: String = "",
        basePoints: Int = 10,
        frequency: String = "once",
        nextDueDate: Date = Date(),
        assignedUserId: String,
        creationUserId: String,
        status: String = "created",
        biddingState: String = "none",
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description.isEmpty ? "NONE" : description
        self.basePoints = basePoints
        self.frequency = frequency
        self.nextDueDate = nextDueDate
        self.assignedUserId = assignedUserId
        self.creationUserId = creationUserId
        self.status = status
        self.biddingState = biddingState
        self.lastUpdated = lastUpdated
    }
}

struct ProfileView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        VStack(spacing: 16) {
            if let user = authVM.user {
                Text("Logged in as: \(user.email ?? "Unknown")")
            }
            Button("Sign Out") {
                authVM.signOut()
            }
            .foregroundColor(.red)

            Spacer()
        }
        .padding()
    }
}


struct SettlementView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("Monthly Settlement")
                .font(.largeTitle)
            Text("Partner A: 120 points")
            Text("Partner B: 110 points")
            Text("Difference: 10 => $10 owed")
            Spacer()
        }
        .padding()
    }
}

struct CreateChoreView: View {
    @EnvironmentObject var choreVM: ChoreViewModel
    @Environment(\.presentationMode) var presentationMode
    let householdId: String

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var basePoints: String = "10"
    @State private var frequency: String = "once"
    @State private var dueDate: Date = Date()

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)
                    TextField("Points (default 10)", text: $basePoints)
                        .keyboardType(.numberPad)
                    Picker("Frequency", selection: $frequency) {
                        Text("Once").tag("once")
                        Text("Daily").tag("daily")
                        Text("Weekly").tag("weekly")
                        Text("Monthly").tag("monthly")
                    }
                    DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .navigationTitle("New Chore")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    Task {
                        if let currentUser = Auth.auth().currentUser {
                            let userId = currentUser.uid
                            let points = Int(basePoints) ?? 10
                            let newChore = Chore(
                                id: UUID().uuidString, // Generate a new unique ID
                                title: title,
                                description: description.isEmpty ? "NONE" : description,
                                basePoints: points,
                                frequency: frequency,
                                nextDueDate: dueDate,
                                assignedUserId: userId,
                                creationUserId: userId,
                                status: "created",
                                biddingState: "none",
                                lastUpdated: Date()
                            )
                            choreVM.createChore(chore: newChore)
                            presentationMode.wrappedValue.dismiss()
                        } else {
                            print("No current user found")
                        }
                    }
                }
            )
        }
    }
}

struct ChoreDetailView: View {
    @EnvironmentObject var choreVM: ChoreViewModel
    @Environment(\.presentationMode) var presentationMode
    let chore: Chore
    
    var isCurrentUserAssigned: Bool {
        chore.assignedUserId == Auth.auth().currentUser?.uid
    }
    
    var isCompleted: Bool {
        chore.status == "completed"
    }
    
    var isOverdue: Bool {
        chore.nextDueDate < Date() && !isCompleted
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Chore status header
                HStack {
                    VStack(alignment: .leading) {
                        Text(chore.title)
                            .font(.largeTitle)
                            .bold()
                            .foregroundColor(isCompleted ? .gray : .primary)
                        
                        Text("Status: \(chore.status.capitalized)")
                            .font(.subheadline)
                            .foregroundColor(
                                isCompleted ? .green :
                                    isOverdue ? .red : .blue
                            )
                    }
                    
                    Spacer()
                    
                    // Points badge
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 60, height: 60)
                        
                        VStack {
                            Text("\(chore.basePoints)")
                                .font(.title2)
                                .bold()
                            
                            Text("pts")
                                .font(.caption)
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Divider()
                
                // Due date and assignment info
                Group {
                    VStack(alignment: .leading, spacing: 8) {
                        Label {
                            Text("Due \(chore.nextDueDate, formatter: DateFormatter.shortDateTime)")
                                .foregroundColor(isOverdue ? .red : .primary)
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundColor(isOverdue ? .red : .blue)
                        }
                        
                        Label {
                            Text("Repeats: \(chore.frequency.capitalized)")
                        } icon: {
                            Image(systemName: "repeat")
                                .foregroundColor(.blue)
                        }
                        
                        Label {
                            Text(isCurrentUserAssigned ? "Assigned to you" : "Assigned to partner")
                        } icon: {
                            Image(systemName: "person")
                                .foregroundColor(.blue)
                        }
                        
                        if !chore.description.isEmpty && chore.description != "NONE" {
                            Label {
                                Text(chore.description)
                                    .multilineTextAlignment(.leading)
                            } icon: {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Action buttons
                if !isCompleted {
                    if isCurrentUserAssigned {
                        // Options for the assigned user
                        Button {
                            choreVM.completeChore(chore: chore)
                            presentationMode.wrappedValue.dismiss()
                        } label: {
                            Label("Mark as Complete", systemImage: "checkmark.circle")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                        }
                    } else {
                        // Options for the non-assigned user
                        VStack(spacing: 12) {
                            Button {
                                if let currentUser = Auth.auth().currentUser {
                                    choreVM.stealChore(chore: chore, newUserId: currentUser.uid)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } label: {
                                Label("Steal (-1 point)", systemImage: "hand.raised")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.orange)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            Button {
                                if let currentUser = Auth.auth().currentUser {
                                    choreVM.forceChore(chore: chore, newUserId: currentUser.uid)
                                    presentationMode.wrappedValue.dismiss()
                                }
                            } label: {
                                Label("Force (+1 point)", systemImage: "bolt")
                                    .padding()
                                    .frame(maxWidth: .infinity)
                                    .background(Color.purple)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    }
                } else {
                    // For completed chores
                    Text("This chore has been completed")
                        .font(.headline)
                        .foregroundColor(.green)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(10)
                }
                
                // Last updated info
                Text("Last updated: \(chore.lastUpdated, formatter: DateFormatter.shortDateTime)")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                
                Spacer()
            }
            .padding()
        }
        .navigationTitle("Chore Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
struct ChoreListView: View {
    @EnvironmentObject var choreVM: ChoreViewModel
    let householdId: String
    @State private var showCreateChore = false
    @State private var showCompletedChores = false
    @State private var filterMode: FilterMode = .all
    
    enum FilterMode: String, CaseIterable {
        case all = "All"
        case mine = "Mine"
        case others = "Others"
    }
    
    var filteredChores: [Chore] {
        let activeChores = choreVM.chores.filter {
            showCompletedChores || $0.status != "completed"
        }
        
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            return activeChores
        }
        
        switch filterMode {
        case .all:
            return activeChores
        case .mine:
            return activeChores.filter { $0.assignedUserId == currentUserId }
        case .others:
            return activeChores.filter { $0.assignedUserId != currentUserId }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                // Filter options
                Picker("Filter", selection: $filterMode) {
                    ForEach(FilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                Toggle("Show Completed", isOn: $showCompletedChores)
                    .padding(.horizontal)
                    .padding(.top, 5)
                
                if choreVM.isLoading {
                    ProgressView()
                        .padding()
                } else if filteredChores.isEmpty {
                    VStack {
                        Spacer()
                        
                        Text(filterMode == .mine ? "You don't have any chores yet" : "No chores found")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button {
                            showCreateChore = true
                        } label: {
                            Text("Create your first chore")
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                                .padding(.top, 10)
                        }
                        
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(filteredChores.sorted(by: { $0.nextDueDate < $1.nextDueDate })) { chore in
                            NavigationLink(destination: ChoreDetailView(chore: chore)) {
                                ChoreRowView(chore: chore)
                            }
                        }
                    }
                    .listStyle(InsetListStyle())
                }
            }
            .navigationTitle("Chores")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showCreateChore = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        choreVM.fetchChores(householdId: householdId)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showCreateChore) {
                CreateChoreView(householdId: householdId)
                    .environmentObject(choreVM)
            }
        }
    }
}

struct ChoreRowView: View {
    let chore: Chore
    
    var isCompleted: Bool {
        chore.status == "completed"
    }
    
    var isCurrentUserAssigned: Bool {
        chore.assignedUserId == Auth.auth().currentUser?.uid
    }
    
    var statusColor: Color {
        if isCompleted {
            return .green
        } else {
            return isOverdue ? .red : .blue
        }
    }
    
    var isOverdue: Bool {
        chore.nextDueDate < Date() && !isCompleted
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chore.title)
                    .font(.headline)
                    .foregroundColor(isCompleted ? .gray : .primary)
                    .strikethrough(isCompleted)
                
                HStack {
                    Text("Due: \(chore.nextDueDate, formatter: DateFormatter.shortDate)")
                        .font(.caption)
                        .foregroundColor(isOverdue ? .red : .gray)
                    
                    if isOverdue && !isCompleted {
                        Text("OVERDUE")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.red)
                            .cornerRadius(4)
                    }
                }
                
                Text("Points: \(chore.basePoints)")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                // Status indicator
                Text(isCurrentUserAssigned ? "You" : "Partner")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isCurrentUserAssigned ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                    .cornerRadius(4)
                
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MainView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject var choreVM = ChoreViewModel()

    // If you store a real "householdId" somewhere, fetch it here. For demo:
    let householdId = "my-household-id"

    var body: some View {
        TabView {
            ChoreListView(householdId: householdId)
                .environmentObject(choreVM)
                .tabItem {
                    Label("Chores", systemImage: "list.bullet")
                }

            SettlementView()
                .tabItem {
                    Label("Settlement", systemImage: "dollarsign.circle")
                }

            ProfileView()
                .environmentObject(authVM)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
        }
        .onAppear {
            choreVM.fetchChores(householdId: householdId)
        }
    }
}


struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var name: String = ""
    @State private var isRegistering: Bool = false
    @State private var showForgotPassword: Bool = false
    @State private var resetEmail: String = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Logo or App Title
            VStack {
                Text("ChoreMarket")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.blue)
                
                Text("Share chores fairly")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 30)
            
            // Form Fields
            VStack(spacing: 16) {
                if isRegistering {
                    VStack(alignment: .leading) {
                        Text("Full Name")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        TextField("", text: $name)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .autocapitalization(.words)
                    }
                }
                
                VStack(alignment: .leading) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    TextField("", text: $email)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                VStack(alignment: .leading) {
                    Text("Password")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    SecureField("", text: $password)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                if !isRegistering {
                    HStack {
                        Spacer()
                        Button("Forgot Password?") {
                            resetEmail = email
                            showForgotPassword = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
            
            // Submit Button
            Button {
                Task {
                    if isRegistering {
                        await authVM.signUp(email: email, password: password, name: name)
                    } else {
                        await authVM.signIn(email: email, password: password)
                    }
                }
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                        .frame(height: 50)
                    
                    if authVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(isRegistering ? "Sign Up" : "Sign In")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(authVM.isLoading)
            .padding(.top, 10)
            
            // Toggle Register/Login
            Button {
                isRegistering.toggle()
                // Clear the error message when switching modes
                authVM.errorMessage = nil
            } label: {
                Text(isRegistering ? "Already have an account? Sign in" : "Need an account? Sign up")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .disabled(authVM.isLoading)
            .padding(.top, 10)
            
            // Error Message
            if let error = authVM.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 20)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding(.horizontal, 30)
        .padding(.top, 50)
        .alert("Reset Password", isPresented: $showForgotPassword) {
            TextField("Email", text: $resetEmail)
                .keyboardType(.emailAddress)
                .autocapitalization(.none)
            
            Button("Cancel", role: .cancel) {}
            
            Button("Reset") {
                Task {
                    await authVM.resetPassword(email: resetEmail)
                }
            }
        } message: {
            Text("Enter your email to receive a password reset link.")
        }
    }
}
class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if targetEnvironment(simulator)
        // Use debug provider for simulators
        return AppCheckDebugProvider(app: app)
        #else
        // Use DeviceCheck for real devices
        return DeviceCheckProviderFactory().createProvider(with: app)
        #endif
    }
}


@main
struct ChoreMarketApp: App {
    @StateObject var authVM = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
        AppCheck.setAppCheckProviderFactory(nil)
    }

    var body: some Scene {
        WindowGroup {
            // Decide which view to show based on auth state
            if authVM.isAuthenticated {
                MainView()
                    .environmentObject(authVM)
            } else {
                LoginView()
                    .environmentObject(authVM)
            }
        }
    }
}
