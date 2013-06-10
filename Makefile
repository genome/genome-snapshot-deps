.PHONY: validate lucid nothing

nothing:
	@echo "'make all' to build all binaries."
	@echo "'make source' to build only source package."

pkgs-for-building-pkgs:
	(dpkg -l debhelper git-buildpackage >/dev/null) || sudo apt-get -q -y install debhelper git-buildpackage

source: pkgs-for-building-pkgs
	$(MAKE) debian BUILD_FLAGS='-uc -us -S'

all: pkgs-for-building-pkgs
	$(MAKE) debian BUILD_FLAGS='-uc -A'

purge:
	rm -f ../genome-snapshot-deps*.changes ../genome-snapshot-deps*.deb
	rm -rf debian

debian: validate
	rsync -av --delete common/ debian/
	cp -a $(DISTRO)/compat debian/
	cp -a $(DISTRO)/changelog debian/
	bin/build-control $(DISTRO) > debian/control
	dpkg-buildpackage $(BUILD_FLAGS)

validate:
ifndef DISTRO
DISTRO:=$(shell lsb_release -sc)
endif
ifndef DISTRO
	@echo "Must specify DISTRO argument, e.g. DISTRO=lucid"
	@exit 1
endif
