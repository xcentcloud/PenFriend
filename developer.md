# PenFriend Product Brief and iPad Use Cases

This document defines PenFriend as an iOS 27-first Smart Notebook and Markup Workspace for iPad. It combines product positioning, requirements, formal use-case specifications, and a capability matrix that maps the PencilKit/PaperKit foundation of the app together with the adjacent editor features built around it.

## Scope

- **Primary actor:** iPad user with touch or Apple Pencil input
- **Supporting actors:** Shared recipients, imported document sources, local/cloud persistence
- **Primary goal:** Create, annotate, refine, persist, and share handwritten and mixed-media content
- **Platform direction:** iOS 27 and iPadOS 27 first, using the latest Apple Pencil, touch, accessibility, multitasking, and document-handling patterns

## PenFriend Product Definition

### Product Positioning

PenFriend is a native iPad productivity app for handwriting, annotation, structured page composition, and shareable output. The product should feel like one unified workspace rather than separate note, PDF markup, and whiteboard tools.

### Core Product Pillars

- Handwritten note taking as the default entry experience
- Document and image annotation for review, feedback, and field workflows
- Structured markup with text, links, images, and shapes for rich page composition
- Persistent editable canvases and page-based workspaces that reopen without flattening content
- Sharing and export workflows for PDF, image, and collaboration handoff

### Product Structure

- **Notebook mode** for handwritten pages, planner pages, and journals
- **Markup mode** for PDFs, screenshots, and imported images
- **Canvas mode** for freeform boards, brainstorming, and mixed-media layouts
- **Export and share layer** that works consistently across all three modes

### iOS 27-First Product Direction

- Align the experience with the latest iOS 27 and iPadOS 27 interaction patterns instead of building a custom interaction model that conflicts with the platform
- Treat precision ink, editable markup, persistent state, device-assisted review, and modern sharing flows as product differentiators
- Use current Apple Pencil, touch, accessibility, multitasking, and document workflows as first-class product behaviors

### Primary Target Users

- Students and note takers
- Designers and reviewers
- Inspectors and field operators
- General productivity users who need both handwriting and structured content

## Product Requirements

### Notebook Module

- Support handwritten note creation, planner pages, and journal-style page composition
- Preserve editable ink state for reopened notes and notebooks
- Cover core workflows represented by **UC-01**, **UC-08**, and **UC-09**

### Markup Module

- Support annotation on PDFs, worksheets, screenshots, and imported images
- Preserve editable annotations for later revision instead of forcing flattened output
- Cover core workflows represented by **UC-02**, **UC-06**, **UC-07**, **UC-10**, and **UC-11**

### Canvas Module

- Support freeform mixed-media canvases with handwriting, text, shapes, links, and images
- Allow users to reposition, resize, and refine multiple elements on a shared surface
- Cover core workflows represented by **UC-03**, **UC-04**, **UC-05**, and **UC-12**

### Persistence Module

- Restore notebooks, canvases, and markup sessions as editable workspaces
- Maintain compatibility across saved versions and preserve recoverable state when partial restoration fails
- Cover core workflows represented by **UC-07** and **UC-14**

### Export Module

- Export current pages or workspaces to shareable image and PDF outputs
- Support system sharing and save flows without breaking the editable source state
- Cover core workflows represented by **UC-02**, **UC-11**, and **UC-15**

## Formal Use-Case Specifications

### UC-01: Freehand Note Taking
- **Actor:** Student, professional, or general note taker
- **Preconditions:** A blank, ruled, or grid page is open; input tools are available
- **Primary flow:**
  1. The actor opens a new note page.
  2. The actor chooses a pen, pencil, or marker from the tool picker.
  3. The actor writes or sketches with Apple Pencil or touch.
  4. The actor uses undo or redo as needed.
  5. The system saves the drawing state for later editing.
- **Exceptions:**
  - If the selected tool is unavailable, the system falls back to the default ink tool.
  - If saving fails, the system keeps the current canvas in memory and prompts the actor to retry.
- **Capabilities:** Apple Pencil and finger input, `PKCanvasView`, `PKToolPicker`, `PKDrawing` save/restore, undo/redo

