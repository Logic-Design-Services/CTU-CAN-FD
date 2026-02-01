all: Progdokum ctu_can_fd_architecture tb_architecture

Progdokum: version.tex
	lyx --export-to pdf2 $@.pdf $@.lyx

ctu_can_fd_architecture: version.tex
	lyx --export-to pdf2 $@.pdf $@.lyx

tb_architecture: version.tex
	lyx --export-to pdf2 $@.pdf $@.lyx

version.tex: FORCE
	desc=$$(git describe --always --tags); \
	date="$$(git show -s --format=%cd --date=format:%Y-%m-%d)"; \
	echo "$$desc, $$date" >$@

clean:
	-rm -f *.aux *.toc *.out *.log *.tex *.texe *.pdf

FORCE:

.PHONY: all clean
