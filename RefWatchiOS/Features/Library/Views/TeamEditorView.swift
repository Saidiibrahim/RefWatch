//
//  TeamEditorView.swift
//  RefWatchiOS
//
//  Edit a team with basic fields plus simple Players/Officials editors.
//

import OSLog
import RefWatchCore
import SwiftUI

struct TeamEditorView: View {
  let teamStore: TeamLibraryStoring
  @State var team: TeamRecord

  @State private var editingName: String = ""
  @State private var editingShort: String = ""
  @State private var editingDivision: String = ""

  @State private var showingAddPlayer = false
  @State private var newPlayerName = ""
  @State private var newPlayerNumber = ""
  @State private var editingPlayer: PlayerRecord?

  @State private var showingAddOfficial = false
  @State private var newOfficialName = ""
  @State private var newOfficialRole: TeamOfficialRole = .manager
  @State private var editingOfficial: TeamOfficialRecord?
  @State private var errorMessage: String?

  var body: some View {
    Form {
      Section("Basics") {
        TextField("Name", text: self.$editingName)
        TextField("Short Name", text: self.$editingShort)
        TextField("Division", text: self.$editingDivision)
      }
      .alert("Unable to Update Team", isPresented: Binding(
        get: { self.errorMessage != nil },
        set: { if $0 == false { self.errorMessage = nil } }
      )) {
        Button("OK", role: .cancel) { self.errorMessage = nil }
      } message: {
        Text(self.errorMessage ?? "Sign in on your phone to edit this team.")
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
              Button { self.editingPlayer = p } label: { Label("Edit", systemImage: "pencil") }
                .tint(.blue)
              Button(role: .destructive) { self.deletePlayer(p) } label: { Label("Delete", systemImage: "trash") }
            }
          }
        }
        Button { self.showingAddPlayer = true } label: { Label("Add Player", systemImage: "person.badge.plus") }
      }
      Section("Officials") {
        if sortedOfficials.isEmpty {
          Text("No officials added").foregroundStyle(.secondary)
        } else {
          ForEach(sortedOfficials, id: \.id) { o in
            HStack { Text(o.name); Spacer(); Text(o.roleRaw).foregroundStyle(.secondary) }
              .swipeActions {
                Button { self.editingOfficial = o } label: { Label("Edit", systemImage: "pencil") }
                  .tint(.blue)
                Button(role: .destructive) { self.deleteOfficial(o) } label: { Label("Delete", systemImage: "trash") }
              }
          }
        }
        Button { self.showingAddOfficial = true } label: {
          Label("Add Official", systemImage: "person.2.badge.gearshape")
        }
      }
    }
    .navigationTitle(self.team.name)
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { self.save() }
          .disabled(self.editingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .onAppear {
      self.editingName = self.team.name
      self.editingShort = self.team.shortName ?? ""
      self.editingDivision = self.team.division ?? ""
    }
    .sheet(isPresented: self.$showingAddPlayer) {
      NavigationStack {
        Form {
          TextField("Name", text: self.$newPlayerName)
          TextField("Number", text: self.$newPlayerNumber).keyboardType(.numberPad)
        }
        .navigationTitle("Add Player")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { self.showingAddPlayer = false } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") { self.addPlayer() }
              .disabled(self.newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .sheet(item: self.$editingPlayer) { player in
      NavigationStack {
        PlayerEditForm(player: player) { name, number in
          player.name = name
          player.number = number
          do {
            try self.teamStore.updatePlayer(player)
          } catch {
            AppLog.library.error("Failed to update player: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to edit players.")
          }
          self.editingPlayer = nil
        }
      }
    }
    .sheet(isPresented: self.$showingAddOfficial) {
      NavigationStack {
        Form {
          TextField("Name", text: self.$newOfficialName)
          Picker("Role", selection: self.$newOfficialRole) {
            ForEach(TeamOfficialRole.allCases, id: \.self) { r in
              Text(r.rawValue).tag(r)
            }
          }
        }
        .navigationTitle("Add Official")
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button("Cancel") { self.showingAddOfficial = false } }
          ToolbarItem(placement: .confirmationAction) {
            Button("Add") { self.addOfficial() }
              .disabled(self.newOfficialName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
          }
        }
      }
    }
    .sheet(item: self.$editingOfficial) { official in
      NavigationStack {
        OfficialEditForm(official: official) { name, role in
          official.name = name
          official.roleRaw = role.rawValue
          do {
            try self.teamStore.updateOfficial(official)
          } catch {
            AppLog.library.error("Failed to update official: \(error.localizedDescription, privacy: .public)")
            self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to edit officials.")
          }
          self.editingOfficial = nil
        }
      }
    }
  }

  private func save() {
    self.team.name = self.editingName.trimmingCharacters(in: .whitespacesAndNewlines)
    self.team.shortName = self.editingShort.trimmingCharacters(in: .whitespacesAndNewlines)
    self.team.division = self.editingDivision.trimmingCharacters(in: .whitespacesAndNewlines)
    do {
      try self.teamStore.updateTeam(self.team)
    } catch {
      AppLog.library.error("Failed to save team: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to update this team.")
    }
  }

  private func addPlayer() {
    let num = Int(newPlayerNumber)
    do {
      _ = try self.teamStore.addPlayer(
        to: self.team,
        name: self.newPlayerName.trimmingCharacters(in: .whitespacesAndNewlines),
        number: num)
      self.newPlayerName = ""; self.newPlayerNumber = ""; self.showingAddPlayer = false
    } catch {
      AppLog.library.error("Failed to add player: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to add players.")
    }
  }

  private func deletePlayer(_ p: PlayerRecord) {
    do {
      try self.teamStore.deletePlayer(p)
    } catch {
      AppLog.library.error("Failed to delete player: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to delete players.")
    }
  }

  private func addOfficial() {
    do {
      _ = try self.teamStore.addOfficial(
        to: self.team,
        name: self.newOfficialName.trimmingCharacters(in: .whitespacesAndNewlines),
        roleRaw: self.newOfficialRole.rawValue)
      self.newOfficialName = ""; self.showingAddOfficial = false
    } catch {
      AppLog.library.error("Failed to add official: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to add officials.")
    }
  }

  private func deleteOfficial(_ o: TeamOfficialRecord) {
    do {
      try self.teamStore.deleteOfficial(o)
    } catch {
      AppLog.library.error("Failed to delete official: \(error.localizedDescription, privacy: .public)")
      self.errorMessage = self.errorDisplayMessage(for: error, fallback: "Sign in to delete officials.")
    }
  }

  private func errorDisplayMessage(for error: Error, fallback: String) -> String {
    if let authError = error as? PersistenceAuthError {
      return authError.errorDescription ?? fallback
    }
    if let localized = (error as NSError).localizedFailureReason {
      return localized
    }
    return fallback
  }
}

#Preview {
  let store = InMemoryTeamLibraryStore()
  guard let team = try? store.createTeam(name: "Leeds United", shortName: "LEE", division: "U18") else {
    fatalError("Failed to create preview team")
  }
  return NavigationStack { TeamEditorView(teamStore: store, team: team) }
}

