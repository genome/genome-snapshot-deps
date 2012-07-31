.PHONY: validate lucid nothing

nothing:
	@echo "'make <DISTRO>' to re-generate the debian directory"

purge:
	rm -f ../genome-snapshot-deps*.changes ../genome-snapshot-deps*.deb
	rm -rf debian

debian: validate
	rsync -av --delete common/ debian/
	cp -a $(DISTRO)/compat debian/
	cp -a $(DISTRO)/changelog debian/
	bin/build-control $(DISTRO) > debian/control
	dpkg-buildpackage $(BUILD_FLAGS)

lucid-source:
	$(MAKE) debian DISTRO=lucid BUILD_FLAGS='-uc -us -S'

lucid:
	$(MAKE) debian DISTRO=lucid BUILD_FLAGS='uc -A'

all:
	$(MAKE) lucid

validate:
ifndef DISTRO
	@echo "Must specify DISTRO argument, e.g. DISTRO=lucid"
	@exit 1
endif
