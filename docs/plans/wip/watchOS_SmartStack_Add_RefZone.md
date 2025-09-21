# Add RefZone to Smart Stack (watchOS)

Quick reference for adding and testing the RefZone Smart Stack widget on Apple Watch or the watchOS Simulator.

## Add the widget
- Show Smart Stack
  - On device: rotate the Digital Crown up from the watch face.
  - In Simulator: two‑finger scroll up on the watch face, or click‑and‑drag the on‑screen crown to scroll up.
- Enter edit mode: press and hold any Smart Stack card, then tap "Edit".
- Add RefZone: tap "+", search for "RefZone".
- Choose style and add:
  - Select the Rectangular style and tap "Add Widget".
  - Repeat to add the Circular style as well.
- Reorder: drag RefZone to the top of the stack, then tap "Done" (or press the Digital Crown) to finish.

## Verify behavior
- Timer animation: while a match is running, the timer animates on the widget.
- Indicators: paused shows a pause icon; stoppage shows a stopwatch icon.
- Deep link: tapping the widget opens `refzone://timer` and routes into the timer control surface.

## Troubleshooting
- RefZone not listed in "+":
  - Launch the RefZone watch app once, then try adding again.
  - Trigger an update (pause/resume/score) to force a timeline reload.
  - Ensure both the watch app and widget targets have App Group `group.refzone.shared` enabled.
- Widget not updating:
  - Verify you’re running the latest build and the match is active.
  - Trigger any publishing event (pause/resume/score) to reload Widget timelines.
- Circular layout looks rectangular:
  - Make sure you added the Circular style; the widget auto‑selects layout based on family.

## Notes
- Supported families: Accessory Rectangular and Accessory Circular.
- The widget is driven by App Group state and reloads; timelines are set to `.after(expectedEnd)` while running and `.never` otherwise.
