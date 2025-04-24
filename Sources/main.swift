// The Swift Programming Language
// https://docs.swift.org/swift-book

import SwiftUI
import UserNotifications
import CoreLocation
import DeviceActivity // For Screen Time API integration

// MARK: - Main App Structure
class AtomicBreakApp {
    var userProfile = UserProfile()
    var habitTracker = HabitTracker()
    var cueManager = CueManager()
    var rewardSystem = RewardSystem()
    var interventionSystem = InterventionSystem()
    
    func setup() {
        // Initial app setup and onboarding
        userProfile.createProfile()
        habitTracker.identifyProblemApps()
        cueManager.analyzeUsagePatterns()
        rewardSystem.setupRewards()
        interventionSystem.setupInterventions()
    }
    
    func dailyCheckIn() {
        // Daily reflection and progress tracking
        habitTracker.updateDailyStats()
        cueManager.adjustTriggers()
        rewardSystem.provideDailyRewards()
        userProfile.updateProgress()
    }
}

// MARK: - User Profile
class UserProfile {
    var name: String = ""
    var targetApps: [String] = []
    var dailyTimeLimits: [String: Int] = [:] // minutes
    var progressHistory: [String: [String: Int]] = [:]
    var replacementActivities: [String] = []
    var implementationIntentions: [String] = []
    var habitTracker: HabitTracker?
    
    func createProfile() {
        // Set up user profile with addiction targets and goals
        // This would be a UI flow to collect user info
        // For demonstration, using mock data
        name = "User"
        targetApps = ["Instagram", "Facebook", "TikTok"]
        dailyTimeLimits = ["Instagram": 30, "Facebook": 20, "TikTok": 15] // minutes
        replacementActivities = ["Reading", "Walking", "Meditation"]
        implementationIntentions = [
            "When I feel bored, I will read instead of opening Instagram",
            "After lunch, I will take a 10-minute walk instead of checking Facebook"
        ]
    }
    
    func updateProgress() {
        // Update user progress based on daily activity
        guard let tracker = habitTracker else { return }
        
        let today = getCurrentDate()
        var todayProgress: [String: Int] = [:]
        
        for app in targetApps {
            todayProgress[app] = tracker.getUsageTime(app: app)
        }
        
        progressHistory[today] = todayProgress
    }
}

// MARK: - Habit Tracker
class HabitTracker {
    var problemApps: [String: [String: Int]] = [:]
    var usageData: [String: [String: Int]] = [:]
    var streaks: [String: Int] = [:]
    var userProfile: UserProfile?
    
    func identifyProblemApps() {
        // Analyze and identify apps the user is addicted to
        // This would use ScreenTime API to get actual usage data
        // For demonstration, using mock data
        problemApps = [
            "Instagram": ["avgDailyUsage": 120, "openCount": 45],
            "Facebook": ["avgDailyUsage": 90, "openCount": 30],
            "TikTok": ["avgDailyUsage": 60, "openCount": 25]
        ]
    }
    
    func updateDailyStats() {
        // Update daily usage statistics
        let today = getCurrentDate()
        
        // This would use ScreenTime API to get actual usage data
        // For demonstration, using mock data
        usageData[today] = [
            "Instagram": 65, // minutes
            "Facebook": 40,
            "TikTok": 30
        ]
        
        updateStreaks()
    }
    
    func updateStreaks() {
        guard let profile = userProfile else { return }
        let today = getCurrentDate()
        
        if let todayData = usageData[today] {
            for (app, timeSpent) in todayData {
                if let limit = profile.dailyTimeLimits[app] {
                    if timeSpent <= limit {
                        streaks[app] = (streaks[app] ?? 0) + 1
                    } else {
                        streaks[app] = 0
                    }
                }
            }
        }
    }
    
    func getUsageTime(app: String) -> Int {
        let today = getCurrentDate()
        return usageData[today]?[app] ?? 0
    }
}

// MARK: - Cue Manager
class CueManager {
    var usagePatterns: [String: [String]] = [:]
    var triggerTimes: [String] = []
    var triggerLocations: [[String: Any]] = []
    var triggerEmotions: [[String: String]] = []
    
    func analyzeUsagePatterns() {
        // Analyze when and how the user accesses problem apps
        // This would use actual usage data and pattern recognition
        // For demonstration, using mock data
        usagePatterns = [
            "peakTimes": ["7:00-8:00", "12:00-13:00", "21:00-23:00"],
            "frequentLocations": ["Home", "Work", "Commute"],
            "emotionalStates": ["Bored", "Stressed", "Tired"]
        ]
        
        createInterventionTriggers()
    }
    
    func createInterventionTriggers() {
        // Create triggers for interventions based on usage patterns
        triggerTimes = ["7:00", "12:00", "21:00"] // Times to send notifications
        
        triggerLocations = [
            ["name": "Home", "lat": 40.7128, "long": -74.0060],
            ["name": "Work", "lat": 40.7112, "long": -74.0055]
        ]
        
        triggerEmotions = [
            ["emotion": "Bored", "replacement": "Try reading for 10 minutes"],
            ["emotion": "Stressed", "replacement": "Try 5 minutes of deep breathing"]
        ]
    }
    