### UC-02: Worksheet and Document Annotation
- **Actor:** Student, reviewer, or trainer
- **Preconditions:** A worksheet, lesson asset, or reference document is loaded
- **Primary flow:**
  1. The actor opens an existing document.
  2. The system displays the document as an annotatable surface.
  3. The actor marks up the content with ink, highlights, or underlines.
  4. The system saves the annotation state in an editable form for later revision.
  5. The actor optionally exports a flattened or shared result.
- **Exceptions:**
  - If the source document cannot be rendered, the system blocks annotation and shows an import error.
  - If export fails, the system preserves the annotation session for retry.
- **Capabilities:** Drawing over existing content, `PKToolPicker`, pen/marker/pencil/eraser tools, highlighting/underlining, export annotated output

### UC-03: Diagram Creation and Precision Sketching
- **Actor:** Designer, engineer, or planner
- **Preconditions:** A drawing surface is open and precision tools are enabled
- **Primary flow:**
  1. The actor creates a new diagram canvas.
  2. The actor draws lines and shapes with pencil tools.
  3. The actor uses ruler-assisted alignment where needed.
  4. The actor adjusts shapes or selected content for accuracy.
- **Exceptions:**
  - If precision aids are disabled on the device, the system continues with standard drawing interactions.
  - If a shape cannot be edited as a discrete object, the system treats it as stroke content.
- **Capabilities:** `PKCanvasView`, pencil drawing tools, ruler support, shape placement/editing, selection/move/resize

### UC-04: Stroke Selection and Editing
- **Actor:** Any user refining a drawing
- **Preconditions:** The page contains existing strokes or objects
- **Primary flow:**
  1. The actor activates the selection tool.
  2. The actor selects strokes with lasso or direct selection behavior.
  3. The actor moves, resizes, duplicates, or deletes the selection.
  4. The system updates the page while preserving edit history.
- **Exceptions:**
  - If no strokes are selected, edit commands remain disabled.
  - If paste content is unavailable, duplicate and paste actions are skipped.
- **Capabilities:** `PKCanvasView`, lasso/selection tools, stroke-level editing, copy/paste, transforms, undo/redo

### UC-05: Mixed Media Brainstorming Canvas
- **Actor:** Product, design, or workshop participant
- **Preconditions:** A freeform board is available for editing
- **Primary flow:**
  1. The actor adds handwritten notes to the board.
  2. The actor inserts text blocks, shapes, and images.
  3. The actor rearranges elements to organize ideas.
  4. The system persists the board as an editable workspace.
- **Exceptions:**
  - If image import fails, the board remains editable without the image.
  - If an element type is unsupported, the system rejects only that insertion.
- **Capabilities:** Freeform drawing, text boxes, shapes, image insertion, canvas layout/editing

### UC-06: Design Review and Redlining
- **Actor:** Designer, QA reviewer, or stakeholder
- **Preconditions:** A screenshot, mockup, or design file is open
- **Primary flow:**
  1. The actor imports the design artifact.
  2. The actor annotates issues with arrows, shapes, text, and ink.
  3. The actor uses magnification for fine-grained review.
  4. The actor saves or shares the marked-up design.
- **Exceptions:**
  - If high-resolution assets load slowly, the system may defer magnification until rendering completes.
  - If placement precision is limited, the system retains the last valid annotation position.
- **Capabilities:** Image markup, arrows/geometric shapes, text annotations, loupe support, precise placement/adjustment

### UC-07: PDF and Page Markup
- **Actor:** Reader, analyst, or approver
- **Preconditions:** A PDF or page-based document is loaded
- **Primary flow:**
  1. The actor opens the document.
  2. The actor adds handwritten notes, highlights, and callouts.
  3. The system binds markup to the current page context.
  4. The actor saves and later reloads the markup.
- **Exceptions:**
  - If a page cannot accept markup, the system disables editing for that page only.
  - If page-to-markup mapping is lost, the system requests document reload before continuing.
- **Capabilities:** Markup over documents, handwritten comments, highlighting/callouts, persistent save/reload of markup data

