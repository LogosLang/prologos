# Prologos Ott Specification — Build Targets
#
# Prerequisites:
#   - ott (https://github.com/ott-tool/ott)
#   - pdflatex (TeX Live or similar)
#
# Usage:
#   make              # generate LaTeX from .ott
#   make pdf          # generate PDF (requires pdflatex)
#   make clean        # remove generated files

OTT = ott
PDFLATEX = pdflatex

SOURCES = prologos.ott
TEX_OUT = prologos-generated.tex
WRAPPER = prologos-rules.tex
PDF_OUT = prologos-rules.pdf

.PHONY: all pdf clean

all: $(TEX_OUT)

$(TEX_OUT): $(SOURCES)
	$(OTT) -tex_wrap false -i $< -o $@

pdf: $(TEX_OUT) $(WRAPPER)
	$(PDFLATEX) $(WRAPPER)
	$(PDFLATEX) $(WRAPPER)

clean:
	rm -f $(TEX_OUT) $(PDF_OUT) *.aux *.log *.out