    func adjustTriggers() {
        // Adjust triggers based on recent usage data
        // This would dynamically adjust based on actual user behavior
    }
}

// MARK: - Reward System
class RewardSystem {
    var rewards: [[String: Any]] = []
    var milestones: [Int: String] = [:]
    var points: Int = 0
    var userProfile: UserProfile?
    var habitTracker: HabitTracker?
    
    func setupRewards() {
        // Set up reward system for habit building
        rewards = [
            ["name": "Digital Badge", "points": 100],
            ["name": "Achievement Unlock", "points": 250],
            ["name": "Custom Reward", "points": 500]
        ]
        
        milestones = [
            7: "One week streak",
            30: "One month streak",
            90: "Three month streak"
        ]
    }
    
    func provideDailyRewards() {
        guard let profile = userProfile, let tracker = habitTracker else { return }
        
        var pointsEarned = 0
        
        // Award points for staying under limits
        for (app, limit) in profile.dailyTimeLimits {
            let actualUsage = tracker.getUsageTime(app: app)
            if actualUsage <= limit {
                pointsEarned += 20
                
                // Bonus for significantly under limit
                if actualUsage <= limit / 2 {
                    pointsEarned += 20
                }
            }
        }
        
        // Award points for streaks
        for (app, streak) in tracker.streaks {
            if streak > 0 {
                pointsEarned += min(streak * 5, 50) // Cap at 50 points per app
                
                // Check for milestones
                for (days, milestoneName) in milestones {
                    if streak == days {
                        awardMilestone(app: app, milestoneName: milestoneName)
                    }
                }
            }
        }
        
        points += pointsEarned
        checkRewardEligibility()
    }
    
    func awardMilestone(app: String, milestoneName: String) {
        let notification = "Congratulations! You've achieved \(milestoneName) for \(app)!"
        sendNotification(title: "Milestone Achieved", body: notification)
    }
    
    func checkRewardEligibility() {
        for reward in rewards {
            if let rewardPoints = reward["points"] as? Int, points >= rewardPoints,
               let rewardName = reward["name"] as? String {
                grantReward(reward: rewardName, points: rewardPoints)
                points -= rewardPoints
            }
        }
    }
    
    func grantReward(reward: String, points: Int) {
        let notification = "You've earned the \(reward)!"
        sendNotification(title: "Reward Earned", body: notification)
    }
}

// MARK: - Intervention System
class InterventionSystem {
    var interventions: [[String: String]] = []
    var triggeredInterventions: [String: Int] = [:]
    var cueManager: CueManager?
    
    func setupInterventions() {
        // Set up intervention strategies
        
        // Make it obvious interventions (make trigger moments visible)
        interventions.append([
            "type": "obvious",
            "name": "Usage Alert",
            "action": "Show notification with current usage time when app opens"
        ])
        
        // Make it unattractive interventions
        interventions.append([
            "type": "unattractive",
            "name": "Distraction Reminder",
            "action": "Show what you're missing while using the app"
        ])
        
        // Make it difficult interventions
        interventions.append([
            "type": "difficult",
            "name": "Friction Builder",
            "action": "Add 20-second delay before opening problem apps"
        ])
        
        // Make it unsatisfying interventions
        interventions.append([
            "type": "unsatisfying",
            "name": "Goal Reminder",
            "action": "Show time lost towards personal goals"
        ])
    }
    
    func triggerTimeBasedInterventions() {
        guard let manager = cueManager else { return }
        
        let currentTime = getCurrentTime()
        
        for triggerTime in manager.triggerTimes {
            if currentTime == triggerTime {
                let intervention = selectIntervention()
                applyIntervention(intervention: intervention)
            }
        }
    }
    
    func triggerLocationBasedInterventions(location: CLLocation) {
        guard let manager = cueManager else { return }
        
        for locationDict in manager.triggerLocations {
            if let lat = locationDict["lat"] as? Double,
               let long = locationDict["long"] as? Double,
               let name = locationDict["name"] as? String {
                
                let targetLocation = CLLocation(latitude: lat, longitude: long)
                
                if isNearLocation(currentLocation: location, targetLocation: targetLocation) {
                    let intervention = selectIntervention()
                    applyIntervention(intervention: intervention)
                }
            }
        }
    }
    
    func selectIntervention() -> [String: String] {
        // In a real app, this would use more sophisticated logic
        return interventions.randomElement() ?? interventions[0]
    }
    
    func applyIntervention(intervention: [String: String]) {
        guard let type = intervention["type"] else { return }
        
        var notificationTitle = "AtomicBreak"
        var notificationBody = ""
        
        switch type {
        case "obvious":
            notificationTitle = "Usage Alert"
            notificationBody = "You've already spent 45 minutes on Instagram today"
        
        case "unattractive":
            notificationTitle = "Time Well Spent?"
            notificationBody = "You could read 10 pages in the time you'll spend scrolling"
        
        case "difficult":
            // In a real app, this would implement app opening delays
            notificationTitle = "Taking a Pause"
            notificationBody = "Let's wait 20 seconds before opening this app"
        
        case "unsatisfying":
            notificationTitle = "Goal Reminder"
            notificationBody = "Every minute on social media is a minute not spent on your goals"
        
        default:
            break
        }
        
        if !notificationBody.isEmpty {
            sendNotification(title: notificationTitle, body: notificationBody)
        }
    }
}

