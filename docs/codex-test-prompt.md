# BetterNotes — full test and debug brief for Codex

Paste everything below into Codex. It is written so Codex can work remotely
(no physical iPad, Apple Pencil, Mac pairing or network), so each area says what
can be automated and what only a person can check.

---

## 1. Your role

You are testing and debugging **BetterNotes**, an iPadOS notes app built on
PencilKit (handwriting, lasso selection, imported PDFs and images, audio
recordings, BYOK AI assistance) with a native Mac companion. SwiftUI + SwiftData.
The repo is at `~/betternotes`, branch `main`. The App Store submission deadline is
**31 Oct 2026**, so prioritise by risk (section 4) and report early.

Read `CLAUDE.md` first. It records hard-won rules about this codebase.

### Ground rules
- **Report, don't silently fix.** For each problem found: what you ran, what you
  expected, what happened, the file and line, and your suspected cause. Fix only
  clear, small bugs, one commit each, and say so. Never mix a fix with refactoring.
- **Do not commit or push unless asked.** Work on a new branch `codex-test-pass`.
- `BetterNotes.xcodeproj` is generated. Never edit `project.pbxproj`. Add files and run
  `xcodegen generate`.
- Do not restore deliberately removed features: zoom menu, handwriting
  beautifier, writing suggestions, assistant rename/clear/delete, the Apple
  on-device model tier. AI is **BYOK only**.
- Do not use or request real API keys, tokens or personal data. Provider calls
  must be mocked or use the `-ui-testing-ai-stub` launch argument.
- Xcode rewrites `BetterNotes/Localizable.xcstrings` and `InfoPlist.xcstrings` during
  builds. Revert those two files (`git checkout -- <file>`) before reporting a diff
  unless you changed strings on purpose.
- A simulator pass is **not evidence** for touch targets, gesture routing or
  PencilKit. Say "simulator only" in the report when that is all you have.
- Never run the whole UI suite on a device. Run targeted tests.

### Commands
```
xcodegen generate

# unit tests (about 30 seconds once built)
xcodebuild test -scheme BetterNotes \
  -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)' \
  -only-testing:BetterNotesTests

# full simulator run (about 7 minutes; restart the simulator after roughly a dozen runs)
xcodebuild test -scheme BetterNotes \
  -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)'

# one UI test
xcodebuild test -scheme BetterNotes \
  -destination 'platform=iOS Simulator,name=iPad Air 13-inch (M4)' \
  -only-testing:BetterNotesUITests/BetterNotesUITests/<testName>

# Mac target (only 4 tests exist; see section 3, area M)
xcodebuild test -scheme BetterNotesMac -destination 'platform=macOS'
```
`xcodebuild test` can hang while finalizing the log; run it under `timeout 1200`.
Expected CoreData lines such as "Persistence-1632 vs 1621" and "error 6922" come from
the legacy-store migration tests and are not failures. Judge results by
`Executed N tests, with M failures` and `** TEST SUCCEEDED **`, not by grepping for
"error:".

### Baseline you must reproduce first
- Unit suite: **296 tests, 0 failures, 2 skipped** (iPad Air 13-inch M4 simulator).
- Mac suite: 4 tests, 0 failures.
- Report any difference before testing anything else.

---

## 2. What changed recently (highest risk, least tested)

1. **Merged PR from a fork (18 Oct):** library folders, document import,
   configurable OCR (PaddleOCR cloud / vision chat), Scribble-to-Erase, shared
   vertical zoom, lasso rework, Pencil double-tap. Its own notes say no physical
   Pencil or gesture testing was done.
