import SwiftUI
import SwiftData

struct ExerciseLibraryView: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@State private var exercises: [TrainingExercise] = []
	@State private var searchText: String = ""
	@State private var isLoading: Bool = false
	@State private var error: String?
	@State private var showingAddEdit: Bool = false
	@State private var editingExercise: TrainingExercise?
	@State private var importing: Bool = false

	var body: some View {
		NavigationStack {
			List {
				if isLoading || importing {
					Section {
						HStack(spacing: 12) {
							ProgressView()
							Text(importing ? "exercise.library.importing".localized : "common.loading".localized)
						}
					}
				}

				if let error = error {
					Section {
						Text(error)
							.font(.caption)
							.foregroundColor(.red)
					}
				}

				let filtered = filteredExercises()
				if filtered.isEmpty && !isLoading && !importing {
					Section {
						Text("exercise.library.empty".localized)
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}

				// Favorites first
				let favorites = filtered.filter { $0.isFavorite }
				if !favorites.isEmpty {
					Section("exercise.library.favorites".localized) {
						ForEach(favorites, id: \.id) { ex in
							ExerciseRow(exercise: ex, onToggleFavorite: { toggleFavorite(ex) }, onEdit: { startEdit(ex) })
								.swipeActions(edge: .trailing, allowsFullSwipe: true) {
									Button(role: .destructive) { deleteExercise(ex) } label: { Label("common.delete".localized, systemImage: "trash") }
								}
						}
					}
				}

				let others = filtered.filter { !$0.isFavorite }
				if !others.isEmpty {
					Section("exercise.library.all".localized) {
						ForEach(others, id: \.id) { ex in
							ExerciseRow(exercise: ex, onToggleFavorite: { toggleFavorite(ex) }, onEdit: { startEdit(ex) })
								.swipeActions(edge: .trailing, allowsFullSwipe: true) {
									Button(role: .destructive) { deleteExercise(ex) } label: { Label("common.delete".localized, systemImage: "trash") }
								}
						}
					}
				}
			}
			.navigationTitle("exercise.library.title".localized)
			.searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("exercise.library.search".localized))
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) {
					Button("common.done".localized) { dismiss() }
				}
				ToolbarItemGroup(placement: .navigationBarTrailing) {
					Button(action: { startAdd() }) {
						Image(systemName: "plus.circle.fill")
					}
					Button(action: { importFromChatGPT() }) {
						Image(systemName: "square.and.arrow.down.on.square")
					}
					.accessibilityLabel("exercise.library.fetch".localized)
				}
			}
			.onAppear { loadExercises() }
		}
		.sheet(isPresented: $showingAddEdit) {
			ExerciseEditorView(exercise: editingExercise, onSave: { saveExercise($0) })
		}
	}

	private func filteredExercises() -> [TrainingExercise] {
		guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			return exercises
		}
		let q = searchText.lowercased()
		return exercises.filter { ex in
			ex.name.lowercased().contains(q) ||
			(ex.category?.lowercased().contains(q) ?? false) ||
			(ex.difficulty?.lowercased().contains(q) ?? false) ||
			(ex.equipment?.lowercased().contains(q) ?? false) ||
			ex.instructions.lowercased().contains(q) ||
			ex.tags.joined(separator: ", ").lowercased().contains(q)
		}
	}

	private func loadExercises() {
		let descriptor = FetchDescriptor<TrainingExercise>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
		exercises = (try? modelContext.fetch(descriptor)) ?? []
	}

	private func startAdd() { editingExercise = nil; showingAddEdit = true }
	private func startEdit(_ ex: TrainingExercise) { editingExercise = ex; showingAddEdit = true }

	private func saveExercise(_ draft: ExerciseDraft) {
		if let editing = editingExercise {
			editing.name = draft.name
			editing.category = draft.category
			editing.difficulty = draft.difficulty
			editing.equipment = draft.equipment
			editing.instructions = draft.instructions
			editing.tags = draft.tags
			editing.isFavorite = draft.isFavorite
		} else {
			let ex = TrainingExercise(name: draft.name, category: draft.category, difficulty: draft.difficulty, equipment: draft.equipment, instructions: draft.instructions, tags: draft.tags, source: "user", isFavorite: draft.isFavorite)
			modelContext.insert(ex)
		}
		try? modelContext.save()
		loadExercises()
	}

	private func deleteExercise(_ ex: TrainingExercise) {
		modelContext.delete(ex)
		try? modelContext.save()
		loadExercises()
	}

	private func toggleFavorite(_ ex: TrainingExercise) {
		ex.isFavorite.toggle()
		try? modelContext.save()
		loadExercises()
	}

	private func importFromChatGPT() {
		guard ChatGPTService.shared.hasValidAPIKey else {
			self.error = "chatgpt.error.missing_api_key".localized
			return
		}
		Task {
			await MainActor.run { importing = true; error = nil }
			let tempDog = Dog(name: "DogLog")
			do {
				let list = try await ChatGPTService.shared.fetchExerciseCatalog(dog: tempDog, analysis: nil)
				for dto in list {
					let exists = try? modelContext.fetch(FetchDescriptor<TrainingExercise>(predicate: #Predicate { $0.name == dto.name }))
					if (exists?.isEmpty ?? true) {
						let ex = TrainingExercise(name: dto.name, category: dto.category, difficulty: dto.difficulty, equipment: dto.equipment, instructions: dto.instructions, tags: dto.tags ?? [], source: dto.source ?? "chatgpt", isFavorite: false)
						modelContext.insert(ex)
					}
				}
				try? modelContext.save()
				await MainActor.run { loadExercises() }
			} catch {
				await MainActor.run { self.error = error.localizedDescription }
			}
			await MainActor.run { importing = false }
		}
	}
}

private struct ExerciseRow: View {
	let exercise: TrainingExercise
	let onToggleFavorite: () -> Void
	let onEdit: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(alignment: .firstTextBaseline) {
				Text(exercise.name)
					.font(.headline)
				Spacer()
				Button(action: onToggleFavorite) {
					Image(systemName: exercise.isFavorite ? "heart.fill" : "heart")
						.foregroundColor(exercise.isFavorite ? .red : .secondary)
				}
				.buttonStyle(.plain)
			}

			if let category = exercise.category, !category.isEmpty {
				Label(category, systemImage: "tag")
					.font(.caption)
					.foregroundColor(.secondary)
			}

			if !exercise.tags.isEmpty {
				Text(exercise.tags.joined(separator: ", "))
					.font(.caption2)
					.foregroundColor(.secondary)
			}

			Text(exercise.instructions)
				.font(.caption)
				.foregroundColor(.secondary)
		}
		.contentShape(Rectangle())
		.onTapGesture { onEdit() }
	}
}

