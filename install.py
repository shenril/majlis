#!/usr/bin/env python3
"""
Majlis installer — turn the boilerplate in templates/ into YOUR council.

Run this once, before opening the project in Claude Code:

    python3 install.py                 # interactive
    python3 install.py --answers a.yml # non-interactive
    python3 install.py --defaults      # accept every default, no prompts

It asks which life themes you want to delegate and what to call each advisor,
then writes the agent definitions, the roster, your brain folders, and your
owner dossier. Re-running it OVERWRITES those generated files.

Standard library only — no pip install, no virtualenv.

CLAUDE.md is deliberately NOT generated. The charter is static and always names
Jarvis, so a fresh clone boots Claude Code fine even before this script runs.
"""
from __future__ import annotations

import argparse
import pathlib
import re
import string
import sys

ROOT = pathlib.Path(__file__).resolve().parent
TEMPLATES = ROOT / "templates"

# Jarvis, HR Lead and Researcher are fixed literals, never placeholders:
# CLAUDE.md names all three and is static. See templates/PLACEHOLDERS.md.
CORE_AGENTS = {"hr-lead": "HR Lead", "researcher": "Researcher"}
CORE_ROWS = ["jarvis", "hr-lead", "researcher"]

# A display name goes verbatim into Markdown and YAML frontmatter, so it is the
# one piece of untrusted input here. Restricting it to a single line of letters,
# digits, spaces, hyphens, apostrophes and periods is what keeps a name from
# breaking frontmatter — the renderer itself does no evaluation, so this is the
# only control that matters. (See the security note in issue #1.)
NAME_RE = re.compile(r"^[A-Za-z][A-Za-z0-9 .'\-]{0,48}$")


class InstallError(Exception):
    pass


def slugify(name: str) -> str:
    """'Chief of Staff' -> 'chief-of-staff'. The handle Jarvis dispatches with."""
    slug = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")
    if not slug:
        raise InstallError(f"cannot derive a handle from {name!r}")
    return slug


def read_meta(path: pathlib.Path) -> dict:
    """Minimal manifest reader. Deliberately not a YAML library: this project
    has no third-party dependencies, and the manifests are flat key/value."""
    meta = {}
    for line in path.read_text().splitlines():
        line = line.split("#", 1)[0].strip() if line.strip().startswith("#") else line
        if not line.strip() or ":" not in line:
            continue
        key, _, value = line.partition(":")
        key, value = key.strip(), value.strip()
        if value.startswith("[") and value.endswith("]"):
            inner = value[1:-1].strip()
            meta[key] = [v.strip() for v in inner.split(",") if v.strip()]
        else:
            meta[key] = value
    return meta


def load_packages() -> dict[str, dict]:
    packages = {}
    for meta_file in sorted(TEMPLATES.glob("advisors/*/meta.yaml")):
        meta = read_meta(meta_file)
        meta["dir"] = meta_file.parent
        packages[meta["theme"]] = meta
    if not packages:
        raise InstallError(f"no advisor packages found under {TEMPLATES/'advisors'}")
    # Declared order, not glob order: it decides how the roster reads, so it is
    # a property of the packages rather than of the filesystem.
    return dict(sorted(packages.items(), key=lambda kv: int(kv[1].get("order", 99))))


def render(path: pathlib.Path, mapping: dict[str, str]) -> str:
    """Substitute, never safe_substitute: an unknown or stray placeholder must
    fail loudly rather than put an empty string into an agent's prompt."""
    try:
        return string.Template(path.read_text()).substitute(mapping)
    except KeyError as exc:
        raise InstallError(f"{path}: no value for placeholder {exc}") from None
    except ValueError as exc:
        raise InstallError(f"{path}: {exc} (write a literal '$' as '$$')") from None


# --------------------------------------------------------------------------- #
# asking
# --------------------------------------------------------------------------- #

def ask_name(prompt: str, default: str, auto: bool) -> str:
    while True:
        if auto:
            return default
        raw = input(f"  {prompt} [{default}]: ").strip() or default
        if NAME_RE.match(raw):
            return raw
        print(f"    ! use letters, digits, spaces, - . ' (max 49 chars) — got {raw!r}")


def ask_yes(prompt: str, default: bool, auto: bool) -> bool:
    if auto:
        return default
    suffix = "Y/n" if default else "y/N"
    raw = input(f"  {prompt} [{suffix}]: ").strip().lower()
    return default if not raw else raw.startswith("y")


def collect(packages: dict, auto: bool, preset: dict | None) -> dict:
    """Returns {theme: display_name} for every advisor to install."""
    chosen: dict[str, str] = {}

    prereq = {t: p for t, p in packages.items() if p.get("kind") == "prerequisite"}
    elective = {t: p for t, p in packages.items() if p.get("kind") != "prerequisite"}

    if not auto and not preset:
        print("\nYour council always includes Jarvis (orchestrator), HR Lead and Researcher.")
        print("These two run the machinery every other advisor depends on:\n")

    for theme, pkg in prereq.items():
        if preset is not None:
            chosen[theme] = preset.get(theme, pkg["default_name"])
            continue
        if not auto:
            print(f"  · {pkg['default_name']} — {pkg.get('summary','')}")
        chosen[theme] = ask_name(f"name for the {theme} advisor", pkg["default_name"], auto)

    if not auto and not preset:
        print("\nNow the elective themes — pick the parts of your life to delegate:\n")

    for theme, pkg in elective.items():
        if preset is not None:
            if theme in preset:
                chosen[theme] = preset[theme]
            continue
        if not auto:
            print(f"  · {theme} — {pkg.get('summary','')}")
        if ask_yes(f"delegate {theme}?", True, auto):
            chosen[theme] = ask_name(f"name for the {theme} advisor", pkg["default_name"], auto)

    return chosen