2. **Fixes from 24 Oct (commit `8b3fd97`):**
   - `AudioRecorder`: recorder creation, `prepareToRecord`, `record` and the stop
     wait now run off the main thread (recording freeze).
   - Selection menu: tapping a selection toggles an on-page menu beside it
     instead of clearing the selection (`PageEditorView.swift`, `SelectionHandles`,
     `selectionMenu`, `SelectionContextBar`).
   - Vertical scroll: pulling past the last page adds a page
     (`ZoomablePageView.swift` bottom overscroll, `NotebookView.swift`).
   - `InkJournal` (`BetterNotes/Services/InkJournal.swift`): counts-only log of
     ink changes in Application Support, to diagnose strokes that move, resize or
     reappear after a large erase.
   - Test bundle IDs moved to `com.kenny-lhs.betternotes.tests` / `.uitests`.
3. **Sync policy (2 Oct):** protocol v5 conflict setting, conflicts archived,
   permanent delete propagation with a confirmation prompt.

Known open problems (confirm, root-cause, report): see section 5.

---

## 3. Test matrix

For every row: run the automated tests named, read the code for the listed risk,
and write any missing test. **[Device]** marks things Codex cannot verify; list
them under "needs a person" with exact steps.

### A. Drawing and ink (PencilKit)
Files: `Views/Components/PaperCanvas.swift`, `PageEditorView.swift`,
`ZoomablePageView.swift`, `Services/InkJournal.swift`, tests `InkInteractionTests`.
- Pen, pencil, highlighter, eraser (stroke and bitmap), lasso: tool switching
  keeps the selected tool; settings persist across relaunch.
- Stroke lifecycle: pen-up debounce (120 ms), late commits, rapid next stroke,
  tool change during a stroke. Check there is no stale or lost stroke.
- Undo and redo of ink, elements and lasso moves; redo after a lasso move keeps ink;
  history coalescing (0.35 s) does not merge distinct edits.
- **Strokes reappearing after erasing many strokes** (open bug, sporadic): review
  the resurrection workaround in `canvasViewDrawingDidChange`
  (`settledDrawingAtToolBegin`, `awaitingResurrectionCheck`), the two-step
  `setCanvasDrawing` (transient reset then async assignment, generation guard),
  and `performProgrammaticDrawingChange`. Write a stress unit test that erases or
  deletes a large selection and then begins a new stroke, and look for any path
  where a stale drawing wins. Use `InkJournal` lines to explain the sequence.
- **Strokes moving or resizing on their own** (open bug): review the lasso
  mutation commit (`beginInkSelectionMutation` / `finishInkSelectionMutation`), the
  cached selection preview layer in `InkCanvasViewport`, and any path that applies
  `selectionMutation.transform` when the selection is no longer the same.
- Scribble to Erase: three or more crossing passes erase ink plus the scratch
  stroke, one undo restores, blank-area scribbles stay ink, setting toggle works,
  OCR is not scheduled for scratches. Tests: `InkInteractionTests`.
- Shape recognition (press and hold) commits one shape and never leaves a ghost.
- Dark Mode: ink and rasters are not blank (OCR renders in a light trait collection).
- **[Device]** Pencil latency, palm rejection, Apple Pencil double tap toggling
  tools (and respecting the system setting), draw-with-finger on and off.

### B. Selection and the new menu
- Lasso (Free and Rectangle): first tap activates the saved mode; tapping the active
  tool opens mode choices; one-finger drag selects; two fingers pan.
- Selecting strokes plus images, text boxes, recordings and tape together.
- **New:** tapping the selection body shows or hides its menu and never clears it;
  tapping outside clears it. Menu actions: Cut, Copy, Paste, Duplicate, Delete,
  Ask, Tape Options (tape only), and the ellipsis (Lock, Bring Forward, Send
  Backward). Check each action on mixed selections, locked elements
  (`lockedExcludedElementIDs`), and an empty clipboard (Paste disabled).
- Menu placement: above the rotate handle when there is room, else below, else
  inside; clamped to the page; counter-scaled by `zoomScale`. Check a selection at
  the page top, bottom and corners, in portrait and landscape pages, and in
  vertical scroll mode at several zoom levels.