// MARK: - Sorting helpers

extension TeamEditorView {
  private var sortedPlayers: [PlayerRecord] {
    self.team.players.sorted { lhs, rhs in
      let ln = lhs.number ?? Int.max
      let rn = rhs.number ?? Int.max
      if ln != rn { return ln < rn }
      return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
  }

  private var sortedOfficials: [TeamOfficialRecord] {
    func rank(_ roleRaw: String?) -> Int {
      guard let raw = roleRaw, let role = TeamOfficialRole(rawValue: raw) else { return Int.max }
      return TeamOfficialRole.allCases.firstIndex(of: role) ?? Int.max
    }
    return self.team.officials.sorted { lhs, rhs in
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
      TextField("Name", text: self.$name)
      TextField("Number", text: self.$number).keyboardType(.numberPad)
    }
    .navigationTitle("Edit Player")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { self.dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { self.onSave(self.name.trimmingCharacters(in: .whitespacesAndNewlines), Int(self.number)) }
          .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .onAppear {
      self.name = self.player.name
      self.number = self.player.number.map(String.init) ?? ""
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
      TextField("Name", text: self.$name)
      Picker("Role", selection: self.$role) {
        ForEach(TeamOfficialRole.allCases, id: \.self) { Text($0.rawValue).tag($0) }
      }
    }
    .navigationTitle("Edit Official")
    .toolbar {
      ToolbarItem(placement: .cancellationAction) { Button("Cancel") { self.dismiss() } }
      ToolbarItem(placement: .confirmationAction) {
        Button("Save") { self.onSave(self.name.trimmingCharacters(in: .whitespacesAndNewlines), self.role) }
          .disabled(self.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .onAppear {
      self.name = self.official.name
      self.role = TeamOfficialRole(rawValue: self.official.roleRaw) ?? .manager
    }
  }
}
