import SwiftUI

struct DogGalleryView: View {
    let dogs: [Dog]
    @Binding var selectedDog: Dog?
    let onShowTutorial: () -> Void
    
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 16) {
                // Regular dogs
                ForEach(dogs, id: \.id) { dog in
                    DogCardView(dog: dog)
                        .onTapGesture {
                            selectedDog = dog
                        }
                }
                
                // Demo dog (always shows last, or only if no dogs)
                DemoCardView()
                    .onTapGesture {
                        onShowTutorial()
                    }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct DogCardView: View {
    let dog: Dog
    
    var body: some View {
        VStack(spacing: 12) {
            // Dog photo or placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray5))
                    .frame(height: 120)
                
                if let profilePhoto = dog.profilePhoto,
                   let uiImage = UIImage(data: profilePhoto.imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(16)
                } else if let photoData = dog.photoData, let uiImage = UIImage(data: photoData) {
                    // Fallback to legacy photo
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                        .cornerRadius(16)
                } else {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 4) {
                // Dog name
                Text(dog.name ?? "dog.unknown_name".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                // Dog age
                if let dateOfBirth = dog.dateOfBirth {
                    Text(String(format: "age.years_old".localized, ageFromDate(dateOfBirth)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Dog breed
                if let breed = dog.breed, !breed.isEmpty {
                    Text(breed)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func ageFromDate(_ date: Date) -> Int {
        Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0
    }
}

struct DemoCardView: View {
    var body: some View {
        VStack(spacing: 12) {
            // Demo icon with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [.blue.opacity(0.6), .purple.opacity(0.6)]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 120)
                
                VStack(spacing: 8) {
                    Image(systemName: "graduationcap.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    
                    Text("tutorial.tutorial_label".localized)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .tracking(1)
                }
            }
            
            VStack(spacing: 4) {
                Text("tutorial.demo_dog_name".localized)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("tutorial.demo_dog_description".localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: .blue.opacity(0.2), radius: 5, x: 0, y: 2)
    }
}

struct DogGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        DogGalleryView(dogs: [], selectedDog: .constant(nil), onShowTutorial: {})
    }
}