- Move, resize (all eight handles) and rotate commit one transformed drawing at
  gesture end, including leaving the page or changing tools mid-gesture.
- The two selection states move together: `selectedElementID` and
  `selectionState`. After any add or remove, `refreshSelectionBounds()` runs.
- Existing tests to run: `testTappingASelectionTogglesItsMenuInsteadOfClearingIt`,
  `testAskAboutLassoedInkIsReachableFromTheSelectionBar`,
  `testSelectionOutlineReportsItsOwnFrameNotTheWholePage`,
  `testInsertedInkCanMoveAndPasteFromBlankCanvas`,
  `testFixedBottomToolbarKeepsSelectionActionsReachable`,
  `testLassoSelectsInkOnFirstTapInBothModes`,
  `testVerticalLassoSelectsInkOnFirstTapInBothModes`,
  `testDrawnStrokesCanBeResizedByTheirHandlesWithoutLosingSelection`,
  `testRedoOfALassoMoveKeepsTheInk`.
- Known SwiftUI traps (check any new view): hit-testing is clipped to a view's own
  frame (`contentShape` outward is ignored); `.offset` is a rendering transform and
  leaves the accessibility frame behind (use `.position`); element `posX`/`posY`
  are centres.

### C. Page layout, zoom and navigation
- Single-page mode: horizontal swipe turns pages; pulling left past the last page
  shows a ring and adds a page only past the threshold; a short pull does nothing;
  view-only mode disables it. Tests: `testSinglePageAddsOnlyWithLongPullAtEnd`,
  `testShortPullOnTheLastPageDoesNotAddAPage`.
- Vertical scroll mode: one `ZoomablePageView` owns zoom and pan; pinch scales
  page boxes and spacing together; **new** pull up past the last page adds a page
  (threshold 100 pt, flick 40 pt); the Add Page button still works. Tests:
  `testPullingPastTheLastPageInVerticalScrollAddsAPage`,
  `testVerticalPinchScalesThePageBoxWithTheWritingArea`.
- Page overview, page count button, previous/next, add, duplicate, delete, move
  pages; page orientation and templates (blank/ruled/grid etc.) with line thickness
  and opacity, saved per page and as notebook default, copied with pages.
- Tabs: tab strip, pinned + menu, each tab keeps its page, closing a tab leaves
  the notebook in the library.
- Toolbar: docks at either side, compact and narrow (Stage Manager) layouts.
  **[Device]** narrow Stage Manager width.
- Multitasking and size-class changes must not recreate the editor or dismiss
  settings.

### D. Elements: text, sticky notes, images, tape, shapes
- Insert, edit, move, resize, rotate, lock, layer order, duplicate, delete.
- Rich text codec: older saved rich text still loads (`RichTextMigrationTests`).
- Images: Photos import, 3200 px edge cap, text near an image edge stays in frame,
  OCR text appears in search.
- Tape: opaque in the editor and in PDF export; colour, length, height; tap or
  Pencil tap reveals and covers; a Pencil stroke across tape does not reveal it;
  no stray dot of ink is left. Tests: `testTappingTapeRevealsWhatIsUnderIt`,
  `testPencilTapOnTapeRevealsItWithoutLeavingInk`,
  `testPencilStrokeAcrossTapeDoesNotRevealIt`, `testTapeOptionsChangeColorLengthAndHeight`.
- Rotated elements: finger-drag resize and rotate hit areas ignore rotation (known
  open bug); two finger-drag pipelines can both fire; unselected elements have live
  invisible handles; empty text boxes are invisible. Confirm and root-cause each.