### UC-08: Handwriting to Searchable Text
- **Actor:** Knowledge worker or student
- **Preconditions:** Handwritten content exists on the page
- **Primary flow:**
  1. The actor selects handwritten content.
  2. The system runs handwriting recognition.
  3. The actor reviews extracted text.
  4. The system stores recognized text for search or conversion workflows.
- **Exceptions:**
  - If recognition confidence is low, the system returns the original handwriting without conversion.
  - If text extraction is unavailable offline, the system postpones conversion until supported.
- **Capabilities:** Handwriting recognition, Scribble-related text input workflows, text extraction from handwriting

### UC-09: Interactive Planner or Journal
- **Actor:** Planner, journal user, or student
- **Preconditions:** A structured page template or notebook page is available
- **Primary flow:**
  1. The actor opens a planner or journal page.
  2. The actor adds handwriting, typed text, decorative media, and links.
  3. The actor arranges elements into the intended layout.
  4. The system saves the page for future editing.
- **Exceptions:**
  - If links cannot be embedded, the system stores them as plain text references.
  - If the layout exceeds the page bounds, the system requires repositioning before export.
- **Capabilities:** Handwritten entries, text blocks, embedded images, hyperlinks, structured page composition

### UC-10: Medical, Inspection, or Field Annotation
- **Actor:** Inspector, clinician, or field operator
- **Preconditions:** A body chart, diagram, floor plan, or site image is available
- **Primary flow:**
  1. The actor opens the relevant visual asset.
  2. The actor adds issue markers, notes, and color-coded markup.
  3. The actor repositions annotations to match the target area.
  4. The actor saves or shares the annotated record.
- **Exceptions:**
  - If color coding is unavailable, the system preserves markup using the default annotation color.
  - If an overlay is moved outside the target region, the system snaps it back into bounds.
- **Capabilities:** Image overlays, color-coded markup, shape markers, typed/handwritten notes, element repositioning/resizing

### UC-11: Signature and Approval Capture
- **Actor:** Signer, manager, or approver
- **Preconditions:** A signable form or approval page is open
- **Primary flow:**
  1. The actor navigates to the signature field.
  2. The actor signs with high-fidelity ink input.
  3. The actor adds supporting notes if needed.
  4. The system persists and exports the signed result.
- **Exceptions:**
  - If the signature field is locked, the system blocks signing until the field is enabled.
  - If export is interrupted, the system keeps the stored signature state intact.
- **Capabilities:** High-fidelity ink capture, signature persistence, text annotations, export for sharing/storage

### UC-12: Scrapbook and Mood Board Creation
- **Actor:** Creative user or researcher
- **Preconditions:** A rich page or board is available
- **Primary flow:**
  1. The actor adds sketches, photos, captions, and decorative shapes.
  2. The actor reorders and resizes page elements.
  3. The actor refines the final composition.
  4. The system saves the result as an editable board.
- **Exceptions:**
  - If media assets exceed supported size limits, the system rejects only those assets.
  - If element overlap blocks editing, the system preserves z-order controls or selection fallback.
- **Capabilities:** Freehand drawing, images, text boxes, shapes/adornments, multi-element page editing

### UC-13: Detail Inspection and Accessible Review
- **Actor:** Reviewer needing fine-grained inspection or device-assisted readability
- **Preconditions:** Dense content or detailed artwork is open
- **Accessibility scope:** Product-layer accessibility behaviors built around PencilKit/PaperKit surfaces, not framework guarantees by themselves
- **Primary flow:**
  1. The actor zooms and scrolls to the target area.
  2. The actor uses zoom, loupe, or hover assistance to improve readability and control.
  3. The actor uses supported accessibility-oriented review aids, including VoiceOver-readable page context and larger inspection targets.
  4. The actor adds or adjusts annotations using supported accessible targeting controls, including focusable annotation handles and announced placement targets.
  5. The system maintains annotation alignment at the current zoom level while preserving the accessible interaction path.
- **Exceptions:**
  - If hover is unsupported on the device, the system continues without preview interactions.
  - If zoom limits are reached, the system keeps the current viewport and preserves edit accuracy.
