# Template placeholders

Templates in this tree are **plain Markdown**. Personalization is `${placeholder}` substitution via
Python's stdlib `string.Template` — there is no template language, no expressions, and no evaluation.

Conditionality is *"include this fragment or not"*: a block that only applies when some other theme
is installed lives in `fragments/` and is concatenated only when that theme is present.

## The placeholders

| Placeholder | Substituted with |
|---|---|
| `${data_specialist}` | display name of the data/knowledge advisor |
| `${data_specialist_handle}` | its slug — the `subagent_type` Jarvis dispatches |
| `${planning_advisor}` / `${planning_advisor_handle}` | the planning advisor |
| `${health_advisor}` / `${health_advisor_handle}` | the health advisor |
| `${finance_advisor}` / `${finance_advisor_handle}` | the finance advisor |
| `${career_advisor}` / `${career_advisor_handle}` | the career advisor |

**Display name is free-form** ("Chief of Staff", "Watari"). **The handle is slugified from it**
(`chief-of-staff`, `watari`) and is what appears in agent frontmatter `name:` and in the roster's
`subagent_type` column.

## Names that are NOT placeholders

**Jarvis, HR Lead and Researcher are fixed literals.** The orchestrator is always Jarvis, and
`CLAUDE.md` — which names all three — is static and tracked, never generated. Do not turn them into
placeholders.

## Rules

- `install.py` renders with `substitute()`, **not** `safe_substitute()`. An unknown or stray
  placeholder is a hard failure, never a silently empty string in a prompt.
- A literal `$` must be written `$$`. There are currently none in any template.
- Never reference an advisor from a theme you don't depend on — put it in `fragments/` instead.
