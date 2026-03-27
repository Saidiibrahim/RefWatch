//
//  MatchSheetImportPickerSheet.swift
//  RefWatchiOS
//
//  Collects screenshots and runs the server-backed parser before review.
//

import PhotosUI
import SwiftUI
import UIKit

struct MatchSheetImportPickerSheet: View {
  let side: MatchSheetSide
  let service: MatchSheetImportProviding
  let expectedTeamName: String
  let onCancel: () -> Void
  let onImported: (MatchSheetImportDraft) -> Void

  @State private var selectedPhotoItems: [PhotosPickerItem] = []
  @State private var selectedPhotoLoadID = 0
  @State private var viewModel: MatchSheetImportViewModel

  init(
    side: MatchSheetSide,
    service: MatchSheetImportProviding,
    expectedTeamName: String,
    onCancel: @escaping () -> Void,
    onImported: @escaping (MatchSheetImportDraft) -> Void)
  {
    self.side = side
    self.service = service
    self.expectedTeamName = expectedTeamName
    self.onCancel = onCancel
    self.onImported = onImported
    _viewModel = State(initialValue: MatchSheetImportViewModel(
      side: side,
      expectedTeamName: expectedTeamName,
      service: service))
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Import") {
          Text("Add one or more screenshots for the \(self.side.title.lowercased()) team. The parser keeps results as a draft until you confirm them.")
            .font(.footnote)
            .foregroundStyle(.secondary)

          if self.expectedTeamName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            LabeledContent("Expected Team") {
              Text(self.expectedTeamName)
            }
          }

          LabeledContent("Screenshots") {
            Text("\(self.viewModel.attachments.count)")
          }

          LabeledContent("Upload Size") {
            Text(Self.formatByteCount(self.viewModel.totalByteCount))
          }
        }

        Section("Screenshots") {
          PhotosPicker(
            selection: self.photoSelectionBinding,
            maxSelectionCount: MatchSheetImportViewModel.maxScreenshotCount,
            matching: .images,
            photoLibrary: .shared())
          {
            Label("Add Screenshots", systemImage: "photo.on.rectangle.angled")
          }
          .accessibilityLabel("Add screenshots")
          .disabled(self.viewModel.isPreparingAttachments || self.viewModel.isParsing)

          if TestEnvironment.matchSheetImportUITestMode != nil {
            Button("Use Test Screenshot") {
              Task {
                await self.viewModel.appendImageData(
                  Self.makeUITestScreenshotData(),
                  filename: "ui-test-match-sheet.jpg")
              }
            }
            .accessibilityIdentifier("match-sheet-import-use-test-screenshot")
          }

          if self.viewModel.isPreparingAttachments {
            HStack(spacing: 10) {
              ProgressView()
              Text("Preparing screenshots…")
                .foregroundStyle(.secondary)
            }
          }

          if self.viewModel.attachments.isEmpty {
            Text("No screenshots added yet")
              .foregroundStyle(.secondary)
          } else {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 12) {
                ForEach(self.viewModel.attachments) { attachment in
                  VStack(alignment: .leading, spacing: 8) {
                    if let image = attachment.uiImage {
                      Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 96, height: 128)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    Text(attachment.filename)
                      .font(.caption2)
                      .lineLimit(1)
                    Button("Remove") {
                      self.viewModel.removeAttachment(id: attachment.id)
                    }
                    .font(.caption)
                  }
                  .frame(width: 110)
                }
              }
              .padding(.vertical, 4)
            }
          }

          if let attachmentError = self.viewModel.attachmentError {
            Text(attachmentError)
              .font(.footnote)
              .foregroundStyle(.orange)
          }

          if let transportError = self.viewModel.transportError {
            Text(transportError)
              .font(.footnote)
              .foregroundStyle(.red)
          }
        }

        Section {
          Button(self.viewModel.transportError == nil ? "Parse Screenshots" : "Retry Parse") {
            Task {
              if let draft = await self.viewModel.parse() {
                self.onImported(draft)
              }
            }
          }
          .disabled(self.viewModel.canParse == false)
          .accessibilityIdentifier("match-sheet-import-parse")

          if self.viewModel.isParsing {
            HStack(spacing: 10) {
              ProgressView()
              Text("Parsing screenshots…")
                .foregroundStyle(.secondary)
            }
          }
        }
      }
      .navigationTitle("\(self.side.title) Import")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            self.onCancel()
          }
        }
      }
    }
    .task(id: self.selectedPhotoLoadID) {
      guard self.selectedPhotoLoadID > 0, self.selectedPhotoItems.isEmpty == false else { return }

      let items = self.selectedPhotoItems
      self.selectedPhotoItems = []
      let existingCount = self.viewModel.attachments.count

      for (index, item) in items.enumerated() {
        let data = try? await item.loadTransferable(type: Data.self)
        await self.viewModel.appendImageData(
          data,
          filename: "\(self.side.rawValue)-match-sheet-\(existingCount + index + 1).jpg")
      }
    }
  }

  private var photoSelectionBinding: Binding<[PhotosPickerItem]> {
    Binding(
      get: { self.selectedPhotoItems },
      set: { newValue in
        self.selectedPhotoItems = newValue
        if newValue.isEmpty == false {
          self.selectedPhotoLoadID += 1
        }
      })
  }

  private static func makeUITestScreenshotData() -> Data {
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 320, height: 640))
    let image = renderer.image { context in
      UIColor.systemBackground.setFill()
      context.fill(CGRect(x: 0, y: 0, width: 320, height: 640))

      UIColor.label.setFill()
      let paragraph = NSMutableParagraphStyle()
      paragraph.alignment = .left
      let attributes: [NSAttributedString.Key: Any] = [
        .font: UIFont.monospacedSystemFont(ofSize: 22, weight: .regular),
        .foregroundColor: UIColor.label,
        .paragraphStyle: paragraph,
      ]
      let text = """
      METRO FC
      1 Keeper
      4 Defender
      8 Captain
      9 Striker
      Bench: Riley
      Coach: Taylor
      Physio: Morgan
      """
      text.draw(in: CGRect(x: 24, y: 24, width: 272, height: 592), withAttributes: attributes)
    }
    return image.jpegData(compressionQuality: 0.9) ?? Data()
  }

  private static func formatByteCount(_ byteCount: Int) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(byteCount), countStyle: .file)
  }
}
