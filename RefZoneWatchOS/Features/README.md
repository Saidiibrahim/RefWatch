# Features Module

This module contains all the distinct functional areas of the RefWatch Watch App, organized by domain.

## Current Features

- **Events**: Handles match events like cards, goals, and substitutions
- **Match**: Core match management and timing functionality
- **MatchSetup**: Pre-match configuration and team setup
- **Settings**: App configuration and preferences
- **Timer**: Match timing and period management

## Structure

Each feature follows a consistent organization:

- `Models/`: Data structures and business objects
- `ViewModels/`: Business logic and state management
- `Views/`: UI components specific to the feature

## Guidelines

- Each feature should be self-contained and independent
- Shared functionality should be moved to the Core module
- Features can depend on Core but should not depend on other features

### UI Conventions (watchOS)

- Use `navigationTitle` for screen titles; avoid placing duplicate headers inside the body at the top of the view.
- Do not render the time-of-day within views; the system clock is always visible on Apple Watch.
- When presenting sheets, wrap the content in `NavigationStack` and set a title so the system close affordance (X) appears consistently.
- Keep top padding conservative to avoid crowding the status area and curved corners.
- Preserve compact labels like "HOM/AWA" visually, but provide clear accessibility labels, e.g., `.accessibilityLabel("Home")` / `.accessibilityLabel("Away")`.

## Card Event Recording Feature

### Overview

The card event recording system implements a streamlined flow for recording yellow and red cards during a match, supporting both player and team official incidents.

### Architecture

#### Coordinator Pattern

The feature uses a coordinator pattern to manage the complex flow of recording card events:

- `CardEventCoordinator`: Manages the entire card event flow state and transitions
  - Handles recipient selection (player/team official)
  - Manages player number input
  - Controls team official role selection
  - Processes card reason selection
  - Records final card event in match state

### Key Components

#### Views

- `CardEventFlow`: Root view that orchestrates the entire flow using NavigationStack
- `CardReasonSelectionView`: Displays appropriate card reasons based on recipient type
- `TeamOfficialSelectionView`: Handles team official role selection
- `PlayerNumberInputView`: Manages player number input

#### Models

- `CardRecipientType`: Defines possible card recipients (player/team official)
- `TeamOfficialCardReason`: Enumerates reasons for team official cards
- `YellowCardReason`/`RedCardReason`: Defines player card reasons

## Implementation Notes

### State Management

- Uses `@Observable` for the coordinator
- Each view receives only the data it needs
- State transitions are handled through clear coordinator methods

### Navigation

- Single NavigationStack instead of multiple sheets
- Linear, predictable flow from recipient → details → reason
- Clear state transitions managed by coordinator

### Benefits

- Simplified navigation flow
- Centralized state management
- Clear separation of concerns
- Easy to extend with new card types or reasons
- Predictable user experience

## Usage Example

To record a card event, create a CardEventFlow instance with the required parameters:

NavigationLink {
    CardEventFlow(
        cardType: .yellow,
        team: teamType,
        matchViewModel: matchViewModel,
        setupViewModel: setupViewModel
    )
} label: {
    YellowCardButton()
}