private struct ExerciseEditorView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var draft: ExerciseDraft
	let onSave: (ExerciseDraft) -> Void

	init(exercise: TrainingExercise?, onSave: @escaping (ExerciseDraft) -> Void) {
		self.onSave = onSave
		self._draft = State(initialValue: ExerciseDraft(exercise))
	}

	var body: some View {
		NavigationStack {
			Form {
				Section(header: Text("exercise.field.basic".localized)) {
					TextField("exercise.field.name".localized, text: $draft.name)
					TextField("exercise.field.category".localized, text: $draft.category)
					TextField("exercise.field.difficulty".localized, text: $draft.difficulty)
					TextField("exercise.field.equipment".localized, text: $draft.equipment)
				}
				Section(header: Text("exercise.field.instructions".localized)) {
					TextEditor(text: $draft.instructions)
						.frame(minHeight: 120)
				}
				Section(header: Text("exercise.field.tags".localized)) {
					TextField("exercise.field.tags_placeholder".localized, text: Binding(
						get: { draft.tags.joined(separator: ", ") },
						set: { draft.tags = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
					))
					Toggle("exercise.field.favorite".localized, isOn: $draft.isFavorite)
				}
			}
			.navigationTitle(draft.id == nil ? "exercise.library.add".localized : "common.edit".localized)
			.toolbar {
				ToolbarItem(placement: .navigationBarLeading) { Button("common.cancel".localized) { dismiss() } }
				ToolbarItem(placement: .navigationBarTrailing) { Button("common.save".localized) { onSave(draft); dismiss() } }
			}
		}
	}
}

private struct ExerciseDraft {
	var id: UUID?
	var name: String
	var category: String
	var difficulty: String
	var equipment: String
	var instructions: String
	var tags: [String]
	var isFavorite: Bool

	init(_ ex: TrainingExercise?) {
		self.id = ex?.id
		self.name = ex?.name ?? ""
		self.category = ex?.category ?? ""
		self.difficulty = ex?.difficulty ?? ""
		self.equipment = ex?.equipment ?? ""
		self.instructions = ex?.instructions ?? ""
		self.tags = ex?.tags ?? []
		self.isFavorite = ex?.isFavorite ?? false
	}
}