- **Capabilities:** Zoom/scroll, loupe support, precise drawing interactions, hover previews, device-assisted review aids, accessibility-oriented review aids

### UC-14: Persistent Editable Workspaces
- **Actor:** Returning user
- **Preconditions:** A previously saved notebook, board, or markup file exists
- **Primary flow:**
  1. The actor reopens a saved workspace.
  2. The system restores strokes, markup, and embedded elements.
  3. The actor continues editing from the restored state.
  4. The system re-saves the updated version.
- **Exceptions:**
  - If a saved version is incompatible, the system opens the nearest compatible representation.
  - If an element cannot be restored, the system flags the missing element without discarding the rest of the workspace.
- **Capabilities:** `PKDrawing` persistence, paper markup persistence, reload-and-edit workflows, saved-version compatibility

### UC-15: Shareable Output
- **Actor:** Any user distributing final content
- **Preconditions:** The current page or workspace has content ready for export
- **Primary flow:**
  1. The actor chooses an export action.
  2. The system renders the current page or document.
  3. The actor selects image or PDF output.
  4. The system saves or shares the exported file.
- **Exceptions:**
  - If the selected format is unsupported for the current content, the system offers the nearest supported export type.
  - If sharing is cancelled, the system preserves the generated export locally when possible.
- **Capabilities:** Render to image, export to shareable formats, save/distribute completed pages

## Capability-to-Use-Case Matrix

The matrix entries below map the documented capabilities and implementation touchpoints to the formal use cases that depend on them, separated into direct framework-level items and product-layer editor behaviors for the iOS 27-first PenFriend product.

### Platform and Framework Capabilities
- **Apple Pencil and finger input** — PencilKit input — **Use cases:** UC-01
- **`PKCanvasView` canvas rendering** — PencilKit canvas — **Use cases:** UC-01, UC-03, UC-04
- **`PKToolPicker` and tool selection** — PencilKit tools — **Use cases:** UC-01, UC-02
- **`PKDrawing` save/restore** — PencilKit persistence — **Use cases:** UC-01, UC-14
- **Undo and redo** — PencilKit editing — **Use cases:** UC-01, UC-04
- **Drawing over existing content** — PencilKit/PaperKit overlay — **Use cases:** UC-02, UC-07
- **Pencil drawing tools** — PencilKit tools — **Use cases:** UC-03
- **Ruler support** — Precision drawing — **Use cases:** UC-03
- **Lasso and selection tools** — PencilKit selection — **Use cases:** UC-04
- **Loupe support** — Precision review — **Use cases:** UC-06, UC-13
- **Handwriting recognition** — Recognition — **Use cases:** UC-08
- **Scribble-related text input workflows** — Recognition/input — **Use cases:** UC-08
- **High-fidelity ink capture** — Signature workflow — **Use cases:** UC-11
- **Zoom and scroll** — Navigation/review — **Use cases:** UC-13
- **Hover previews on supported devices** — Device-assisted review — **Use cases:** UC-13