### E. Audio recordings
Files: `Services/AudioRecorder.swift`, `PageEditorView` (`startRecording`,
`finishRecording`, `toggleAudio`), `ElementOverlay`, tests `AudioRecorderTests`,
`AudioPlaybackTests`.
- **Recording freeze and missing recording bar** (open bug): verify nothing on the
  main thread waits on audio hardware: `AVAudioRecorder` init, `prepareToRecord`,
  `record`, `setActive`, `AVAudioPlayer.prepareToPlay`, and the stop wait. Look for
  any remaining `Thread.sleep`, `DispatchQueue.main.sync` or synchronous session
  calls on the main actor. Check the race between `startRecording` awaiting
  permission and a quick Stop, a second Start while the first is stopping, switching
  pages or leaving the editor mid-recording, and the permission-denied path removing
  the placeholder element.
- Playback: play, pause, resume, seek, one player at a time, playing blocked while
  recording, error messages visible. A finger or Pencil tap on the play button
  toggles playback; a long press must not show the blank-canvas Select All /
  Insert Space menu (open question). Test: `testFingerOnRecordingPlayButtonPlaysWhenCanvasReceivesIt`.
- Transcription: Speech permission, cancel, error states, result saved to the element.
- **[Device]** real microphone, Bluetooth headset, interruption by a call, backgrounding
  while recording, two-minute and ten-minute recordings, memory use.

### F. Handwriting recognition, `??` questions and OCR
Files: `Services/HandwritingOCR.swift`, `OCRService.swift`, `OCRClient.swift`,
`OCRSettingsStore.swift`, `Views/OCRSettingsView.swift`, tests `OCRPipelineTests`,
`InkQuestionTests`.
- On-device detector reads English only with language correction off, finds `??` at
  the start or end of a handwritten line (including full-width marks), joins
  observations on a row, retries the most recent row locally.
- The inline prompt shows "Better OCR happening", then the recognised text; Answer,
  Not now, Retry, Cancel behave; the prompt never opens the assistant or the keyboard
  by itself; writing elsewhere does not cancel a pending question; already-handled
  questions are not re-offered (`handledQuestionFingerprints`, max 16).
- Custom provider: PaddleOCR synchronous API (`API_URL`, `TOKEN`, base64 `file`,
  `fileType: 1`, `Authorization: token …`) and OpenAI-compatible vision chat. Mock
  both. Check endpoint validation (HTTPS only, HTTP for localhost), 401/403/429
  messages, 8 MiB response cap, oversize upload refusal before Base64 encoding,
  cancellation, unchanged content is not uploaded twice, Test Connection does not
  change saved settings, credentials live in a separate Keychain service.
- Ordinary drawing must never upload a page. Confirm in code that uploads happen
  only on a detected `??`, an explicit recognise, Assistant or Ask Notes.
- **Accuracy is the largest open issue.** Apple Vision reads the owner's English
  handwriting poorly. A local PaddleOCR spike (not committed) on synthetic
  font-based pages gave: Apple Vision 0.026 character error rate, PP-OCRv6 small
  0.008, tiny 0.034. It could not separate the engines on real homework (math
  vectors). Do not rewrite OCR. Instead (1) review image preparation (scale, margin,
  contrast, ink colour on paper colour) for anything that hurts recognition, and (2)
  produce a few stroke-rendered English handwriting samples with `??` lines and a
  repeatable script that scores any provider. Report what you can and cannot judge
  without the owner's real handwriting.
- Search: `Page.pdfText` and `Page.ocrText` stay separate; search combines both;
  failed or stale recognition never replaces existing text.
- Recognition is cancelled when a stroke starts and never scheduled by lasso edits
  or Scribble erase.

### G. AI assistant (BYOK)
Files: `Services/AIClient.swift`, `AIService`, `AssistantCoordinator`,
`Views/AssistantView.swift`, tests `AISettingsStoreTests`, `AssistantCoordinatorTests`.
- Provider add/edit/remove (label wording), Test Connection on reasoning models
  (max_tokens 512 minimum so hidden reasoning is not mistaken for an output limit),
  keys stored in Keychain, never logged.
- Assistant conversation: streaming, cancel, citations, Ask Notes, error display,
  conversation save errors visible, history stays local, Delete Assistant History in
  Settings > AI.