// MARK: - App Delegate
@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, CLLocationManagerDelegate {
    var window: UIWindow?
    var app: AtomicBreakApp?
    var locationManager: CLLocationManager?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Initialize app
        app = AtomicBreakApp()
        app?.setup()
        
        // Setup cross-references
        app?.userProfile.habitTracker = app?.habitTracker
        app?.habitTracker.userProfile = app?.userProfile
        app?.rewardSystem.userProfile = app?.userProfile
        app?.rewardSystem.habitTracker = app?.habitTracker
        app?.interventionSystem.cueManager = app?.cueManager
        
        // Setup notifications
        setupNotifications(application)
        
        // Setup location services
        setupLocationServices()
        
        // Schedule daily check-in
        scheduleDailyCheckIn()
        
        return true
    }
    
    func setupNotifications(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }
    
    func setupLocationServices() {
        locationManager = CLLocationManager()
        locationManager?.delegate = self
        locationManager?.requestAlwaysAuthorization()
        locationManager?.startMonitoringSignificantLocationChanges()
    }
    
    func scheduleDailyCheckIn() {
        let calendar = Calendar.current
        var dateComponents = DateComponents()
        dateComponents.hour = 0
        dateComponents.minute = 1
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let content = UNMutableNotificationContent()
        content.title = "Daily Check-In"
        content.body = "Time to review your progress!"
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: "dailyCheckIn", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        
        // Also perform check-in when app launches
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.app?.dailyCheckIn()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            app?.interventionSystem.triggerLocationBasedInterventions(location: location)
        }
    }
    
    // MARK: - Background Tasks
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Update data in background
        app?.habitTracker.updateDailyStats()
        app?.interventionSystem.triggerTimeBasedInterventions()
        completionHandler(.newData)
    }
}

// MARK: - Helper Functions
func getCurrentDate() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: Date())
}

func getCurrentTime() -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: Date())
}

func isNearLocation(currentLocation: CLLocation, targetLocation: CLLocation) -> Bool {
    let distanceInMeters = currentLocation.distance(from: targetLocation)
    return distanceInMeters < 100 // Within 100 meters
}

func sendNotification(title: String, body: String) {
    let content = UNMutableNotificationContent()
    content.title = title
    content.body = body
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
}

// MARK: - SwiftUI App View
struct ContentView: View {
    @State private var selectedTab = 0
    @State private var userProfile = UserProfile()
    @State private var usageStats: [String: Int] = [:]
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            VStack {
                Text("AtomicBreak")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                Text("Today's App Usage")
                    .font(.headline)
                    .padding(.top)
                
                ForEach(Array(usageStats.keys), id: \.self) { app in
                    HStack {
                        Text(app)
                            .font(.system(size: 16))
                        
                        Spacer()
                        
                        Text("\(usageStats[app] ?? 0) min")
                            .font(.system(size: 16))
                            .foregroundColor(getColorForUsage(app: app, minutes: usageStats[app] ?? 0))
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                Spacer()
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar")
            }
            .tag(0)
            
            // Habits Tab
            VStack {
                Text("Habit Builder")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                List {
                    Section(header: Text("My Implementation Intentions")) {
                        ForEach(userProfile.implementationIntentions, id: \.self) { intention in
                            Text(intention)
                        }
                    }
                    
                    Section(header: Text("Replacement Activities")) {
                        ForEach(userProfile.replacementActivities, id: \.self) { activity in
                            Text(activity)
                        }
                    }
                }
                
                Spacer()
            }
            .tabItem {
                Label("Habits", systemImage: "list.bullet")
            }
            .tag(1)
            
            // Settings Tab
            VStack {
                Text("Settings")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding()
                
                List {
                    Section(header: Text("Daily Time Limits")) {
                        ForEach(Array(userProfile.dailyTimeLimits.keys), id: \.self) { app in
                            HStack {
                                Text(app)
                                Spacer()
                                Text("\(userProfile.dailyTimeLimits[app] ?? 0) min")
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(2)
        }
        .onAppear {
            // Initialize with mock data
            userProfile.createProfile()
            usageStats = ["Instagram": 45, "Facebook": 25, "TikTok": 15]
        }
    }
    
    func getColorForUsage(app: String, minutes: Int) -> Color {
        let limit = userProfile.dailyTimeLimits[app] ?? 30
        
        if minutes > limit {
            return .red
        } else if minutes > limit * 0.8 {
            return .orange
        } else {
            return .green
        }
    }
}

// MARK: - SwiftUI App
@available(iOS 14.0, *)
struct AtomicBreakUIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}