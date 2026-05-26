#!/bin/sh
# Split bewerbung.pdf into anschreiben.pdf (page 1) and lebenslauf.pdf (page 2+).
# Aufgerufen aus .latexmkrc als $success_cmd, cwd ist das Application-Verzeichnis.
# Braucht poppler-utils (pdfseparate, pdfinfo, pdfunite).
set -e

PDF=bewerbung.pdf
[ -e "$PDF" ] || { echo "split-pdf: $PDF not found, skipping" >&2; exit 0; }

N=$(pdfinfo "$PDF" 2>/dev/null | awk '/^Pages:/{print $2}')
[ -z "$N" ] && { echo "split-pdf: could not read page count, skipping" >&2; exit 0; }

# Seite 1 -> Anschreiben
pdfseparate -f 1 -l 1 "$PDF" anschreiben.pdf

# Seite 2 bis Ende -> Lebenslauf (falls > 1 Seite gesamt)
if [ "$N" -gt 1 ]; then
    pdfseparate -f 2 -l "$N" "$PDF" cv-tmp-%d.pdf
    pdfunite cv-tmp-*.pdf lebenslauf.pdf 2>/dev/null
    rm -f cv-tmp-*.pdf
else
    rm -f lebenslauf.pdf
fi

echo "split-pdf: anschreiben.pdf (1 page), lebenslauf.pdf ($((N - 1)) pages)"
