# Makefile for Homa protocol RFC

LIBDIR := lib
-include $(LIBDIR)/main.mk

# Bootstrap rule: if lib/ is missing, fetch i-d-template (as a git
# submodule if one is configured, a symlink to $ID_TEMPLATE_HOME if
# that is set, or otherwise a fresh clone).
$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif

# Under Cygwin, xml2rfc can't write to /dev/stdout when it is a pipe,
# which breaks the template's markdown -> XML step. Route xml2rfc
# through a wrapper that uses a temporary file instead.
ifneq (,$(findstring CYGWIN,$(shell uname -s)))
xml2rfc := bash $(CURDIR)/cygwin-xml2rfc $(XML2RFC_OPTS)
endif

# The following target is useful for debugging Makefiles; it
# prints the value of a make variable.
print-%:
	@echo $* = $($*)
