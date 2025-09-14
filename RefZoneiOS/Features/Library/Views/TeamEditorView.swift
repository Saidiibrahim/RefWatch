//
//  TeamEditorView.swift
//  RefZoneiOS
//
//  Edit a team with basic fields plus simple Players/Officials editors.
//

import SwiftUI
import RefWatchCore

struct TeamEditorView: View {
    let teamStore: TeamLibraryStoring
    @State var team: TeamRecord

    @State private var editingName: String = ""
    @State private var editingShort: String = ""
    @State private var editingDivision: String = ""

    @State private var showingAddPlayer = false
    @State private var newPlayerName = ""
    @State private var newPlayerNumber = ""
    @State private var editingPlayer: PlayerRecord? = nil

    @State private var showingAddOfficial = false
    @State private var newOfficialName = ""
    @State private var newOfficialRole: TeamOfficialRole = .manager
    @State private var editingOfficial: TeamOfficialRecord? = nil

    var body: some View {
        Form {
            Section("Basics") {
                TextField("Name", text: $editingName)
                TextField("Short Name", text: $editingShort)
                TextField("Division", text: $editingDivision)
            }
            Section("Players") {
                if sortedPlayers.isEmpty {
                    Text("No players added").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedPlayers, id: \.id) { p in
                        HStack {
                            if let n = p.number { Text("#\(n)").monospaced() }
                            Text(p.name)
                            Spacer()
                        }
                        .swipeActions {
                            Button { editingPlayer = p } label: { Label("Edit", systemImage: "pencil") }
                                .tint(.blue)
                            Button(role: .destructive) { deletePlayer(p) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
                Button { showingAddPlayer = true } label: { Label("Add Player", systemImage: "person.badge.plus") }
            }
            Section("Officials") {
                if sortedOfficials.isEmpty {
                    Text("No officials added").foregroundStyle(.secondary)
                } else {
                    ForEach(sortedOfficials, id: \.id) { o in
                        HStack { Text(o.name); Spacer(); Text(o.roleRaw).foregroundStyle(.secondary) }
                            .swipeActions {
                                Button { editingOfficial = o } label: { Label("Edit", systemImage: "pencil") }
                                    .tint(.blue)
                                Button(role: .destructive) { deleteOfficial(o) } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
                Button { showingAddOfficial = true } label: { Label("Add Official", systemImage: "person.2.badge.gearshape") }
            }
        }
        .navigationTitle(team.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }.disabled(editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            editingName = team.name
            editingShort = team.shortName ?? ""
            editingDivision = team.division ?? ""
        }
        .sheet(isPresented: $showingAddPlayer) {
            NavigationStack {
                Form {
                    TextField("Name", text: $newPlayerName)
                    TextField("Number", text: $newPlayerNumber).keyboardType(.numberPad)
                }
                .navigationTitle("Add Player")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddPlayer = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { addPlayer() }.disabled(newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
            }
        }
        .sheet(item: $editingPlayer) { player in
            NavigationStack {
                PlayerEditForm(player: player) { name, number in
                    player.name = name
                    player.number = number
                    do { try teamStore.updatePlayer(player) } catch { }
                    editingPlayer = nil
                }
            }
        }
        .sheet(isPresented: $showingAddOfficial) {
            NavigationStack {
                Form {
                    TextField("Name", text: $newOfficialName)
                    Picker("Role", selection: $newOfficialRole) {
                        ForEach(TeamOfficialRole.allCases, id: \.self) { r in
                            Text(r.rawValue).tag(r)
                        }
                    }
                }
                .navigationTitle("Add Official")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingAddOfficial = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Add") { addOfficial() }.disabled(newOfficialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
                }
            }
        }
        .sheet(item: $editingOfficial) { official in
            NavigationStack {
                OfficialEditForm(official: official) { name, role in
                    official.name = name
                    official.roleRaw = role.rawValue
                    do { try teamStore.updateOfficial(official) } catch { }
                    editingOfficial = nil
                }
            }
        }
    }

    private func save() {
        team.name = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
        team.shortName = editingShort.trimmingCharacters(in: .whitespacesAndNewlines)
        team.division = editingDivision.trimmingCharacters(in: .whitespacesAndNewlines)
        do { try teamStore.updateTeam(team) } catch { }
    }

    private func addPlayer() {
        let num = Int(newPlayerNumber)
        do {
            _ = try teamStore.addPlayer(to: team, name: newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines), number: num)
            newPlayerName = ""; newPlayerNumber = ""; showingAddPlayer = false
        } catch { }
    }

    private func deletePlayer(_ p: PlayerRecord) {
        do { try teamStore.deletePlayer(p) } catch { }
    }

    private func addOfficial() {
        do {
            _ = try teamStore.addOfficial(to: team, name: newOfficialName.trimmingCharacters(in: .whitespacesAndNewlines), roleRaw: newOfficialRole.rawValue)
            newOfficialName = ""; showingAddOfficial = false
        } catch { }
    }

    private func deleteOfficial(_ o: TeamOfficialRecord) {
        do { try teamStore.deleteOfficial(o) } catch { }
    }
}

#Preview {
    let store = InMemoryTeamLibraryStore()
    let team = try! store.createTeam(name: "Leeds United", shortName: "LEE", division: "U18")
    return NavigationStack { TeamEditorView(teamStore: store, team: team) }
}

// MARK: - Sorting helpers
private extension TeamEditorView {
    var sortedPlayers: [PlayerRecord] {
        team.players.sorted { lhs, rhs in
            let ln = lhs.number ?? Int.max
            let rn = rhs.number ?? Int.max
            if ln != rn { return ln < rn }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    var sortedOfficials: [TeamOfficialRecord] {
        func rank(_ roleRaw: String?) -> Int {
            guard let raw = roleRaw, let role = TeamOfficialRole(rawValue: raw) else { return Int.max }
            return TeamOfficialRole.allCases.firstIndex(of: role) ?? Int.max
        }
        return team.officials.sorted { lhs, rhs in
            let lr = rank(lhs.roleRaw)
            let rr = rank(rhs.roleRaw)
            if lr != rr { return lr < rr }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

// MARK: - Inline edit forms
private struct PlayerEditForm: View {
    let player: PlayerRecord
    var onSave: (String, Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var number: String = ""
    var body: some View {
        Form {
            TextField("Name", text: $name)
            TextField("Number", text: $number).keyboardType(.numberPad)
        }
        .navigationTitle("Edit Player")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), Int(number)) }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            name = player.name
            number = player.number.map(String.init) ?? ""
        }
    }
}

private struct OfficialEditForm: View {
    let official: TeamOfficialRecord
    var onSave: (String, TeamOfficialRole) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @State private var role: TeamOfficialRole = .manager
    var body: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Role", selection: $role) {
                ForEach(TeamOfficialRole.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
        }
        .navigationTitle("Edit Official")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { onSave(name.trimmingCharacters(in: .whitespacesAndNewlines), role) }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            name = official.name
            role = TeamOfficialRole(rawValue: official.roleRaw) ?? .manager
        }
    }
}
