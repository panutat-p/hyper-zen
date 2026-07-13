#!/usr/bin/env python3
"""Render Apple SF Symbol sets into a self-contained inline HTML comparison."""

from __future__ import annotations

import argparse
import base64
import html
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


MAX_OUTPUT_BYTES = 2_000_000


def fail(message: str) -> None:
    raise SystemExit(f"preview-icon: {message}")


def load_spec(path: Path) -> dict:
    try:
        spec = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        fail(f"could not read {path}: {error}")

    states = spec.get("states")
    icon_sets = spec.get("sets")
    if not isinstance(states, list) or not 2 <= len(states) <= 5:
        fail("states must contain between 2 and 5 entries")
    if not isinstance(icon_sets, list) or not 1 <= len(icon_sets) <= 6:
        fail("sets must contain between 1 and 6 entries")

    state_ids: set[str] = set()
    for state in states:
        if not isinstance(state, dict) or not state.get("id") or not state.get("label"):
            fail("each state requires non-empty id and label values")
        if state["id"] in state_ids:
            fail(f"duplicate state id '{state['id']}'")
        state_ids.add(state["id"])

    set_ids: set[str] = set()
    for icon_set in icon_sets:
        if not isinstance(icon_set, dict) or not icon_set.get("id") or not icon_set.get("label"):
            fail("each set requires non-empty id and label values")
        if icon_set["id"] in set_ids:
            fail(f"duplicate set id '{icon_set['id']}'")
        set_ids.add(icon_set["id"])
        icons = icon_set.get("icons")
        if not isinstance(icons, list) or len(icons) != len(states):
            fail(f"set '{icon_set['id']}' must provide one icon per state")
        for icon in icons:
            if not isinstance(icon, dict) or not icon.get("symbol"):
                fail(f"set '{icon_set['id']}' contains an icon without a symbol")
            colors = icon.get("colors", [])
            if not isinstance(colors, list) or not all(isinstance(item, str) for item in colors):
                fail(f"colors for '{icon['symbol']}' must be a string array")

    default_set = spec.get("default_set", icon_sets[0]["id"])
    if default_set not in set_ids:
        fail(f"default_set '{default_set}' does not match a set id")
    return spec


def data_url(path: Path) -> str:
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def escaped(value: object) -> str:
    return html.escape(str(value), quote=True)


def javascript_string(value: str) -> str:
    return json.dumps(value, ensure_ascii=False).replace("</", "<\\/")


