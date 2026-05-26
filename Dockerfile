# resume-me-agent
#
# Carries the LaTeX pipeline and the init bundle. Users mount their repo at
# /job and call `latexmk -r /opt/pipeline/.latexmkrc applications/<x>/bewerbung.tex`
# via the wrapper.
#
# Build:   docker build -t resume-me-agent .
# Pull:    docker pull ghcr.io/tobiasbrummer/resume-me-agent:latest
#
# Fira Sans is NOT baked in. The wrapper mounts the host's
# ~/.local/share/fonts on /usr/local/share/fonts/host and entrypoint.sh
# refreshes fc-cache on container start.

FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# texlive-full = scheme-full (without language packs) -- we add German and
# English explicitly. Plus python3-yaml for yaml_to_tex.py, poppler-utils for
# split-pdf.sh, fontconfig so host-mounted fonts are picked up.
RUN apt-get update && apt-get install -y --no-install-recommends \
        texlive-full \
        latexmk \
        python3 \
        python3-yaml \
        poppler-utils \
        fontconfig \
        locales \
        ca-certificates \
    && sed -i '/^# *en_US.UTF-8/s/^# *//' /etc/locale.gen \
    && sed -i '/^# *de_DE.UTF-8/s/^# *//' /etc/locale.gen \
    && locale-gen \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Pipeline (templates, scripts, .latexmkrc) -- consumed by latexmk during build.
COPY pipeline/ /opt/pipeline/

# Init bundle -- extracted by setup.sh into the user's repo on first run.
# Includes the bewerbung wrapper itself.
COPY init/ /opt/init/
COPY bin/bewerbung /opt/init/bewerbung
RUN chmod +x /opt/init/bewerbung /opt/pipeline/scripts/split-pdf.sh

# Mount-point for the user's repo. WORKDIR is /job so latexmk-on-relative-path
# works (`latexmk applications/<x>/bewerbung.tex`).
WORKDIR /job

# Entry-wrapper: refresh fc-cache if host fonts are mounted, then exec.
# `exec "$@"` so signals (Ctrl-C on latexmk -pvc) pass through cleanly.
COPY <<'EOF' /usr/local/bin/entrypoint.sh
#!/bin/sh
set -e
if [ -d /usr/local/share/fonts/host ]; then
    fc-cache -f >/dev/null 2>&1 || true
fi
exec "$@"
EOF
RUN chmod +x /usr/local/bin/entrypoint.sh

# Image metadata for GHCR
LABEL org.opencontainers.image.title="resume-me-agent" \
      org.opencontainers.image.description="LaTeX pipeline for agent-driven job applications" \
      org.opencontainers.image.source="https://github.com/tobiasbrummer/resume-me-agent" \
      org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]