### Product-Layer Editor Behaviors
- **Highlighting and underlining** — Document markup — **Use cases:** UC-02, UC-07
- **Export annotated output** — Sharing/export — **Use cases:** UC-02, UC-11, UC-15
- **Shape placement and editing** — Structured drawing — **Use cases:** UC-03, UC-06, UC-12
- **Selection, move, and resize interactions** — Editing transforms — **Use cases:** UC-03, UC-04, UC-10, UC-12
- **Stroke-level editing** — PencilKit editing — **Use cases:** UC-04
- **Copy and paste** — Editing utilities — **Use cases:** UC-04
- **Object transforms** — Editing transforms — **Use cases:** UC-04, UC-12
- **Freeform drawing** — Canvas creation — **Use cases:** UC-05, UC-12
- **Text boxes and text blocks** — Paper-style composition — **Use cases:** UC-05, UC-09, UC-12
- **Shapes and adornments** — Paper-style composition — **Use cases:** UC-05, UC-06, UC-12
- **Image insertion and embedded images** — Media placement — **Use cases:** UC-05, UC-09, UC-12
- **Canvas layout and multi-element editing** — Paper-style composition — **Use cases:** UC-05, UC-12
- **Image markup** — Markup workflows — **Use cases:** UC-06
- **Image overlays** — Markup workflows — **Use cases:** UC-10
- **Arrows and geometric shapes** — Review markup — **Use cases:** UC-06
- **Text annotations** — Review/approval markup — **Use cases:** UC-06, UC-11
- **Precise placement and adjustment** — Precision review — **Use cases:** UC-06
- **Precise drawing interactions** — Precision review — **Use cases:** UC-13
- **Markup over documents and pages** — Document annotation — **Use cases:** UC-07
- **Handwritten comments and callouts** — Document annotation — **Use cases:** UC-07
- **Persistent save/reload of markup data** — Persistence — **Use cases:** UC-07, UC-14
- **Text extraction from handwritten content** — Recognition/search — **Use cases:** UC-08
- **Hyperlinks** — Paper-style composition — **Use cases:** UC-09
- **Structured page composition** — Paper-style composition — **Use cases:** UC-09
- **Color-coded markup** — Specialized annotation — **Use cases:** UC-10
- **Shape markers** — Specialized annotation — **Use cases:** UC-10
- **Typed and handwritten notes** — Mixed input — **Use cases:** UC-10
- **Element repositioning and resizing** — Specialized annotation — **Use cases:** UC-10
- **Signature persistence** — Signature workflow — **Use cases:** UC-11
- **Device-assisted review aids** — Device-assisted review — **Use cases:** UC-13
- **Accessibility-oriented review aids** — Accessible review — **Use cases:** UC-13
- **Paper markup persistence** — Persistence — **Use cases:** UC-14
- **Saved document version compatibility** — Persistence — **Use cases:** UC-14
- **Render to image** — Export — **Use cases:** UC-15
- **Export to shareable formats, including PDF** — Export — **Use cases:** UC-15
- **Save and distribute completed pages** — Export — **Use cases:** UC-15

## PenFriend MVP Scope

### Priority 1: Core Capture and Editing

- Status: **Implemented**
- Primary supporting use cases: **UC-01**, **UC-04**

#### Implemented Functional Scope

- Users can create a new handwritten note page from the default notebook entry flow.
- The note page supports Apple Pencil and finger input for writing and sketching.
- Undo and redo are available during active note editing.
- Stroke selection supports lasso-style or direct selection behavior for existing ink.
- Selected strokes can be moved and refined without flattening the page state.
- Edit history is preserved while selection and refinement actions are applied.

#### Priority 1 UX Behavior

- New page creation opens directly into an editable ink surface.
- Tool selection keeps a usable default ink tool available at all times.
- Undo and redo controls remain context-aware and available during capture/edit sessions.
- Selection actions are disabled when no selectable strokes are present.
- Refinement actions update the current page state immediately and remain reversible.

#### Acceptance Criteria

- A user can open a new note page and create handwritten content in one continuous flow.
- A user can switch tools and continue writing without losing current drawing state.
- A user can undo and redo edits across capture and refinement actions.
- A user can select existing strokes, reposition them, and commit updates.
- The resulting page remains editable after capture and refinement workflows.

### Priority 2: Markup Workflows

- PDF and image annotation
- Review markup with text, highlights, callouts, arrows, and shapes
- Primary supporting use cases: **UC-02**, **UC-06**, **UC-07**

### Priority 3: Structured Mixed Content Pages

- Mixed content pages with text, shapes, links, and images
- Notebook and canvas layouts that support richer composition beyond pure ink
- Primary supporting use cases: **UC-05**, **UC-09**, **UC-12**

### Priority 4: Persistent Editable Workspaces

- Save and reopen notebooks, markup sessions, and canvases as editable state
- Handle saved-version compatibility and partial recovery gracefully
- Primary supporting use cases: **UC-14**

### Priority 5: Sharing and Export

- Export to PDF and image formats
- Support system share flows and saved output handoff
- Primary supporting use cases: **UC-15**

This MVP keeps PenFriend focused on a unified iPad workspace for notes, markup, and mixed-media composition while remaining aligned with the latest iOS 27 product direction.
