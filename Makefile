.PHONY: validate lucid nothing

nothing:
	@echo "'make all' to build all binaries."
	@echo "'make source' to build only source package."
	@echo "'make test-repo' to put newly built debs into a test repo"
	@echo "'make clean-test-repo' to discard the temp test repo"


pkgs-for-building-pkgs:
	for PKG in debhelper git-buildpackage; do \
	  dpkg -l $$PKG | grep -q "^ii " || sudo apt-get -q -y install $$PKG; \
	done

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
endif

define KEYPARAMS
%echo Generating a standard key
Key-Type: DSA
Key-Length: 1024
Subkey-Type: ELG-E
Subkey-Length: 1024
Name-Real: vagrant
Name-Email: vagrant@devnull.com
Expire-Date: 0
%commit
%echo done
endef
export KEYPARAMS

keyparams:
	@echo "$$KEYPARAMS" > $${HOME}/keyparams

test-keys: keyparams
	@sudo dpkg -l rng-tools >/dev/null || sudo apt-get install rng-tools
	@grep -q "^HRNGDEVICE" /etc/default/rng-tools || \
		echo "HRNGDEVICE=/dev/urandom\nRNGDOPTIONS=\"-W 90% -t 1\"\n" | \
		sudo tee -a /etc/default/rng-tools
	@sudo /etc/init.d/rng-tools restart ||:
	@gpg --list-keys vagrant >/dev/null 2>&1  || \
		gpg --gen-key --batch $${HOME}/keyparams
	@export MYGPGKEY=vagrant

test-repo: test-keys
	debsign --re-sign -k$(MYGPGKEY) ../*.changes
	sudo dpkg -l reprepro >/dev/null || sudo apt-get install reprepro
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

