import SwiftUI
import SwiftData
import PhotosUI

struct AddEditDogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let dog: Dog?
    
    @State private var name = ""
    @State private var breed = ""
    @State private var dateOfBirth = Date()
    @State private var gender = "dog.male".localized
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    
    private var genders: [String] {
        ["dog.male".localized, "dog.female".localized]
    }
    private var isEditing: Bool { dog != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("dog.basic_information".localized) {
                    TextField("dog.dog_name".localized, text: $name)
                    TextField("dog.breed".localized, text: $breed)
                    
                    DatePicker("dog.date_of_birth".localized, selection: $dateOfBirth, displayedComponents: .date)
                    
                    Picker("dog.gender".localized, selection: $gender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(gender).tag(gender)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("dog.photo".localized) {
                    VStack(alignment: .leading, spacing: 12) {
                        // Photo picker
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            HStack {
                                Image(systemName: "camera.fill")
                                    .foregroundColor(.blue)
                                Text(photoData == nil ? "dog.add_photo".localized : "dog.change_photo".localized)
                                    .foregroundColor(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // Show current photo if available
                        if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                            HStack {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .cornerRadius(12)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("dog.profile_photo".localized)
                                        .font(.headline)
                                    
                                    Button("dog.remove_photo".localized) {
                                        self.photoData = nil
                                    }
                                    .font(.caption)
                                    .foregroundColor(.red)
                                }
                                
                                Spacer()
                            }
                        }
                    }
                }
                
                Section("dog.notes".localized) {
                    TextField("dog.additional_notes".localized, text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "dog.edit_dog".localized : "dog.add_dog".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("common.cancel".localized) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("common.save".localized) {
                        saveDog()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let dog = dog {
                loadDogData(dog)
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let newItem = newItem {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        photoData = data
                    }
                }
            }
        }
    }
    
    private func loadDogData(_ dog: Dog) {
        name = dog.name
        breed = dog.breed ?? ""
        dateOfBirth = dog.dateOfBirth ?? Date()
        gender = dog.gender ?? "dog.male".localized
        notes = dog.notes ?? ""
        photoData = dog.photoData
    }
    
    private func saveDog() {
        if let dog = dog {
            // Editing existing dog
            dog.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            dog.breed = breed.trimmingCharacters(in: .whitespacesAndNewlines)
            dog.dateOfBirth = dateOfBirth
            dog.gender = gender
            dog.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            dog.photoData = photoData
        } else {
            // Creating new dog
            let newDog = Dog(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                breed: breed.trimmingCharacters(in: .whitespacesAndNewlines),
                dateOfBirth: dateOfBirth,
                gender: gender,
                notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                photoData: photoData
            )
            modelContext.insert(newDog)
        }
        
        do {
            try modelContext.save()
            // If editing an existing dog, invalidate caches so training week can be refreshed
            if let existingDog = dog {
                ChatGPTService.shared.invalidateCache(for: existingDog.id)
            }
            dismiss()
        } catch {
            print("Error saving dog: \(error)")
        }
    }
}

struct AddEditDogView_Previews: PreviewProvider {
    static var previews: some View {
        AddEditDogView(dog: nil)
    }
}