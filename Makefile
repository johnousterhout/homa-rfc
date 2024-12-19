# Makefile for Homa protocol RFC

SRC = draft-ousterhout-tsvwg-homa-00.md

all: homa-rfc.txt homa-rfc.html

homa-rfc.xml: $(SRC)
	kramdown-rfc $(SRC) > homa-rfc.xml

homa-rfc.txt: homa-rfc.xml
	xml2rfc --text -o homa-rfc.txt homa-rfc.xml

homa-rfc.html: homa-rfc.xml
	xml2rfc --html -o homa-rfc.html homa-rfc.xml

clean:
	rm homa-rfc.xml homa-rfc.txt

# The following target is useful for debugging Makefiles; it
# prints the value of a make variable.
print-%:
	@echo $* = $($*)
