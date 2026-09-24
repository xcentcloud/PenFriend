# iPad App Use Cases for PencilKit and PaperKit

This document converts the existing feature ideas into formal use-case specifications and adds a capability matrix that maps the PencilKit/PaperKit-based feature set used across the product.

## Scope

- **Primary actor:** iPad user with touch or Apple Pencil input
- **Supporting actors:** Shared recipients, imported document sources, local/cloud persistence
- **Primary goal:** Create, annotate, refine, persist, and share handwritten and mixed-media content

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
  4. The actor exports or saves the annotated result.
- **Exceptions:**
  - If the source document cannot be rendered, the system blocks annotation and shows an import error.
  - If export fails, the system preserves the annotation session for retry.
- **Capabilities:** Drawing over existing content, pen/marker/pencil/eraser tools, highlighting/underlining, export annotated output

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
- **Capabilities:** Pencil drawing tools, ruler support, shape placement/editing, selection/move/resize

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
- **Capabilities:** Lasso/selection tools, stroke-level editing, copy/paste, transforms

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
- **Capabilities:** Image markup, arrows/geometric shapes, text annotations, loupes, precise placement/adjustment

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

### UC-13: Detail Inspection and Precision Review
- **Actor:** Reviewer needing fine-grained inspection
- **Preconditions:** Dense content or detailed artwork is open
- **Primary flow:**
  1. The actor zooms and scrolls to the target area.
  2. The actor uses loupe or hover assistance where supported.
  3. The actor adds or adjusts precise annotations.
  4. The system maintains annotation alignment at the current zoom level.
- **Exceptions:**
  - If hover is unsupported on the device, the system continues without preview interactions.
  - If zoom limits are reached, the system keeps the current viewport and preserves edit accuracy.
- **Capabilities:** Zoom/scroll, loupe support, precise drawing interactions, hover previews

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

The matrix below groups the documented PencilKit/PaperKit-oriented capabilities into shared capability families and maps those families to the formal use cases that depend on them.

<table>
  <thead>
    <tr>
      <th>Capability</th>
      <th>Framework area</th>
      <th>Use cases</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>Apple Pencil and finger input</td><td>PencilKit input</td><td>UC-01</td></tr>
    <tr><td><code>PKCanvasView</code> canvas rendering</td><td>PencilKit canvas</td><td>UC-01, UC-03, UC-04</td></tr>
    <tr><td><code>PKToolPicker</code> tool selection</td><td>PencilKit tools</td><td>UC-01</td></tr>
    <tr><td><code>PKDrawing</code> save/restore</td><td>PencilKit persistence</td><td>UC-01, UC-14</td></tr>
    <tr><td>Undo and redo</td><td>PencilKit editing</td><td>UC-01, UC-04</td></tr>
    <tr><td>Drawing over existing content</td><td>PencilKit/PaperKit overlay</td><td>UC-02, UC-07</td></tr>
    <tr><td>Pen, marker, pencil, and eraser tools</td><td>PencilKit tools</td><td>UC-02</td></tr>
    <tr><td>Highlighting and underlining</td><td>Document markup</td><td>UC-02, UC-07</td></tr>
    <tr><td>Export annotated output</td><td>Sharing/export</td><td>UC-02, UC-11, UC-15</td></tr>
    <tr><td>Ruler support</td><td>Precision drawing</td><td>UC-03</td></tr>
    <tr><td>Shape placement and editing</td><td>Structured drawing</td><td>UC-03, UC-06, UC-12</td></tr>
    <tr><td>Selection, move, and resize interactions</td><td>Editing transforms</td><td>UC-03, UC-04, UC-10, UC-12</td></tr>
    <tr><td>Lasso and selection tools</td><td>PencilKit selection</td><td>UC-04</td></tr>
    <tr><td>Stroke-level editing</td><td>PencilKit editing</td><td>UC-04</td></tr>
    <tr><td>Copy and paste</td><td>Editing utilities</td><td>UC-04</td></tr>
    <tr><td>Object transforms</td><td>Editing transforms</td><td>UC-04, UC-12</td></tr>
    <tr><td>Freeform drawing</td><td>Canvas creation</td><td>UC-05, UC-12</td></tr>
    <tr><td>Text boxes and text blocks</td><td>Paper-style composition</td><td>UC-05, UC-09, UC-12</td></tr>
    <tr><td>Shapes and adornments</td><td>Paper-style composition</td><td>UC-05, UC-06, UC-12</td></tr>
    <tr><td>Image insertion and embedded images</td><td>Media placement</td><td>UC-05, UC-09, UC-12</td></tr>
    <tr><td>Canvas layout and multi-element editing</td><td>Paper-style composition</td><td>UC-05, UC-12</td></tr>
    <tr><td>Image markup and image overlays</td><td>Markup workflows</td><td>UC-06, UC-10</td></tr>
    <tr><td>Arrows and geometric shapes</td><td>Review markup</td><td>UC-06</td></tr>
    <tr><td>Text annotations</td><td>Review/approval markup</td><td>UC-06, UC-11</td></tr>
    <tr><td>Magnification with loupes</td><td>Precision review</td><td>UC-06, UC-13</td></tr>
    <tr><td>Precise placement and adjustment</td><td>Precision review</td><td>UC-06, UC-13</td></tr>
    <tr><td>Markup over documents and pages</td><td>Document annotation</td><td>UC-07</td></tr>
    <tr><td>Handwritten comments and callouts</td><td>Document annotation</td><td>UC-07</td></tr>
    <tr><td>Persistent save/reload of markup data</td><td>Persistence</td><td>UC-07, UC-14</td></tr>
    <tr><td>Handwriting recognition</td><td>Recognition</td><td>UC-08</td></tr>
    <tr><td>Scribble-related text input workflows</td><td>Recognition/input</td><td>UC-08</td></tr>
    <tr><td>Text extraction from handwritten content</td><td>Recognition/search</td><td>UC-08</td></tr>
    <tr><td>Hyperlinks</td><td>Paper-style composition</td><td>UC-09</td></tr>
    <tr><td>Structured page composition</td><td>Paper-style composition</td><td>UC-09</td></tr>
    <tr><td>Color-coded markup</td><td>Specialized annotation</td><td>UC-10</td></tr>
    <tr><td>Shape markers</td><td>Specialized annotation</td><td>UC-10</td></tr>
    <tr><td>Typed and handwritten notes</td><td>Mixed input</td><td>UC-10</td></tr>
    <tr><td>High-fidelity ink capture</td><td>Signature workflow</td><td>UC-11</td></tr>
    <tr><td>Signature persistence</td><td>Signature workflow</td><td>UC-11</td></tr>
    <tr><td>Zoom and scroll</td><td>Navigation/review</td><td>UC-13</td></tr>
    <tr><td>Hover previews on supported devices</td><td>Device-assisted review</td><td>UC-13</td></tr>
    <tr><td>Paper markup persistence</td><td>Persistence</td><td>UC-14</td></tr>
    <tr><td>Saved document version compatibility</td><td>Persistence</td><td>UC-14</td></tr>
    <tr><td>Render to image</td><td>Export</td><td>UC-15</td></tr>
    <tr><td>Export to shareable formats, including PDF</td><td>Export</td><td>UC-15</td></tr>
  </tbody>
</table>

## Suggested Product Concept

A strong product implementation remains a **Smart Notebook and Markup Workspace** for iPad that combines:

- Handwritten note taking
- Document and image annotation
- Structured markup with text, links, images, and shapes
- Persistent editable canvases and page-based workspaces
- Sharing and export workflows

This combination supports students, designers, reviewers, field workers, and general productivity users in one unified experience.
