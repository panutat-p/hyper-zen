---
name: preview-icon
description: Render and compare sets of Apple SF Symbols for two to five application states in a self-contained selectable preview at enlarged and menu-bar sizes. Use when the user asks to find, preview, display, compare, or choose built-in macOS icons, colored state indicators, status-item or menu-bar symbols, or alternative icon sets.
---

# Preview Icon

Create a visual comparison of genuine built-in Apple SF Symbols. Render each symbol through AppKit, embed every image in the preview, and show both enlarged and approximate 18-point menu-bar sizes.

## Workflow

1. Identify the exact application states and their semantics. Keep independent concepts separate.
2. Select one to six coherent symbol sets. Prefer shape changes as well as color changes so meaning does not depend on color alone.
3. Prefer symbols available on the app's minimum macOS version. The renderer also fails clearly when a symbol is unavailable on the current Mac.
4. Write a JSON specification to a temporary path.
5. Run `scripts/build_preview.py` and write its output to the thread-scoped visualization directory from the environment context.
6. Confirm the output is under 2 MB and contains only embedded `data:image/png;base64` image sources.
7. Display it with `::codex-inline-vis{file="<filename>.html"}`.
8. Implement a selection only after the user chooses it.

Do not use relative image paths; the inline viewer cannot resolve them reliably. Do not modify application code while merely presenting choices.

## JSON specification

Keep icons in the same order as `states`.

```json
{
  "title": "HyperZen three-state menu-bar icons",
  "states": [
    {"id": "active", "label": "Active"},
    {"id": "disabled", "label": "Disabled"},
    {"id": "blocked", "label": "Blocked"}
  ],
  "sets": [
    {
      "id": "playback",
      "label": "E · Playback",
      "choice": "E — Playback",
      "icons": [
        {"symbol": "play.fill", "colors": ["systemGreen"]},
        {"symbol": "pause.fill", "colors": ["systemGray"]},
        {"symbol": "stop.fill", "colors": ["systemRed"]}
      ]
    }
  ],
  "default_set": "playback",
  "action_title": "Choose icon set",
  "action_prompt": "Use {choice} as the static three-state menu-bar indicator."
}
```

Use multiple palette colors for layered symbols when necessary, for example `["white", "systemGreen"]` for a white checkmark inside a green filled circle.

Supported colors: `white`, `black`, `label`, `secondaryLabel`, and AppKit `systemBlue`, `systemBrown`, `systemGray`, `systemGreen`, `systemIndigo`, `systemOrange`, `systemPink`, `systemPurple`, `systemRed`, `systemTeal`, and `systemYellow`.

## Command

Resolve the skill directory from the loaded `SKILL.md` path instead of assuming the current directory.

```bash
python3 <skill-dir>/scripts/build_preview.py \
  --spec /tmp/icon-preview-spec.json \
  --output <visualization-dir>/apple-icon-options.html
```

Use a new lowercase hyphenated output filename for every revised comparison so the client does not reuse a stale preview.
