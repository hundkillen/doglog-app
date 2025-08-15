import SwiftUI
import SwiftData

struct ContentView: View {
    @Query(sort: \Dog.name) private var dogs: [Dog]
    @State private var showingAddDog = false
    @State private var selectedDog: Dog?
    @State private var showingTutorial = false
    
    // Demo dog instance
    private let demoDog = DemoDog()
    
    var body: some View {
        NavigationView {
            DogGalleryView(dogs: dogs, selectedDog: $selectedDog, onShowTutorial: {
                showingTutorial = true
            })
                .navigationTitle("DogLog")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: { showingAddDog = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                        }
                    }
                }
                .sheet(isPresented: $showingAddDog) {
                    AddEditDogView(dog: nil)
                }
                .sheet(item: $selectedDog) { dog in
                    DogDetailView(dog: dog)
                }
                .sheet(isPresented: $showingTutorial) {
                    TutorialView()
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// Demo dog for tutorial purposes
struct DemoDog {
    let name = "🐕 Try DogLog!"
    let breed = "Tap to learn how to use DogLog"
    let isDemo = true
}

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentPage = 0
    
    private let tutorialPages = [
        TutorialPage(
            title: "Welcome to DogLog! 🐕",
            description: "Track your dog's daily activities and behavior patterns with ease.",
            imageName: "pawprint.circle.fill",
            color: .blue
        ),
        TutorialPage(
            title: "Add Your Dog 📝",
            description: "Start by adding your dog's information using the + button. Include their name, breed, age, and a photo!",
            imageName: "plus.circle.fill",
            color: .green
        ),
        TutorialPage(
            title: "Daily Activities 📅",
            description: "Tap on any day in the calendar to log activities like walks, training, playtime, and more. Rate how each activity went!",
            imageName: "calendar.circle.fill",
            color: .orange
        ),
        TutorialPage(
            title: "Rate Your Days 😊",
            description: "Rate each day as Good, Okay, or Bad to track overall patterns. Add daily notes to remember special moments!",
            imageName: "heart.circle.fill",
            color: .red
        ),
        TutorialPage(
            title: "Test Data 🎲",
            description: "Use the Generate Test Data feature to see how the app works with sample activities and ratings.",
            imageName: "dice.fill",
            color: .purple
        ),
        TutorialPage(
            title: "Ready to Start! 🚀",
            description: "You're all set! Add your first dog and start tracking their daily adventures. Your data will help build better routines!",
            imageName: "checkmark.circle.fill",
            color: .mint
        )
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Page indicator
                HStack(spacing: 8) {
                    ForEach(0..<tutorialPages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? .blue : .gray.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut, value: currentPage)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
                
                // Tutorial content
                TabView(selection: $currentPage) {
                    ForEach(Array(tutorialPages.enumerated()), id: \.offset) { index, page in
                        TutorialPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    if currentPage < tutorialPages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .foregroundColor(.blue)
                        .fontWeight(.medium)
                    } else {
                        Button("Get Started!") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.blue)
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
            .navigationTitle("How to Use DogLog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Skip") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct TutorialPageView: View {
    let page: TutorialPage
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: page.imageName)
                .font(.system(size: 80))
                .foregroundColor(page.color)
                .padding(.top, 40)
            
            VStack(spacing: 16) {
                Text(page.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(page.description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
        }
        .padding()
    }
}