- Ink answers (`InkAnswerCoordinator`): the lasso Ask flow answers in place;
  failures surface; long answers do not hit an output limit with the owner's
  DeepSeek model (open question).
- Mock every network call. Use `-ui-testing-ai-stub` for UI tests.

### H. Library, folders and imports
Files: `Views/Library/LibraryView.swift`, `FolderBrowserComponents.swift`,
`Models/NotebookFolder.swift`, `Services/DocumentImporter`, tests `DocumentSupportTests`.
- Create, nest, rename (rewrites all descendant paths and memberships in one save,
  rejects conflicts), favourite, colour, archive (inherited by descendants), trash
  and restore (restores only the group trashed with the folder), Empty Trash, and the
  30-day retention.
- Drag notebooks onto folder tiles, breadcrumbs and sidebar folders; moves are atomic
  and reject missing folders or deleted notebooks; unavailable folders reject drops.
- Notes shows only root items; opening a folder shows its immediate children.
- New Notebook sheet creates in the current folder (`NewNotebookSheet(folderName:)`).
- Import: PDF, `.betternotes` backup, JPEG, PNG, HEIC, HEIF, TIFF, GIF, BMP, WebP;
  the destination picker always appears and Cancel creates nothing; importing the
  same backup twice does not clash; corrupt files fail cleanly and leave no partial
  notebook; incoming "Open in" URLs queue and open the imported notebook; Word,
  Excel, PowerPoint and text are unsupported and must say so.
- Sort (check the header translates), search, favourites, archive, trash views.
- Editable backup export and re-import round trip with audio and old rich text
  (`ArchiveRoundTripTests`); the legacy-store migrations (`BetterNotesTests`,
  `RichTextMigrationTests`) keep their `originalName` mappings.
- PDF export (single page and whole notebook, vertical mode) honours tape, ink
  colour (no white-on-white) and line settings.

### I. Settings, language and accessibility
- App Language: English, Simplified, Traditional switch immediately and persist.
  List any untranslated visible string. Known gap: "More Selection Actions".
- Settings sidebar layout in portrait and landscape; Input settings (finger drawing,
  Scribble to Erase); OCR settings; Nearby Sync settings.
- VoiceOver labels on toolbar, menus and the new selection menu; Dynamic Type; hit
  targets of at least 44 pt on anything that sits under the full-page lasso overlay.

### J. Nearby sync (iPad and Mac)
Files: `Services/NearbySync.swift`, spec
`docs/superpowers/specs/2026-10-01-sync-conflict-and-delete-policy-design.md`, tests
`ArchiveRoundTripTests`, `NearbyFolderSyncTests`. Multipeer, Bonjour
`_better-notes._tcp`, required encryption, protocol v5.
- Automatable: every decision as a pure function (`NearbyMergeDecision.decide`,
  deletion decision, `NearbyFolderSync.merge`, the deletion log). Cover each
  conflict policy (keep both, newest wins, prefer iPad, prefer Mac) by role, ties,
  missing dates, one-sided edits, mismatched settings falling back to keep both,
  v4 packages rejected, folders from older peers left alone, a folder removed on one
  side removed on the other, folders holding notebooks recreated.
- Conflict copies are born archived; Trash syncs as an edit and each device keeps its
  own Trash; a permanent delete is queued for the peer, which asks once and never
  deletes a notebook edited since the last sync; Keep is remembered.
- Review `NearbySyncCoordinator` for races (no coordinator tests exist): interrupted
  transfer, quitting mid-sync, an open editor on the iPad deferring an incoming
  update, the Mac is not tracked as open (known gap), whole-library in-memory
  snapshot size.
- **[Device pair, needs a person]** first pairing and the local-network prompt,
  reconnect after restart or backgrounding, concurrent edits under each policy,
  permanent delete answered Keep and Delete, Empty Trash batch, large media library.
  The owner's school network blocks this; a phone hotspot or home Wi-Fi works.

