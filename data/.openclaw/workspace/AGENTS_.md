# Agent Guide Corrections

The companion below records a proposed correction to the read-only
[AGENTS.md](AGENTS.md). It has not been applied to that file and is not
automatically loaded in its place. An operator must apply the replacement
manually, preserving any deployment-specific instructions.

## Describe preinstalled document tools and the persistent Python environment

### Old text (exactly)

```markdown
- Use `fd` instead of `fdfind`; the compatibility alias is already installed.
```

### Reason

The installed-tools list does not describe the image's PDF, multilingual OCR,
graphics, document-conversion, or email tools. Agents also need to use the
dedicated persistent Python environment instead of assuming these packages are
available in system Python or reinstalling them with `pip --user`.

### Recommended new text

````markdown
- Use `fd` instead of `fdfind`; the compatibility alias is already installed.
- PDF: Poppler (`pdftotext`, `pdftoppm`, `pdfinfo`, `pdfimages`), Ghostscript
  (`gs`), and `qpdf`.
- OCR: `tesseract` with English (`eng`), Russian (`rus`), and Thai (`tha`)
  language data; Noto fonts are installed for text rendering.
- Documents and graphics: `pandoc`, `rsvg-convert`, and `xxd`.
- Email: `msmtp` for SMTP submission and `mbsync` (isync) for IMAP
  synchronization. Both are installed but accounts are not preconfigured.

## PDF and OCR Workflow

- Inspect PDFs with `pdfinfo` and try `pdftotext -layout` first. For scans
  without a text layer, rasterize the required pages with `pdftoppm`, then
  use Tesseract. Tesseract accepts images, not PDF input.
- Use `pdfimages` to extract embedded images; use `pdftoppm` when you need
  the complete rendered page, including text and vector graphics.
- Use `qpdf --check` for structural diagnostics, `qpdf --linearize` to
  linearize, and Ghostscript for rendering or rewriting. Keep the original:
  rewriting can change document features and invalidate signatures.
- Run commands in a task-specific writable directory below home. Large PDF
  jobs can exceed the default 64 MiB `/tmp`; use a home-backed `TMPDIR`.
  Restrict page ranges and resolution to avoid unnecessary memory/disk use.

```bash
mkdir -p "$HOME/.cache/document-tools/tmp"
export TMPDIR="$HOME/.cache/document-tools/tmp"
pdfinfo input.pdf
pdftotext -layout input.pdf extracted.txt
pdftoppm -f 1 -l 1 -singlefile -r 150 -png input.pdf scan
tesseract scan.png stdout -l eng+rus+tha
pdfimages -png input.pdf embedded
qpdf --check input.pdf
qpdf --linearize input.pdf linearized.pdf
gs -dSAFER -dBATCH -dNOPAUSE -sDEVICE=pdfwrite \
  -sOutputFile=rewritten.pdf input.pdf
xxd -l 64 input.pdf
```

## Python Documents and Graphics

- Run `document-python script.py` to use the preinstalled libraries:
  PyMuPDF (`pymupdf`, also available through the legacy `fitz` import),
  `pdfplumber`, `pypdf`, Pillow (`PIL`), `python-docx` (`docx`),
  `openpyxl`, Beautiful Soup (`bs4`), and `lxml`.
- Prefer `import pymupdf` in new scripts; the `fitz` alias is deprecated.
- The launcher initializes and uses
  `~/.local/share/document-tools/venv`, a persistent symlink to an
  image-managed versioned environment. Dependencies are installed offline
  from pinned wheels in the read-only `/opt/document-tools` directory.
- Plain `python3` remains system Python. Do not assume it has these libraries
  and do not reinstall them with `pip --user`. For an interactive session,
  activate the document venv only after initialization with the launcher.
- Do not modify or delete the image-managed venv or its version directories.
  Request an image dependency update for permanent additions, or use a
  separate personal venv for experimental packages.
- Use PyMuPDF for PDF reading/rendering, `pdfplumber` for text/table extraction,
  and `pypdf` for page manipulation. Scanned tables still need OCR and review;
  extraction is not guaranteed to preserve complex layouts.
- Use Pandoc for supported document formats, `python-docx` for DOCX,
  `openpyxl` for XLSX, Beautiful Soup/lxml for HTML/XML, Pillow for raster
  graphics, and `rsvg-convert` for SVG. Pandoc does not read arbitrary PDFs;
  LibreOffice and OCRmyPDF are not included.

```bash
document-python -c 'import pymupdf, pdfplumber, pypdf, PIL, docx, openpyxl, bs4, lxml'
document-python your_script.py
source ~/.local/share/document-tools/venv/bin/activate
pandoc input.docx -t markdown -o converted.md
rsvg-convert input.svg -o rendered.png
document-python /opt/document-tools/test-document-tools.py
```

## Email Tools

- `msmtp --version` and `mbsync --version` verify availability without
  sending mail or accessing a mailbox.
- Configure only user-authorized accounts, with TLS and the provider's
  supported authentication. OAuth2 providers may need a separate token
  helper; no account credentials or helper are bundled.
- Keep mail configuration and credentials private in the persistent home,
  never in the image, Git, logs, or chat output.
- Sending email and synchronizing mailboxes require explicit user
  authorization for the account and action. Do not infer permission from
  the presence of a client or configuration.
````
