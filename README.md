# resume-me-agent

> "Resume me, agent." — Markdown-to-PDF job applications with a coding agent in the loop.

A small toolkit for writing job applications (cover letter + CV) as Markdown,
rendering them to PDF via LaTeX + Fira Sans, and optimizing them for ATS / LLM
screening with a coding agent (Claude Code, OpenAI Codex). Built around a
single Docker image so the only host dependency is Docker (or Podman).

## What you get

- A LaTeX pipeline that turns Markdown into a clean two-page PDF (cover letter
  page + CV page) with custom renderers for project lists, role headings, and
  a flex-layout skills section
- A wrapper script `./bewerbung` with `new` / `build` / `watch` / `clean` / `shell`
- A generic template you customize with your own data (profile, experience,
  projects, skills, languages)
- A skill file (`.claude/skills/bewerbung.md` or `AGENTS.md` for Codex) that
  tells your coding agent how to analyze a job posting, do gap analysis,
  optimize the application for ATS/LLM screening, run a self-test, and build

## Quick start

```sh
git clone https://github.com/tobiasbrummer/resume-me-agent ~/applications
cd ~/applications
./setup.sh
```

That's it. `setup.sh` pulls the Docker image, extracts the generic template
into your working directory, asks which agent you use, and writes the
matching agent instructions file.

To make your first application:

```sh
./bewerbung new acme-corp        # creates applications/acme-corp/ from template
# Edit applications/acme-corp/{meta.yaml,profil.md,anschreiben.md,...}
./bewerbung build acme-corp      # builds PDF
```

Output:
- `applications/acme-corp/bewerbung.pdf` (complete, both pages)
- `applications/acme-corp/anschreiben.pdf` (cover letter, page 1)
- `applications/acme-corp/lebenslauf.pdf` (CV, pages 2+)

## For agents (Claude Code, Codex, ...)

If a user gives you this repo's URL and asks you to set things up, do this:

```sh
# 1. Clone into the user's chosen directory
git clone https://github.com/tobiasbrummer/resume-me-agent <target>
cd <target>

# 2. Run setup non-interactively with your agent name
./setup.sh --non-interactive --agent=claude   # or --agent=codex
```

After setup:
- Read `.claude/skills/bewerbung.md` (Claude Code) or `AGENTS.md` (Codex) --
  these contain the full workflow for analyzing a posting and optimizing the
  application
- Read `CLAUDE.md` or `AGENTS.md` for the pipeline internals (file roles,
  LaTeX gotchas, tuning knobs)
- Ask the user for: company name, job posting (text or URL), language, and
  any specific angle they want emphasized
- Run `./bewerbung new <company>`, edit the files, run `./bewerbung build <company>`,
  verify the PDF

The skill covers ATS/LLM screening optimization (keyword density, Lost-in-
the-Middle structure, job-title contextualization, self-test simulation).
Read it before writing anything.

## Requirements

- Docker or Podman (the wrapper auto-detects)
- A coding agent (optional but recommended): Claude Code or OpenAI Codex
- Optionally: any font you want to use, installed locally

## Fonts

The default font is `TeX Gyre Heros` -- it's bundled with `texlive-fonts-recommended`
in the image, so the pipeline works out of the box on any platform without
extra installs.

To use a different font (Fira Sans, Inter, IBM Plex, …), install it on your
host and set `font_family` in `user.yaml`:

```yaml
font_family: "Fira Sans"
# Optional: tune fontspec features per font.
# font_features: "Numbers=OldStyle, Ligatures={Common,TeX}, Kerning=On"
```

The wrapper mounts your host font directory into the container read-only --
no font setup inside the container needed. Default font directories by OS:

| OS | Font directory |
|---|---|
| Linux | `~/.local/share/fonts` |
| macOS | `~/Library/Fonts` |
| Windows (Git Bash / WSL) | `%USERPROFILE%\AppData\Local\Microsoft\Windows\Fonts` |

Override with `BEWERBUNG_FONTS=/your/path`.

## How it works

```
┌── Source repo (this) ──────────┐    ┌── Docker image ──────────────┐
│  pipeline/  (LaTeX templates)  │ ─→ │  /opt/pipeline/  (build src) │
│  init/      (sterile template) │ ─→ │  /opt/init/      (setup src) │
│  bin/bewerbung                 │ ─→ │  /opt/bin/bewerbung          │
│  setup.sh                      │    │  + TeXLive scheme-full       │
│  Dockerfile                    │    │  + python3-yaml, poppler, …  │
└────────────────────────────────┘    └──────────────────────────────┘
                                                    │
                                                    │  ./setup.sh extracts /opt/init/
                                                    │  + pipeline/templates/
                                                    ↓
┌── Your applications repo (user) ─────────────────────────────────┐
│  applications/_template/   (your generic baseline material)      │
│  applications/<company>/   (one per application)                 │
│  assets/portrait.jpg + signatur.png                              │
│  pipeline/templates/    (preamble + document + tokens, editable) │
│  .claude/skills/bewerbung.md  or  AGENTS.md                      │
│  CLAUDE.md  or  AGENTS.md                                        │
│  bewerbung  (extracted wrapper)                                  │
└──────────────────────────────────────────────────────────────────┘
```

