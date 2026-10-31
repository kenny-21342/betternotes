# Final device checklist (30 Oct 2026)

Run on the iPad with a **normal launch** (no test arguments). Tick each box; note anything that fails.

## 1. Touch and selection (about 5 min)
- [ ] Pen: write a few words, erase some, write again. Nothing moves or reappears.
- [ ] Lasso a group of strokes. The menu appears beside the selection.
- [ ] Tap the selection: the menu hides. Tap again: it comes back, and the selection stays.
- [ ] Duplicate: a copy appears and is selected.
- [ ] Copy, then Paste: the pasted ink appears and is selected.
- [ ] Delete: the ink is gone.
- [ ] Lasso an image and a recording together: the menu still works.
- [ ] Vertical scroll mode: pull up past the last page. A page is added.
- [ ] Single-page mode: a long pull at the end adds a page; a short pull does not.

## 2. Recording (about 3 min)
- [ ] Settings are in vertical scroll mode: the recording bar shows bottom-left.
- [ ] Record 10 seconds, tap Stop. No freeze, and the clip appears on the page.
- [ ] Play the clip: progress moves, Pause works.
- [ ] Cancel a recording: no clip is saved.
- [ ] Leave the notebook mid-recording: one clip is saved.
- [ ] Start a recording, lock the iPad for 10 seconds, unlock. Note what happened.

## 3. Cloud OCR (about 5 min)
- [ ] Settings > OCR: enter the Baidu AI Studio API_URL and token.
- [ ] Press the connection test: it succeeds.
- [ ] Write a line ending in `??`. The label appears and the recognized text is right.
- [ ] Try one line of your math homework. Note the accuracy.
- [ ] Turn the network off: the label shows an error with Retry, and existing OCR text is kept.

## 4. Data safety (about 10 min)
- [ ] Back up the library (More > Export).
- [ ] Install a clean build (delete app first), then restore the backup. Notebooks, folders and ink all return.
- [ ] Install the release build over the current one. Nothing is lost.
- [ ] Delete a notebook to Trash, restore it. Empty Trash removes it for good.

## 5. Import and export (about 5 min)
- [ ] Import a large PDF into a chosen folder. Annotate a page.
- [ ] Import a photo. Draw on it.
- [ ] Export a notebook as PDF and open it.

## 6. Nearby sync with the Mac (needs a shared network)
- [ ] First connection: approve on both devices.
- [ ] Edit on the iPad: the Mac shows it. Edit on the Mac: the iPad shows it.
- [ ] Edit the same notebook on both without syncing: the result matches the Nearby Sync setting.
- [ ] Move a notebook to Trash on one side: it follows.
- [ ] Permanently delete a shared notebook: the other device asks before deleting.
- [ ] Mac's selected notebook counts as open, so iPad edits to it wait until another one is selected.

## 7. Long session (10 to 15 min)
- [ ] Write and erase heavily. If strokes ever move or reappear, pull the log:
  `xcrun devicectl device copy from --device 64E718A4-0CFA-5BCA-9640-EE6B5AD95B72 --domain-type appDataContainer --domain-identifier com.kenny-lhs.betternotes --source "Library/Application Support/InkJournal.log" --destination ~/Desktop/InkJournal.log`

## 8. Fresh install and release build
- [ ] Delete the app, reinstall. Microphone, local network and Pencil prompts appear with sensible wording.
- [ ] Archive in Release and run it on the iPad. No test-only behavior shows.

## 9. Optional
- [ ] Dark Mode on the library, editor and settings.
- [ ] Larger Dynamic Type on the library.
- [ ] Chinese language: "More Selection Actions" is still untranslated.
- [ ] Split View with a notebook open.
