# latexmk config for resume-me-agent.
#
# Loaded via `latexmk -r /opt/pipeline/.latexmkrc <app>/bewerbung.tex` from
# the wrapper. The pipeline-root is derived from this file's location, so
# the same .latexmkrc works both inside the container (at /opt/pipeline/) and
# in a local fallback install.
#
# Build a single application from the user repo's root:
#     latexmk applications/firma-xy/bewerbung.tex
# Live-edit with auto-rebuild and PDF auto-reload:
#     latexmk -pvc applications/firma-xy/bewerbung.tex

use File::Basename;

$pdf_mode = 4;                 # 4 = lualatex
$lualatex = 'lualatex -interaction=nonstopmode -synctex=1 -shell-escape %O %S';

# Compile inside the application's directory so relative paths in the master
# template resolve (\markdownInput{anschreiben.md}, meta.tex, ...).
$do_cd = 1;

# PDF-Viewer for live-reload via latexmk -pvc. Only used outside the container;
# the wrapper passes -view=none inside.
$pdf_previewer = 'zathura %S &';

# Pipeline-root: directory of this .latexmkrc. Lets scripts/yaml_to_tex.py
# and scripts/split-pdf.sh resolve regardless of where the pipeline lives.
our $PIPELINE_ROOT = $ENV{'PIPELINE_ROOT'} // dirname(__FILE__);

# User-repo root: where applications/ lives. Frozen before $do_cd jumps into
# the application directory, so yaml_to_tex.py can find user.yaml etc.
our $JOB_REPO = $ENV{'JOB_REPO'} // $ENV{'PWD'};

# --- custom dep: meta.yaml -> meta.tex via yaml_to_tex.py -------------------
add_cus_dep('yaml', 'tex', 0, 'yaml_to_meta_tex');
sub yaml_to_meta_tex {
    my ($base) = @_;
    return system("BEWERBUNG_REPO=\"$JOB_REPO\" python3 \"$PIPELINE_ROOT/scripts/yaml_to_tex.py\" \"$base.yaml\" > \"$base.tex\"");
}

# --- Post-Build: bewerbung.pdf -> anschreiben.pdf (page 1) + lebenslauf.pdf
# --- (pages 2..) via poppler-utils.
$success_cmd = "sh $PIPELINE_ROOT/scripts/split-pdf.sh";
