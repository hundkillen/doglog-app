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
    @State private var gender = "Male"
    @State private var notes = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var photoData: Data?
    
    private let genders = ["Male", "Female"]
    private var isEditing: Bool { dog != nil }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Basic Information") {
                    TextField("Dog Name", text: $name)
                    TextField("Breed", text: $breed)
                    
                    DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    
                    Picker("Gender", selection: $gender) {
                        ForEach(genders, id: \.self) { gender in
                            Text(gender).tag(gender)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Photo") {
                    HStack {
                        if let photoData = photoData, let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "camera")
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        VStack(alignment: .leading) {
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Text(photoData == nil ? "Add Photo" : "Change Photo")
                                    .foregroundColor(.blue)
                            }
                            
                            if photoData != nil {
                                Button("Remove Photo") {
                                    photoData = nil
                                    selectedPhotoItem = nil
                                }
                                .foregroundColor(.red)
                            }
                        }
                        
                        Spacer()
                    }
                }
                
                Section("Notes") {
                    TextField("Additional notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(isEditing ? "Edit Dog" : "Add Dog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
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
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = data
                }
            }
        }
    }
    
    private func loadDogData(_ dog: Dog) {
        name = dog.name ?? ""
        breed = dog.breed ?? ""
        dateOfBirth = dog.dateOfBirth ?? Date()
        gender = dog.gender ?? "Male"
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