When you run `./bewerbung build <company>`:
- Container starts with image `ghcr.io/tobiasbrummer/resume-me-agent:latest`
- Mounts: your repo → `/job`, host fonts → `/usr/local/share/fonts/host`
- Runs `latexmk -r /opt/pipeline/.latexmkrc applications/<company>/bewerbung.tex`
- TEXINPUTS prefers `/job/pipeline/templates/` over the image's
  `/opt/pipeline/templates/`, so any template file you keep in your repo
  wins over the baked-in version

## Customizing the design

`setup.sh` drops the LaTeX templates into `pipeline/templates/` in your
repo. Edit them directly to change colors, fonts sizes, the photo shadow,
section ordering, the cover-letter layout -- anything:

| File | What it controls |
|---|---|
| `pipeline/templates/tokens.tex` | design tokens -- colors, the `\rem` base unit, the type/space/leading scales, the text measure; self-contained and editable |
| `pipeline/templates/preamble.tex` | font sizes, list bullets, skill flex-layout, markdown renderer hooks, the sender line |
| `pipeline/templates/document.tex` | page-1 cover-letter layout and page-2+ CV layout, default section order |
| `pipeline/templates/bewerbung.tex` | the three-line stub copied into each application |

The tokens in `tokens.tex` are generated from a shared design-token source
(the author's `design-tokens` tool), so the application and the author's web
identity stay visually consistent -- same font, palette, and proportions. You
do not need that generator to tweak the look: edit `tokens.tex` directly in
your repo and the next build picks it up.

This is the natural workflow for letting a coding agent (Claude Code,
Codex) reshape the design: "make the accent color teal", "drop the photo
shadow", "move the date below the subject" -- the agent edits the file in
your repo and the next build picks it up. No image rebuild needed.

Pipeline scripts (`yaml_to_tex.py`, `split-pdf.sh`, `.latexmkrc`) stay in
the image -- they're build glue, not layout. If you really need to tweak
those, fork this repo and build your own image.

Re-running `setup.sh` keeps your edits in `pipeline/templates/`. Use
`--force` to overwrite them with the image's current defaults (backs up
to `*.bak`).

## File roles in an application directory

| File | Renders to | Edit per application |
|---|---|---|
| `meta.yaml` | recipient, date, subject, salutation, closing (auto-generated `meta.tex`) | yes |
| `profil.md` | one paragraph beside the photo on the CV page | yes |
| `anschreiben.md` | body text of the cover letter (between salutation and closing) | yes |
| `experience.md` | work history + teaching + volunteering + education | mostly reorder |
| `projects.md` | projects/research as definition-list with optional GitHub links | reorder + emphasize |
| `languages.md` | language list | rarely |
| `skills.tex` | skills in a CSS-flex-like layout | pick categories that match |
| `sections.tex` (optional) | section order in the CV with `\clearpage` positions | per role type |
| `bewerbung.tex` | three-line stub: `\input{preamble}` + `\input{meta}` + `\input{document}` | never |

Things that do **not** belong in the Markdown files (the LaTeX layer renders
them, duplicating them would print twice or leak reviewer notes into the PDF):
addresses, dates, subjects, salutations, closings, signatures, H1 headings,
"## Profile" sections, "Applying for:" notes.

## Languages

The pipeline renders German and English. Set `sprache: de` or `sprache: en`
in `meta.yaml`. The CV title ("Lebenslauf" / "Curriculum Vitae"), the
enclosures label ("Anlagen" / "Enclosures"), and the footer ("Seite X von Y"
/ "Page X of Y") follow that setting.

## Updating

```sh
docker pull ghcr.io/tobiasbrummer/resume-me-agent:latest
```

Or rerun `./setup.sh` -- it's idempotent and re-extracts the latest
templates without overwriting your customizations (it backs up to
`*.bak` if there's a real conflict).

## See also

- **[career-ops](https://career-ops.org/)** -- a separate open-source toolkit
  for the job-search side: scraping postings from portals, tracking
  applications, follow-up cadence. Different project; complementary if you
  want both halves of the workflow.

## Repository layout

```
resume-me-agent/
  Dockerfile
  pipeline/                       # baked into /opt/pipeline/ in the image
    templates/{bewerbung,preamble,document,tokens}.tex
    scripts/{yaml_to_tex.py,split-pdf.sh}
    .latexmkrc
  init/                           # baked into /opt/init/, extracted by setup.sh
    applications/_template/
    assets/{portrait.jpg,signatur.png}
    .claude/skills/bewerbung.md
    CLAUDE.md.template
    AGENTS.md.template
    README.md.template
    .gitignore.template
  bin/bewerbung                   # wrapper, baked into /opt/bin/
  setup.sh                        # interactive + --non-interactive modes
  README.md                       # this file
  LICENSE                         # MIT
  .github/workflows/build.yml     # builds image, pushes to ghcr.io on main
```

## License

MIT -- see [LICENSE](./LICENSE).