def validate(chosen: dict, packages: dict) -> None:
    """Refuse an impossible selection BEFORE writing anything."""
    for theme in chosen:
        for need in packages[theme].get("requires", []):
            if need not in chosen:
                raise InstallError(
                    f"'{theme}' requires the '{need}' advisor, which is not installed")

    handles: dict[str, str] = {}
    for theme, name in chosen.items():
        if not NAME_RE.match(name):
            raise InstallError(f"invalid display name for '{theme}': {name!r}")
        handle = slugify(name)
        if handle in CORE_AGENTS or handle == "jarvis":
            raise InstallError(f"'{name}' collides with the founding member '{handle}'")
        if handle in handles:
            raise InstallError(
                f"'{name}' and '{handles[handle]}' both slugify to '{handle}'")
        handles[handle] = name


def build_mapping(chosen: dict, packages: dict) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for theme, name in chosen.items():
        key = packages[theme]["placeholder"]
        mapping[key] = name
        mapping[f"{key}_handle"] = slugify(name)
    return mapping


# --------------------------------------------------------------------------- #
# writing
# --------------------------------------------------------------------------- #

def install(chosen: dict, packages: dict, mapping: dict) -> list[str]:
    written = []

    def put(rel: str, text: str):
        path = ROOT / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        written.append(rel)

    for handle in CORE_AGENTS:
        put(f".claude/agents/{handle}.md", render(TEMPLATES / f"core/{handle}.md", mapping))

    for theme, name in chosen.items():
        pkg = packages[theme]
        handle = slugify(name)
        put(f".claude/agents/{handle}.md", render(pkg["dir"] / "agent.md", mapping))

        intake = pkg["dir"] / "intake.md"
        if intake.exists():
            # Each advisor gets its OWN intake skill: the domain questions from
            # its package, followed by the shared six-bucket spine. Installing an
            # advisor installs its interview; skipping one installs nothing.
            spine = TEMPLATES / "shared" / "intake-spine.md"
            text = render(intake, mapping)
            if spine.exists():
                text = text.rstrip("\n") + "\n\n" + render(spine, mapping)
            put(f".claude/skills/{handle}-intake/SKILL.md", text)

        brain = ROOT / f"Team's brain/{handle}"
        brain.mkdir(parents=True, exist_ok=True)
        (brain / ".gitkeep").touch()
        written.append(f"Team's brain/{handle}/")

    rows = [render(TEMPLATES / f"core/roster-row-{c}.md", mapping).rstrip("\n")
            for c in CORE_ROWS]
    rows += [render(packages[t]["dir"] / "roster-row.md", mapping).rstrip("\n")
             for t in chosen]
    roster = string.Template(
        (TEMPLATES / "roster.md").read_text()).substitute({**mapping, "rows": "\n".join(rows)})
    put("team/roster.md", roster)

    # The dossier only carries sections for advisors that were installed.
    sections = [render(packages[t]["dir"] / "profile-section.md", mapping)
                for t in chosen if (packages[t]["dir"] / "profile-section.md").exists()]
    profile = string.Template((TEMPLATES / "owner-profile.md").read_text()).substitute(
        {**mapping, "profile_sections": "".join(sections)})
    put("team/owner-profile.md", profile)
    return written


def parse_answers(path: pathlib.Path) -> dict:
    answers = {}
    for line in path.read_text().splitlines():
        if not line.strip() or line.strip().startswith("#") or ":" not in line:
            continue
        key, _, value = line.partition(":")
        answers[key.strip()] = value.strip().strip("\"'")
    return answers


def main() -> int:
    ap = argparse.ArgumentParser(description="Instantiate your Majlis council.")
    ap.add_argument("--answers", type=pathlib.Path,
                    help="non-interactive: 'theme: Display Name' per line; "
                         "omitted electives are not installed")
    ap.add_argument("--defaults", action="store_true",
                    help="accept every default without prompting")
    args = ap.parse_args()

    try:
        packages = load_packages()
        preset = parse_answers(args.answers) if args.answers else None
        if preset is not None:
            unknown = set(preset) - set(packages)
            if unknown:
                raise InstallError(f"unknown theme(s) in answers: {sorted(unknown)}")

        chosen = collect(packages, auto=args.defaults, preset=preset)
        validate(chosen, packages)
        mapping = build_mapping(chosen, packages)
        written = install(chosen, packages, mapping)
    except InstallError as exc:
        print(f"\nFAILED: {exc}", file=sys.stderr)
        return 1
    except (KeyboardInterrupt, EOFError):
        print("\naborted — nothing written.", file=sys.stderr)
        return 130

    print(f"\nYour council is ready — {len(written)} paths written:\n")
    for theme, name in chosen.items():
        print(f"  {name:<24} {slugify(name):<22} ({theme})")
    print("\nNext: open this folder in Claude Code and say")
    print('  "Jarvis, start my intake."\n')
    return 0


if __name__ == "__main__":
    sys.exit(main())
