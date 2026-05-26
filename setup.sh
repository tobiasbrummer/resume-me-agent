#!/usr/bin/env bash
# resume-me-agent setup.
#
# Run from a freshly cloned resume-me-agent repository OR from any directory
# you want to bootstrap as your applications repo. Pulls the Docker image,
# extracts /opt/init/ here, picks an agent instruction format, and (by
# default) cleans up the resume-me-agent source files so what remains is
# your applications repo.
#
# Interactive:
#   ./setup.sh
# Non-interactive (good for agents):
#   ./setup.sh --non-interactive --agent=claude    # or codex|both|none
#
# Other flags:
#   --target=<path>       where to set up (default: $PWD)
#   --image-tag=<tag>     override image (default: ghcr.io/tobiasbrummer/resume-me-agent:latest)
#   --keep-source         don't delete Dockerfile, pipeline/, bin/, .github/, setup.sh
#   --keep-git            don't reset .git
#   --force               overwrite existing files without .bak backup

set -euo pipefail

# --- defaults --------------------------------------------------------------
IMAGE="ghcr.io/tobiasbrummer/resume-me-agent:latest"
TARGET="$PWD"
INTERACTIVE=1
AGENT=""
KEEP_SOURCE=0
KEEP_GIT=0
FORCE=0

# --- parse flags -----------------------------------------------------------
while [ "$#" -gt 0 ]; do
    case "$1" in
        --non-interactive)   INTERACTIVE=0 ;;
        --agent=*)           AGENT="${1#*=}" ;;
        --target=*)          TARGET="${1#*=}" ;;
        --image-tag=*)       IMAGE="${1#*=}" ;;
        --keep-source)       KEEP_SOURCE=1 ;;
        --keep-git)          KEEP_GIT=1 ;;
        --force)             FORCE=1 ;;
        -h|--help)
            sed -n '4,21p' "$0" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *) echo "unknown flag: $1" >&2; exit 1 ;;
    esac
    shift
done

# --- helpers ---------------------------------------------------------------
die()  { echo "ERROR: $*" >&2; exit 1; }
info() { echo ">> $*"; }
ask()  {
    # ask <prompt> <default> -> echoes answer
    local prompt="$1" default="$2" answer=""
    if [ "$INTERACTIVE" = "0" ]; then
        echo "$default"
        return
    fi
    read -r -p "$prompt [$default] " answer </dev/tty || true
    echo "${answer:-$default}"
}
yesno() {
    # yesno <prompt> <default y|n>
    local a
    a="$(ask "$1 (y/n)" "$2")"
    case "$a" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
}

# Container-engine selection
ENGINE=""
pick_engine() {
    if [ -n "${BEWERBUNG_ENGINE:-}" ]; then
        ENGINE="$BEWERBUNG_ENGINE"
    elif command -v podman >/dev/null 2>&1; then
        ENGINE="podman"
    elif command -v docker >/dev/null 2>&1; then
        ENGINE="docker"
    else
        die "neither podman nor docker found. Install one and rerun."
    fi
    info "using container engine: $ENGINE"
}

# Copy a file from the container's /opt/init/ to target, backing up conflicts.
extract_path() {
    local src="$1" dst_rel="$2"
    local dst="$TARGET/$dst_rel"
    mkdir -p "$(dirname "$dst")"
    if [ -e "$dst" ] && [ "$FORCE" = "0" ]; then
        info "  exists, backing up: $dst_rel -> $dst_rel.bak"
        mv "$dst" "$dst.bak"
    fi
    "$ENGINE" cp "$CONTAINER_ID:$src" "$dst"
}

# Like extract_path, but skip if the destination already exists. Used for
# user-editable pipeline templates -- preserves customizations on re-run.
extract_path_if_missing() {
    local src="$1" dst_rel="$2"
    local dst="$TARGET/$dst_rel"
    if [ -e "$dst" ] && [ "$FORCE" = "0" ]; then
        info "  exists, keeping local edits: $dst_rel"
        return
    fi
    [ -e "$dst" ] && rm -rf "$dst"
    mkdir -p "$(dirname "$dst")"
    "$ENGINE" cp "$CONTAINER_ID:$src" "$dst"
}

# --- main ------------------------------------------------------------------
[ -d "$TARGET" ] || die "target directory does not exist: $TARGET"
cd "$TARGET"
info "target: $TARGET"
info "image:  $IMAGE"

pick_engine

# Pull image if missing
if ! "$ENGINE" image inspect "$IMAGE" >/dev/null 2>&1; then
    info "pulling image (this will take a while on first run, ~5 GB)..."
    "$ENGINE" pull "$IMAGE"
fi

# Create a one-shot container so we can `docker cp` from it
info "extracting init bundle..."
CONTAINER_ID="$($ENGINE create "$IMAGE")"
trap '$ENGINE rm "$CONTAINER_ID" >/dev/null 2>&1 || true' EXIT

# Files / dirs to extract from /opt/init/ into target
extract_path /opt/init/applications/_template applications/_template
extract_path /opt/init/assets/portrait.jpg    assets/portrait.jpg
extract_path /opt/init/assets/signatur.png    assets/signatur.png
extract_path /opt/init/.claude/skills/bewerbung.md .claude/skills/bewerbung.md
extract_path /opt/init/user.yaml.template     user.yaml.template
extract_path /opt/init/CLAUDE.md.template     .resume-me-tmp/CLAUDE.md.template
extract_path /opt/init/AGENTS.md.template     .resume-me-tmp/AGENTS.md.template
extract_path /opt/init/README.md.template     .resume-me-tmp/README.md.template
extract_path /opt/init/.gitignore.template    .resume-me-tmp/.gitignore.template
extract_path /opt/init/bewerbung              bewerbung
chmod +x "$TARGET/bewerbung"

