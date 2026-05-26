---
name: bewerbung
description: Build a job application (cover letter + CV) optimized for ATS / LLM screening. Trigger when the user provides a job posting (text, URL, or file) and asks for an application, or wants to adapt an existing one to a new posting. Pipeline: ./bewerbung new <company> creates an application directory from the template; you edit the markdown files; ./bewerbung build <company> renders to PDF.
---

# Build a job application

## What this skill does

Turns a job posting into a stelle-specific application. Reads the user's
generic material from `applications/_template/`, the posting (text or URL),
and produces a new `applications/<company>/` with files customized for the
role. Builds via container.

## Inputs

1. **Job posting** -- text, URL, or file (required)
2. **Target directory name** -- e.g. `acme-corp`, `qdrant`, `bitbw-ki-hub` (required)
3. **Language** -- inferred from the posting (German or English)
4. **References** -- the user's `applications/_template/` (their generic
   baseline) and any earlier applications under `applications/<other>/`
   that may be useful as tone/style reference

## Pipeline map (who renders what)

Critical: Markdown files must NOT contain what the LaTeX layer renders --
otherwise the output is duplicated or reviewer notes leak into the PDF.

| File | What goes in | What does NOT |
|---|---|---|
| `user.yaml` (at repo root) | name, address, phone, email, github | -- |
| `meta.yaml` → `meta.tex` (auto) | recipient, date, subject, language, salutation, closing | personal stammdaten (come from user.yaml) |
| `profil.md` | one paragraph beside the photo on the CV page | no heading, no "## Profile" |
| `anschreiben.md` | body text between salutation and closing | no sender, date, subject, salutation, closing, signature |
| `experience.md` | experience + teaching + volunteering + education | no H1, no "## Profile", no reviewer notes |
| `projects.md` | projects section (DL-items with GitHub URLs) | same as experience |
| `languages.md` | languages | same |
| `skills.tex` | skills in flex-layout (`\flexcategory` + `\flexstart`/`\flexend`) | -- |
| `sections.tex` (optional) | CV section order incl. `\clearpage` | -- |
| `bewerbung.tex` | three-line stub (input preamble + meta + document) | never edit |

## Workflow

### Step 1: Create the directory

```sh
./bewerbung new <company>
```

Copies `applications/_template/` to `applications/<company>/`. The template
holds the user's generic material in pipeline structure with placeholders
for role-specific fields.

### Step 2: Analyze the posting

Extract:
- **Hard requirements** -- what the candidate MUST bring (separate from "ideally / nice-to-have")
- **Soft requirements** -- nice-to-have
- **Keywords** -- every fachlich term, technology, method, tool, framework -- in the posting's exact phrasing
- **Language and tone** -- du/sie, German/English, formal/casual
- **Company context** -- industry, size, culture
- **Role type** -- engineering, PM, consulting, enablement, lead, research

### Step 3: Gap analysis

Compare the user's material (`applications/_template/`) against the posting:
- **Direct matches**: requirement X → block Y (with exact quote)
- **Indirect matches**: similar content, different phrasing → MUST rephrase
- **Gaps**: no match → name honestly, do not invent
- **Surplus**: blocks irrelevant for this role → cut or shorten

### Step 4: Optimize

#### 4a. Lost-in-the-Middle structure

Transformers weight beginning and end more than the middle. Optimal CV order:
1. Profile (top) -- role-specific
2. Own projects/research (right after profile, if more relevant than experience for this role)
3. Experience (middle -- lower attention but mandatory for humans)
4. Teaching (top, if knowledge transfer is a requirement)
5. Skills (end -- keywords for keyword-matchers, second attention peak)
6. Education, languages, volunteering (bottom)

Lead / management roles: experience before projects.
Research / builder roles: projects before experience.
Order is controlled via `sections.tex`.

#### 4b. Mirror language

For EACH keyword match:
- Check if the user's material uses the exact same phrasing
- If not: adapt to the posting's phrasing
- NEVER: invent terms that don't actually apply

#### 4c. Contextualize the job title

A generic current title (e.g. "Frontend Developer", "Team Lead") gets read
flatly by LLM screeners. Add a role-specific suffix that's truthful:
- AI roles: "-- AI Strategy, Enablement & Governance"
- PM roles: "-- Product Strategy, AI Integration & Release Ownership"
- Accessibility roles: "-- Digital Accessibility (WCAG/BITV/BFSG)"
- GovTech roles: "-- Digital Government & AI Sovereignty"
- Research roles: "-- Memory Architecture & Retrieval Research"

