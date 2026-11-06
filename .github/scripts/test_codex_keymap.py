#!/usr/bin/env python3
"""Regression checks for the chezmoi Codex config modifier."""
import os
from pathlib import Path
import subprocess
import tempfile
import tomllib

MODIFIER = Path(__file__).resolve().parents[1] / "home/dot_codex/modify_config.toml"
BINDINGS = {
    "edit_queued_message": "alt-up",
    "prompt_stack_back": "alt-down",
}


def apply(source, seed=None, *, success=True):
    with tempfile.TemporaryDirectory() as directory:
        env = os.environ.copy()
        # Always override the seed path so the test is independent of the host.
        seed_path = Path(directory) / "seed.toml"
        env["CODEX_DOTFILES_SEED_PATH"] = str(seed_path)
        if seed is not None:
            seed_path.write_text(seed)
        result = subprocess.run(
            ["python3", str(MODIFIER)],
            input=source,
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )
    assert (result.returncode == 0) == success, result.stderr
    return result.stdout if success else result.stderr


def check(source, preserved=(), seed=None):
    actual = apply(source, seed)
    chat = tomllib.loads(actual)["tui"]["keymap"]["chat"]
    assert all(chat[key] == value for key, value in BINDINGS.items())
    assert all(item in actual for item in preserved)
    assert apply(actual, seed) == actual, "modifier must be idempotent"
    return actual


check("", ())
check(
    'model = "existing"\n[tui]\nalternate_screen = "never"\n',
    ('model = "existing"', 'alternate_screen = "never"'),
)
check(
    '[tui.keymap.chat]\ninterrupt_turn = "esc"\n'
    '[projects."/work"]\ntrust_level = "trusted"\n',
    ('interrupt_turn = "esc"', 'trust_level = "trusted"'),
)
check(
    '[tui.keymap.chat]\n'
    'edit_queued_message = [\n  "shift-left",\n  "alt-up",\n]\n'
    'prompt_stack_back = "shift-right"\n'
    '[tui]\nraw_output_mode = true\n',
    ('raw_output_mode = true',),
)
seed = (
    'model = "gpt-6.1-sol"\n'
    'approval_policy = "never"\n'
    'sandbox_mode = "danger-full-access"\n'
    '[tui]\nalternate_screen = "never"\n'
)
check("", tuple(seed.splitlines()), seed=seed)
check('model = "custom"\n', ('model = "custom"',), seed=seed)
assert "inline/dotted" in apply(
    '[tui.keymap]\nchat = { edit_queued_message = "shift-left" }\n',
    success=False,
)
print("Codex keymap modifier checks passed")