### K. Persistence, migration and performance
- Relaunch persistence for everything above; legacy SwiftData stores migrate
  (`originalName` mappings on the three to-many relationships).
- Autosave is silent on success and shows a Retry badge on failure.
- Memory and hangs: 50-page notebook, 500-stroke page, large PDF import, repeated
  OCR (physical-memory logging exists), rapid page switching, background and
  foreground. Look for work on the main thread (`Thread.sleep`, synchronous file
  or audio I/O) and unbounded growth.
- `InkJournal.log` caps near 256 KB and records counts only, never note text.

### L. Privacy, security and release hygiene
- No key, token or note text in logs (`InkJournal`, `question-detector` console
  lines, provider errors); Keychain services separate for answering AI and OCR.
- `PrivacyInfo.xcprivacy` present and accurate; usage strings for microphone,
  speech recognition, photos, local network; Bonjour service declared.
- BetterNotes registers only the `.betternotes` UTI; PDFs and images are not
  registered system-wide.
- Version and build numbers, signing (`DEVELOPMENT_TEAM` at project level),
  Release configuration builds, no debug-only paths in Release.

### M. Mac companion
Only 4 Mac tests exist. Build and run `BetterNotesMac`, then review: text and rich
text editing, screenshots, page layout, AI, sync receiving an update while a notebook
is being edited (currently not deferred: confirm nothing crashes and describe what
happens to the in-progress edit), shared files stay platform-neutral. Propose the
smallest set of Mac tests that would have caught the sync and folder logic.

---

## 4. Order of work
1. Reproduce the baseline (section 1).
2. Run the targeted tests named in sections B, C, E, F, H.
3. Code-review the open bugs (section 5) with the highest user impact first:
   recording freeze, stroke reappear/move, OCR image preparation.
4. Write missing tests: sync coordinator races, stress erase then draw, recording
   start/stop races, folder move/trash edge cases.
5. Run the full simulator suite once, then restart the simulator and re-run any
   failures individually before calling them real.
6. Write the report.

## 5. Open problems to confirm and root-cause
1. Recording: the recording bar did not appear and the app froze (fix written, never
   verified with a real microphone).
2. Strokes occasionally move, resize or reappear after erasing many strokes
   (sporadic; no reproduction; `InkJournal` added).
3. OCR accuracy on English handwriting is poor with Apple Vision (largest issue).
4. Long-press on the recording play button may show Select All / Insert Space.
5. Rotated elements: finger-drag handles ignore rotation; duplicate finger-drag
   pipelines; invisible handles on unselected elements; empty text boxes invisible;
   `.offset` on the page pill at `NotebookView.swift` near line 213; dead
   `pageZoomCommand`.
6. OCR is pinned to en-US (no Chinese handwriting).
7. Some strings are missing from the catalog ("The request failed: …", Paste, Tape,
   "More Selection Actions").
8. No `NearbySyncCoordinator` tests; the Mac is not tracked for open-editor deferral.
9. Two `RELEASE_CHECKLIST.md` lines are stale; reconcile them with the code.

## 6. Report format
Reply with:
1. **Summary** (five lines): tests run, pass/fail counts, number of defects by
   severity.
2. **Baseline result** against the numbers in section 1.
3. **Defects**, one block each: ID, severity (blocker / major / minor), area (A–M),
   steps, expected, actual, `file:line`, suspected cause, evidence (log lines or
   failing test), and fix status (none / proposed / committed on `codex-test-pass`).
4. **Coverage table**: each area A–M marked tested by automation, reviewed in code
   only, or needs a person on a device, with the reason.
5. **Needs a person**: an ordered checklist the owner can follow on the iPad (and the
   iPad plus Mac pair), each with exact steps and the expected result.
6. **Tests added or changed**, and anything you could not run and why.

State clearly when a result is simulator-only, mocked, or inferred from reading code.