# --- pick agent ------------------------------------------------------------
if [ -z "$AGENT" ]; then
    if [ "$INTERACTIVE" = "1" ]; then
        echo
        echo "Which coding agent will you use?"
        echo "  1) claude  -- Claude Code (writes CLAUDE.md + .claude/skills/)"
        echo "  2) codex   -- OpenAI Codex (writes AGENTS.md)"
        echo "  3) both    -- both files (the .claude/ skill is already extracted either way)"
        echo "  4) none    -- skip agent-specific files"
        a="$(ask "choice 1/2/3/4" "1")"
        case "$a" in
            1) AGENT="claude" ;;
            2) AGENT="codex" ;;
            3) AGENT="both" ;;
            4) AGENT="none" ;;
            *) die "invalid choice: $a" ;;
        esac
    else
        AGENT="claude"
    fi
fi
info "agent: $AGENT"

# Materialize agent files
case "$AGENT" in
    claude)
        mv "$TARGET/.resume-me-tmp/CLAUDE.md.template" "$TARGET/CLAUDE.md"
        AGENT_INSTRUCTIONS_FILE="CLAUDE.md and .claude/skills/bewerbung.md"
        ;;
    codex)
        mv "$TARGET/.resume-me-tmp/AGENTS.md.template" "$TARGET/AGENTS.md"
        AGENT_INSTRUCTIONS_FILE="AGENTS.md"
        # codex doesn't read .claude/skills/, so drop that dir
        rm -rf "$TARGET/.claude"
        ;;
    both)
        mv "$TARGET/.resume-me-tmp/CLAUDE.md.template" "$TARGET/CLAUDE.md"
        mv "$TARGET/.resume-me-tmp/AGENTS.md.template" "$TARGET/AGENTS.md"
        AGENT_INSTRUCTIONS_FILE="CLAUDE.md, AGENTS.md, .claude/skills/bewerbung.md"
        ;;
    none)
        rm -rf "$TARGET/.claude"
        AGENT_INSTRUCTIONS_FILE=""
        ;;
    *) die "unknown agent: $AGENT (use claude|codex|both|none)" ;;
esac

# README.md template substitution
if [ -f "$TARGET/.resume-me-tmp/README.md.template" ]; then
    sed "s|AGENT_INSTRUCTIONS_FILE|${AGENT_INSTRUCTIONS_FILE:-the agent-instructions file (skipped)}|g" \
        "$TARGET/.resume-me-tmp/README.md.template" > "$TARGET/README.md.new"
    if [ -e "$TARGET/README.md" ] && [ "$FORCE" = "0" ]; then
        mv "$TARGET/README.md" "$TARGET/README.md.bak"
    fi
    mv "$TARGET/README.md.new" "$TARGET/README.md"
fi

# .gitignore
if [ -f "$TARGET/.resume-me-tmp/.gitignore.template" ]; then
    if [ -e "$TARGET/.gitignore" ] && [ "$FORCE" = "0" ]; then
        mv "$TARGET/.gitignore" "$TARGET/.gitignore.bak"
    fi
    mv "$TARGET/.resume-me-tmp/.gitignore.template" "$TARGET/.gitignore"
fi

rm -rf "$TARGET/.resume-me-tmp"

# --- cleanup source files --------------------------------------------------
if [ "$KEEP_SOURCE" = "0" ]; then
    if yesno "Remove resume-me-agent source files (Dockerfile, pipeline/, bin/, .github/, setup.sh, LICENSE)?" "y"; then
        rm -rf \
            "$TARGET/Dockerfile" \
            "$TARGET/pipeline" \
            "$TARGET/bin" \
            "$TARGET/.github" \
            "$TARGET/setup.sh" \
            "$TARGET/LICENSE" \
            "$TARGET/init" 2>/dev/null || true
        info "source files removed"
    fi
fi

# --- extract user-editable pipeline templates ------------------------------
# Placed AFTER source cleanup so a "yes" to the cleanup prompt above doesn't
# wipe these. Pipeline scripts and .latexmkrc stay in the image (build logic),
# only the templates land in the repo so the user (or their coding agent) can
# tweak the layout. TEXINPUTS in `bewerbung` prefers /job/pipeline/templates/
# over the image fallback, so local edits win automatically.
info "extracting layout templates (pipeline/templates/) ..."
extract_path_if_missing /opt/pipeline/templates pipeline/templates

# --- reset git --------------------------------------------------------------
if [ "$KEEP_GIT" = "0" ] && [ -d "$TARGET/.git" ]; then
    if yesno "Reset git history? (recommended for a fresh repo with your remote)" "y"; then
        rm -rf "$TARGET/.git"
        ( cd "$TARGET" && git init -q -b main && info "fresh git repo initialized" )
    fi
fi

# --- next steps -------------------------------------------------------------
echo
echo "Setup complete."
echo
echo "Next steps:"
echo "  1) Copy user.yaml.template to user.yaml and edit your stammdaten:"
echo "       cp user.yaml.template user.yaml && \$EDITOR user.yaml"
echo "  2) Replace assets/portrait.jpg and assets/signatur.png with your real ones."
echo "  3) Customize applications/_template/ with your generic experience/projects/skills."
echo "  4) Create your first application:"
echo "       ./bewerbung new <company>"
echo "  5) Edit applications/<company>/{meta.yaml,profil.md,anschreiben.md,…} and build:"
echo "       ./bewerbung build <company>"
echo
[ -n "$AGENT_INSTRUCTIONS_FILE" ] && \
    echo "Your coding agent should read: $AGENT_INSTRUCTIONS_FILE"
