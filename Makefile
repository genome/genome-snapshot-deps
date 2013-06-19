.PHONY: validate lucid nothing

nothing:
	@echo "'make all' to build all binaries."
	@echo "'make source' to build only source package."
	@echo "'make test-repo' to put newly built debs into a test repo"
	@echo "'make clean-test-repo' to discard the temp test repo"


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
	dpkg-buildpackage $(BUILD_FLAGS) --changes-option='-DDistribution=$(REPO)'

validate:
ifndef DISTRO
DISTRO:=$(shell lsb_release -sc)
endif
ifndef DISTRO
	@echo "Must specify DISTRO argument, e.g. DISTRO=lucid"
	@exit 1
endif
ifndef REPO
REPO:=$(DISTRO)-genome-development
	@echo "Assuming target repository is $(REPO)."
endif

test-repo:
	debsign -k$(MYGPGKEY) ../*.changes
	sudo apt-get install reprepro
	[ test-repos/local_$(DISTRO)/ubuntu/conf ] || mkdir -p test-repos/local_$(DISTRO)/ubuntu/conf/
	cd test-repos/local_$(DISTRO)/ubuntu/conf/
	mkdir test-repos/local_$(DISTRO)/ubuntu/incoming/ || true
	cp ../*.deb ../*.changes test-repos/local_$(DISTRO)/ubuntu/incoming/
	reprepro -v -V -b test-repos/local_$(DISTRO)/ubuntu/ processincoming $(DISTRO)_genome_development
	reprepro -b test-repos/local_$(DISTRO)/ubuntu/ export
	sudo cp test-repos/etc+apt+preferences.d+local.pref /etc/apt/preferences.d/local.pref
	sudo bash -c "cat test-repos/etc+apt+sources.list.d+local.list | perl -ne 's|PWD|$(PWD)|g; s|DISTRO|$(DISTRO)|g; print' >| /etc/apt/sources.list.d/local.list"
	sudo apt-get update || true
	reprepro -v -V -b test-repos/local_$(DISTRO)/ubuntu/ processincoming $(DISTRO)_genome_development
	sudo cp test-repos/etc+apt+preferences.d+local.pref /etc/apt/preferences.d/local.pref
	sudo bash -c "cat test-repos/etc+apt+sources.list.d+local.list | perl -ne 's|PWD|$(PWD)|g; s|DISTRO|$(DISTRO)|g; print' >| /etc/apt/sources.list.d/local.list"
	sudo apt-get update || true
	#
	# now run this, and recurse through failures:
	#   sudo apt-get install genome-snapshot-deps
	#
	# when done, or to re-try:
	#   make clean-test-repo
	#
	
clean-test-repo:
	rm -rf test-repos/local_lucid/ubuntu/db/
	rm -rf test-repos/local_lucid/ubuntu/dists/
	rm -rf test-repos/local_lucid/ubuntu/pool/
	rm -rf test-repos/local_precise/ubuntu/db/
	rm -rf test-repos/local_precise/ubuntu/dists/
	rm -rf test-repos/local_precise/ubuntu/pool/
	sudo rm -f /etc/apt/preferences.d/local.pref
	sudo rm -f /etc/apt/sources.list.d/local.list

