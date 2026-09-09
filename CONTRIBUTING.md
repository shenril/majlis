# Contributing to Majlis

Thanks for wanting to make Majlis better. This is a small, friendly template — contributions
that make it clearer, safer, or easier to adapt are all welcome.

## The one rule that matters most: no personal data

Majlis is a template for a **personal** advisory team, which means the real thing fills up
with private information fast. When contributing to the public template:

- **Never commit personal data.** No real names, employers, financial figures, health
  details, locations, emails, or file paths that leak a username.
- **Never commit your knowledge base or secrets.** No `*.db`, `*.bak`, backups, personal SQL,
  or passphrases. The `.gitignore` covers the common cases, but you are the last line of
  defense — scan your diff before you push.
- **Keep the inbox and brain folders empty** in the template. `Team's Inbox/`,
  `Owner's Inbox/`, and `Team's brain/` ship with only `.gitkeep` files; your private content
  stays in your own fork, never in a PR here.

If you're unsure whether something is personal, leave it out.

## How the repo is structured

```
Majlis/
├── CLAUDE.md            ← the operating charter every member reads
├── README.md
├── install.py           ← renders templates/ into a council (run before first use)
├── templates/           ← THE TRACKED SOURCE: boilerplate install.py instantiates
│   ├── core/            ← founding-trio agent templates
│   ├── advisors/        ← one self-contained package per advisor
│   └── shared/          ← fragments shared across advisors
├── team/
│   ├── roster.md        ← GENERATED list of members and what they own
│   └── owner-profile.md ← GENERATED owner dossier
├── .claude/
│   ├── agents/          ← GENERATED, one file per installed member
│   └── skills/          ← reusable skill packages (per-advisor intake is generated)
├── database/            ← optional encrypted knowledge base + governance layer
├── Team's Inbox/        ← intake (you drop tasks here)
├── Owner's Inbox/       ← outbox (finished deliverables land here)
└── Team's brain/        ← per-member working memory
```

## Proposing a new example agent

Majlis grows the same way in the template as it does in real use — follow the built-in
**Researcher → HR Lead** pattern:

> **Edit `templates/`, never the generated output.** A change to `.claude/agents/*.md`,
> `team/roster.md` or `team/owner-profile.md` is wiped by the next `install.py` run.

1. **Research (Researcher's job).** Ground the persona in what a real expert in that domain
   actually does: their core skills, tools, methodologies, vocabulary, typical deliverables,
   and quality bar. Don't invent a skill set from thin air.
2. **Design (HR Lead's job).** Turn that research into an agent file. Every agent lives at
   `.claude/agents/<name>.md` and has:
   - **Frontmatter:** `name`, `description`, `tools`, `model`.
   - **A system prompt** defining the persona, identity, scope boundaries, and operating
     standards — including "executes; does not orchestrate or hire."
   - For public example agents, a header line: `# Example team member — adapt to your life.`
3. **Register it.** Add a one-line row to `team/roster.md`.
4. **Keep it generic.** Example agents must contain zero personal data — they're scaffolding
   for others to adapt.

Good example agents are concrete about *how the role works* while staying free of any real
person's details.

## PR etiquette

- **One focused change per PR.** Small and reviewable beats big and sweeping.
- **Describe the why**, not just the what, in the PR description.
- **Run a quick self-scan** for personal data before opening the PR.
- **Match the existing tone** — calm, concrete, skimmable. Prose over jargon.
- **Docs are code.** If you change behavior, update `CLAUDE.md`, the `README`, or the roster
  to match.

## Reporting issues

Open an issue for bugs, unclear docs, or ideas. If it's a security or privacy concern (e.g. a
place the template could leak data), please call that out clearly so it gets priority.

Welcome to the Majlis.
