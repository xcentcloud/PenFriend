# PenFriend

PenFriend is an iPad-first SwiftUI + PencilKit workspace for handwritten capture and editing.

## Project

- Xcode project: `PenFriend.xcodeproj`
- App target: `PenFriend`

## Priority 1 foundation included

- New handwritten note page creation
- Apple Pencil and touch drawing canvas
- Undo and redo editing actions
- Stroke selection/editing entry via lasso tool
- Handwriting smoothing with interpolation fallback and optional bundled Core ML model

## Optional Core ML smoothing model

- The app automatically looks for a compiled model named `HandwritingSmoother.mlmodelc` in the app bundle.
- When present, enabling **Use Custom Model** applies model inference using PencilKit stroke data.
- When unavailable, smoothing safely falls back to on-device interpolation.

## Open in Xcode

1. Open `PenFriend.xcodeproj`.
2. Select the `PenFriend` scheme.
3. Run on an iPad simulator or device with Apple Pencil support.
