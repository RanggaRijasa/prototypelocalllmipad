//
//  DataListView.swift
//  PrototypeC3A02
//
//  Created by Codex on 04/07/26.
//

import SwiftData
import SwiftUI

struct DataListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StoryEvent.date, order: .reverse) private var events: [StoryEvent]

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView(
                        "No story events",
                        systemImage: "tray",
                        description: Text("Add a sample event to start building the local behaviour timeline.")
                    )
                } else {
                    List {
                        ForEach(events) { event in
                            NavigationLink {
                                StoryEventDetailView(event: event)
                            } label: {
                                StoryEventRow(event: event)
                            }
                        }
                        .onDelete(perform: deleteEvents)
                    }
                }
            }
            .navigationTitle("Data")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        addSampleEvent()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add sample event")
                }
            }
        }
    }

    private func addSampleEvent() {
        let event = SampleDataSeeder.makeTestEvent(date: Date())
        modelContext.insert(event)
        try? modelContext.save()
    }

    private func deleteEvents(at offsets: IndexSet) {
        for offset in offsets {
            modelContext.delete(events[offset])
        }

        try? modelContext.save()
    }
}

private struct StoryEventRow: View {
    let event: StoryEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(event.activity)
                    .font(.headline)

                Spacer()

                Text(event.mood.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(event.mood.isChallenging ? .orange : .green)
            }

            HStack(spacing: 10) {
                Label(event.scene.displayName, systemImage: "clock")
                Label(event.place.displayName, systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(event.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.activity), \(event.mood.displayName), \(event.scene.displayName), \(event.place.displayName)")
    }
}

private struct StoryEventDetailView: View {
    let event: StoryEvent

    var body: some View {
        Form {
            Section("Child") {
                LabeledContent("Name", value: event.childName)
                LabeledContent("Age", value: "\(event.childAge)")
                LabeledContent("Gender", value: event.childGender)
            }

            Section("Story Event") {
                LabeledContent("Activity", value: event.activity)
                LabeledContent("Scene", value: event.scene.displayName)
                LabeledContent("Place", value: event.place.displayName)
                LabeledContent("Mood", value: event.mood.displayName)
                LabeledContent("Date") {
                    Text(event.date, format: .dateTime.month().day().year().hour().minute())
                }
            }

            Section("Reflection") {
                LabeledContent("Reason", value: event.reason ?? "Not recorded")
                LabeledContent("Parent Note", value: event.parentNote ?? "Not recorded")
            }
        }
        .navigationTitle(event.activity)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    DataListView()
        .modelContainer(for: StoryEvent.self, inMemory: true)
}