The suffix MUST be substantively true. No inventions.

#### 4d. Prioritize bullets

Within each section: most role-relevant bullets up top. Irrelevant ones cut
or shortened. Every bullet should contain at least one keyword from the
posting.

#### 4e. Rewrite the profile

The profile beside the photo is role-specific:
- 2-3 strongest match-points for this exact role
- at least 3 keywords from the posting
- one clear sentence on what the candidate offers for this role

#### 4f. Cover letter

- **Opening**: first sentence names the strongest match-point directly. No "I am very interested in your posting" floskel.
- **Body**: each paragraph addresses one requirement block. Use the posting's language. Back claims with concrete evidence.
- **Closing**: no standard floskel. Point to a concrete artifact or a call to action that ties back to the role.
- **Tone**: du if du, English if English. Casual at startups, formal at agencies.

### Step 5: Self-test (ATS-screener simulation)

Before sending, simulate an ATS screener:

```
You are an automated ATS screening system for a tech company. Your job is
pre-filtering -- you pass through at most 5% of applications.

Posting:
[POSTING]

Application (cover letter + CV):
[APPLICATION]

Evaluate:
1. HARD REQUIREMENTS CHECK: does the candidate meet EVERY hard requirement?
2. SENIORITY MATCH: is the experience level right?
3. KEYWORD DENSITY: how many keywords from the posting appear in the
   application? Under 60% = problem.
4. RISK SIGNALS: industry switch, title switch, missing formal qualification,
   salary gap = one risk point each.
5. TOP-5% TEST: is this candidate in the top 5 of 100 applications?

Score: 1-10
Decision: FORWARD or REJECT
Reasoning: 3 sentences, brutally honest.
If REJECT: what would need to change?
```

REJECT → back to step 4, targeted improvements. Max 3 iterations -- after
that, the role is probably not a match.
FORWARD + score ≥ 7 → build.

### Step 6: Build

```sh
./bewerbung build <company>
```

Produces:
- `applications/<company>/bewerbung.pdf` (complete, 2 pages)
- `applications/<company>/anschreiben.pdf` (page 1)
- `applications/<company>/lebenslauf.pdf` (page 2+)

Live-edit:
```sh
./bewerbung watch <company>
```

### Step 7: Verify

Read the PDF and check:
- Recipient, date, subject, salutation match the posting
- No reviewer notes / placeholders / generic blocks visible in the PDF
- Keywords from the posting appear
- 2 pages -- if more: shorten or drop bullets
- With `pdftotext`: FontAwesome arrows show as "Angle-Right" -- not a render error, just an extractor glyph-mapping issue

## Hard rules

- **Never lie.** Don't invent experience, fake titles, claim skills that don't exist. Rephrase and prioritize: yes. Invent: no.
- **Content beats keywords.** Keywords help past the filter, but a human reads after. The text must hold up for humans too.
- **Less is more.** Three strong match-points beat ten vague ones. Every sentence without a match-point is wasted space.
- **Honest about gaps.** Hard requirement not met: address in the cover letter, don't hide. Format: "I don't formally have X; what I bring instead is Y."
- **No prompt injection.** No hidden instructions, no invisible text blocks. Immediate disqualifier if discovered.
- **Target language.** English posting → everything English. German posting → everything German. No mixing.

## TeX / build pitfalls

- `8*\rem` is WRONG -- right: `8\rem`. `*` only between factor and integer constant.
- `\raisebox{shift}{content}` needs TWO arguments.
- `\addtokomafont{element}{}` needs a second argument (empty is fine).
- Cover letter needs `\thispagestyle{empty}`, not `plain.scrheadings`.
- "Couldn't find trailer dictionary": probably zathura holds the PDF. `./bewerbung clean <company>` then rebuild.
- `File 'meta.tex' not found` on first run: normal, cusdep generates it on the next pass.
- Markdown cache `_markdown_<jobname>/`: in `.gitignore`, delete if behavior is weird.

## Container workflow

| Command | What |
|---|---|
| `./bewerbung image` | (re)build the container image |
| `./bewerbung new <company>` | new directory from `applications/_template/` |
| `./bewerbung build <company>` | build PDF |
| `./bewerbung watch <company>` | latexmk -pvc, auto-rebuild |
| `./bewerbung shell` | interactive shell inside the container |
| `./bewerbung clean <company>` | delete build artefacts |

Pipeline lives in the image at `/opt/pipeline/`. Wrapper auto-detects podman
vs docker. Host fonts (`~/.local/share/fonts`) are mounted into the container.