def build_html(spec: dict, png_directory: Path, output: Path) -> str:
    states = spec["states"]
    icon_sets = spec["sets"]
    default_set = spec.get("default_set", icon_sets[0]["id"])
    root_suffix = re.sub(r"[^a-z0-9-]+", "-", output.stem.lower()).strip("-") or "preview"
    root_id = f"preview-icon-{root_suffix}"
    title = spec.get("title", "Apple SF Symbol icon comparison")

    option_markup: list[str] = []
    for set_index, icon_set in enumerate(icon_sets):
        choice = icon_set.get("choice", icon_set["label"])
        selected = icon_set["id"] == default_set
        classes = "btn viz-tile option is-selected" if selected else "btn viz-tile option"
        state_markup: list[str] = []
        symbols: list[str] = []
        for state_index, (state, icon) in enumerate(zip(states, icon_set["icons"])):
            source = data_url(png_directory / f"set-{set_index}-state-{state_index}.png")
            alt = icon.get("alt", f"{state['label']}: {icon['symbol']}")
            symbols.append(icon["symbol"])
            state_markup.append(
                f'''<span class="state">
          <span>{escaped(state["label"])}</span>
          <img src="{source}" alt="{escaped(alt)}">
          <span class="mini"><img src="{source}" alt=""></span>
        </span>'''
            )

        option_markup.append(
            f'''<button type="button" class="{classes}" data-choice="{escaped(choice)}" aria-pressed="{str(selected).lower()}">
      <span class="option-name">{escaped(icon_set["label"])}</span>
      <span class="symbol-row">{"".join(state_markup)}</span>
      <code>{escaped(" / ".join(symbols))}</code>
    </button>'''
        )

    selected_set = next(item for item in icon_sets if item["id"] == default_set)
    selected_choice = selected_set.get("choice", selected_set["label"])
    action_prompt = spec.get(
        "action_prompt",
        "Use {choice} as the selected static application icon set.",
    )
    action_title = spec.get("action_title", "Choose icon set")
    button_label = spec.get("button_label", "Choose this set")

    return f'''<div id="{root_id}" style="--state-count: {len(states)}" aria-label="{escaped(title)}">
  <div class="viz-grid options" role="group" aria-label="{escaped(title)}">
    {"".join(option_markup)}
  </div>
  <div class="viz-controls choice-controls">
    <span class="selected-choice" aria-live="polite">Selected: {escaped(selected_choice)}</span>
    <button type="button" class="btn btn-primary choose-icon">{escaped(button_label)}</button>
  </div>
</div>

<style>
  #{root_id} {{ display: grid; gap: 1rem; color: var(--foreground); }}
  #{root_id} .options {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }}
  #{root_id} .option {{ display: grid; gap: 0.75rem; min-width: 0; text-align: start; }}
  #{root_id} .option-name {{ font-weight: 500; }}
  #{root_id} .symbol-row {{ display: grid; grid-template-columns: repeat(var(--state-count), minmax(0, 1fr)); gap: 0.5rem; }}
  #{root_id} .state {{ display: grid; justify-items: center; gap: 0.4rem; color: var(--muted-foreground); }}
  #{root_id} .state > img {{ width: 3.5rem; height: 3.5rem; object-fit: contain; }}
  #{root_id} .mini {{ display: grid; place-items: center; width: 2.75rem; height: 1.5rem; background: color-mix(in srgb, var(--foreground) 9%, transparent); }}
  #{root_id} .mini img {{ width: 1.125rem; height: 1.125rem; object-fit: contain; }}
  #{root_id} code {{ overflow-wrap: anywhere; color: var(--muted-foreground); }}
  #{root_id} .choice-controls {{ justify-content: space-between; }}
  @media (max-width: 520px) {{ #{root_id} .options {{ grid-template-columns: 1fr; }} }}
</style>

<script>
  (() => {{
    const root = document.getElementById({javascript_string(root_id)});
    const options = Array.from(root.querySelectorAll('.option'));
    const selectedLabel = root.querySelector('.selected-choice');
    const chooseButton = root.querySelector('.choose-icon');
    const promptTemplate = {javascript_string(action_prompt)};
    let selected = {javascript_string(selected_choice)};

    options.forEach((option) => {{
      option.addEventListener('click', () => {{
        options.forEach((candidate) => {{
          const isSelected = candidate === option;
          candidate.classList.toggle('is-selected', isSelected);
          candidate.setAttribute('aria-pressed', String(isSelected));
        }});
        selected = option.dataset.choice;
        selectedLabel.textContent = `Selected: ${{selected}}`;
      }});
    }});

    chooseButton.addEventListener('click', async () => {{
      if (window.openai?.sendFollowUpMessage) {{
        await window.openai.sendFollowUpMessage({{
          title: {javascript_string(action_title)},
          prompt: promptTemplate.replaceAll('{{choice}}', selected)
        }});
      }}
    }});
  }})();
</script>
'''


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", required=True, type=Path, help="JSON preview specification")
    parser.add_argument("--output", required=True, type=Path, help="HTML fragment to create")
    args = parser.parse_args()

    spec = load_spec(args.spec)
    output = args.output.expanduser().resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    renderer = Path(__file__).with_name("render_sf_symbols.swift")

    with tempfile.TemporaryDirectory(prefix="preview-icon-") as temporary:
        png_directory = Path(temporary)
        result = subprocess.run(
            ["swift", str(renderer), str(args.spec.resolve()), str(png_directory)],
            text=True,
            capture_output=True,
            check=False,
        )
        if result.returncode:
            sys.stderr.write(result.stderr)
            fail("SF Symbol rendering failed")

        fragment = build_html(spec, png_directory, output)
        encoded = fragment.encode("utf-8")
        if len(encoded) >= MAX_OUTPUT_BYTES:
            fail(f"generated preview is {len(encoded)} bytes; limit is {MAX_OUTPUT_BYTES}")
        output.write_bytes(encoded)

    print(output)


if __name__ == "__main__":
    main()
