build: slides.pdf 

slides.pdf : slides.md Makefile
	pandoc -t beamer --template=custom-template.tex -o slides.pdf slides.md
