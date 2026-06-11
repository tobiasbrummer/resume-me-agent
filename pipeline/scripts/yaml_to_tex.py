#!/usr/bin/env python3
"""
Convert meta.yaml -> meta.tex (a set of \\def\\meta...{...} macros).

Reads YAML from stdin or first arg, writes TeX to stdout.

Hierarchy of values (later wins):
    1. HARDCODED_DEFAULTS (generic placeholders, defined below)
    2. $BEWERBUNG_REPO/user.yaml (the user's personal stammdaten -- name,
       address, phone, email, github. Recommended to live at the repo root.)
    3. The application's own meta.yaml (posting-specific overrides)

This way each user keeps name/address/phone/etc. in a single user.yaml they
edit once, and each application's meta.yaml only needs the recipient +
posting fields.
"""
from __future__ import annotations

import os
import sys
import yaml

# Generic placeholders. Override via $BEWERBUNG_REPO/user.yaml (your
# personal stammdaten) and per-application meta.yaml.
HARDCODED_DEFAULTS = {
    "name": "Max Mustermann",
    "adresse": "Musterstrasse 1",
    "plz_ort": "12345 Musterstadt",
    "tel": "+49 123 456789",
    "email": "you@example.com",
    "github": "github.com/yourname",
    "ort": "Musterstadt",
    "sprache": "de",
    "grussformel": "Mit freundlichen Grüßen",
    "empfaenger_name": "",
    "empfaenger_strasse": "",
    # Font defaults. "TeX Gyre Heros" is bundled with texlive-fonts-recommended
    # (always present in scheme-full), so the pipeline works out of the box.
    # Override `font_family` in user.yaml to use Fira Sans, Inter, IBM Plex,
    # etc. -- you need that font installed locally (the wrapper mounts your
    # host font directory into the container).
    "font_family":   "TeX Gyre Heros",
    "font_features": "Ligatures={Common,TeX},Kerning=On",
}

FOOTER_STRINGS = {
    "de": {"seite": "Seite", "von": "von"},
    "en": {"seite": "Page",  "von": "of"},
}


# TeX-special characters that need escaping. We do this minimally; the
# markdown package handles the body text. Here we only escape what could
# appear in metadata values like names, addresses, subjects.
def tex_escape(s: str) -> str:
    if s is None:
        return ""
    s = str(s)
    replacements = [
        ("\\", r"\textbackslash{}"),
        ("&",  r"\&"),
        ("%",  r"\%"),
        ("$",  r"\$"),
        ("#",  r"\#"),
        ("_",  r"\_"),
        ("{",  r"\{"),
        ("}",  r"\}"),
        ("~",  r"\textasciitilde{}"),
        ("^",  r"\textasciicircum{}"),
    ]
    for old, new in replacements:
        s = s.replace(old, new)
    return s


def write_def(out, name: str, value: str) -> None:
    out.write(f"\\def\\meta{name}{{{tex_escape(value)}}}\n")


def write_def_raw(out, name: str, value: str) -> None:
    """Like write_def but does not escape -- caller is responsible for valid TeX.
    Used for fontspec options (Ligatures={...}, etc.) where literal braces and
    commas are required TeX syntax."""
    out.write(f"\\def\\meta{name}{{{value}}}\n")


def tel_to_href(tel: str, country: str = "+49") -> str:
    """Display phone -> RFC3966 tel:-URL.
    '0123 456789' -> 'tel:+49123456789'
    '+49 123 456789' -> 'tel:+49123456789'
    """
    digits = "".join(c for c in tel if c.isdigit())
    if tel.lstrip().startswith("+"):
        e164 = "+" + digits
    elif digits.startswith("00"):
        e164 = "+" + digits[2:]
    elif digits.startswith("0"):
        e164 = country + digits[1:]
    elif digits.startswith(country.lstrip("+")):
        e164 = "+" + digits
    else:
        e164 = country + digits
    return "tel:" + e164


def load_user_yaml() -> dict:
    """Load $BEWERBUNG_REPO/user.yaml if present."""
    repo = os.environ.get("BEWERBUNG_REPO") or os.environ.get("JOB_REPO")
    if not repo:
        return {}
    path = os.path.join(repo, "user.yaml")
    if not os.path.exists(path):
        return {}
    with open(path) as f:
        return yaml.safe_load(f) or {}


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else None
    with open(src) if src else sys.stdin as f:
        meta = yaml.safe_load(f) or {}

    merged = {**HARDCODED_DEFAULTS, **load_user_yaml(), **meta}

    out = sys.stdout

    # Stammdaten
    write_def(out, "name",     merged["name"])
    write_def(out, "adresse",  merged["adresse"])
    write_def(out, "plzort",   merged["plz_ort"])
    write_def(out, "tel",      merged["tel"])
    write_def(out, "telhref",  merged.get("tel_href") or tel_to_href(merged["tel"]))
    write_def(out, "email",    merged["email"])
    write_def(out, "github",   merged["github"])
    write_def(out, "ort",      merged["ort"])

    # Empfaenger
    write_def(out, "empfaengerfirma",   merged.get("empfaenger_firma", ""))
    write_def(out, "empfaengername",    merged.get("empfaenger_name", ""))
    write_def(out, "empfaengerstrasse", merged.get("empfaenger_strasse", ""))
    write_def(out, "empfaengerplzort",  merged.get("empfaenger_plz_ort", ""))

    # Posting-spezifisch
    write_def(out, "betreff",     merged.get("betreff", ""))
    write_def(out, "betreffzusatz",     merged.get("betreff_zusatz", ""))
    write_def(out, "datum",       merged.get("datum", ""))
    write_def(out, "anrede",      merged.get("anrede", ""))
    write_def(out, "grussformel", merged.get("grussformel", "Mit freundlichen Grüßen"))

    # Anlagen-Hinweis (optional). Nur schreiben, wenn gesetzt -- sonst bleibt
    # \metaanlagen undefined und document.tex unterdrueckt den Block.
    if merged.get("anlagen"):
        write_def(out, "anlagen", merged["anlagen"])

    # Font configuration. font_family is mandatory (has a default). Each
    # weight defaults to "<family> <Weight>" -- a fontspec convention that
    # works for OpenType fonts with separately named weight files. If your
    # font uses different naming, override the individual fields.
    family   = merged["font_family"]
    regular  = merged.get("font_regular")  or f"{family} Regular"
    medium   = merged.get("font_medium")   or f"{family} Medium"
    semibold = merged.get("font_semibold") or f"{family} SemiBold"
    italic   = merged.get("font_italic")   or f"{family} Italic"
    write_def(out, "fontfamily",   family)
    write_def(out, "fontregular",  regular)
    write_def(out, "fontmediumname", medium)    # \metafontmedium is a font macro
    write_def(out, "fontsemiboldname", semibold)
    write_def(out, "fontitalicname",   italic)
    write_def_raw(out, "fontfeatures", merged["font_features"])

    # Sprache: ein Marker fuer babel-Wahl
    sprache = merged.get("sprache", "de")
    if sprache == "en":
        out.write("\\def\\metaspracheen{1}\n")
    else:
        out.write("\\def\\metasprachede{1}\n")

    # Footer-Strings (Seite X von Y)
    fs = FOOTER_STRINGS.get(sprache, FOOTER_STRINGS["de"])
    write_def(out, "seite", fs["seite"])
    write_def(out, "von",   fs["von"])


if __name__ == "__main__":
    main()
