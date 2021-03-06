# MAKEFILE
#
# @author      Nicola Asuni <nicola.asuni@miracl.com>
# @link        https://github.com/miracl/natsping
#
# This file is intended to be executed in a Linux-compatible system.
# It also assumes that the project has been cloned in the right path under GOPATH:
# $GOPATH/src/github.com/miracl/natsping
#
# ------------------------------------------------------------------------------

# List special make targets that are not associated with files
.PHONY: help all test format fmtcheck vet lint coverage cyclo ineffassign misspell astscan qa deps install uninstall clean nuke build rpm deb bz2 docker dockertest buildall dbuild

# Use bash as shell (Note: Ubuntu now uses dash which doesn't support PIPESTATUS).
SHELL=/bin/bash

# CVS path (path to the parent dir containing the project)
CVSPATH=stash.certivox.com/scm/maas

# Project owner
OWNER=MIRACL

# Project vendor
VENDOR=miracl

# Project name
PROJECT=natsping

# Project version
VERSION=$(shell cat VERSION)

# Project release number (packaging build number)
RELEASE=$(shell cat RELEASE)

# Name of RPM or DEB package
PKGNAME=${VENDOR}-${PROJECT}

# Current directory
CURRENTDIR=$(shell pwd)

# GO lang path
ifneq ($(GOPATH),)
	ifeq ($(findstring $(GOPATH),$(CURRENTDIR)),)
		# the defined GOPATH is not valid
		GOPATH=
	endif
endif
ifeq ($(GOPATH),)
	# extract the GOPATH
	GOPATH=$(firstword $(subst /src/, ,$(CURRENTDIR)))
endif

# Add the GO binary dir in the PATH
export PATH := ${GOPATH}/bin:$(PATH)

# Path for binary files (where the executable files will be installed)
BINPATH=usr/bin/

# Path for configuration files
CONFIGPATH=etc/$(PROJECT)/

# Path for init script
#INITPATH=etc/init.d/

# Path path for documentation
DOCPATH=usr/share/doc/$(PKGNAME)/

# Path path for man pages
MANPATH=usr/share/man/man1/

# Installation path for the binary files
PATHINSTBIN=$(DESTDIR)/$(BINPATH)

# Installation path for the configuration files
PATHINSTCFG=$(DESTDIR)/$(CONFIGPATH)

# Installation path for the init file
PATHINSTINIT=$(DESTDIR)/$(INITPATH)

# Installation path for documentation
PATHINSTDOC=$(DESTDIR)/$(DOCPATH)

# Installation path for man pages
PATHINSTMAN=$(DESTDIR)/$(MANPATH)

# RPM Packaging path (where RPMs will be stored)
PATHRPMPKG=$(CURRENTDIR)/target/RPM

# DEB Packaging path (where DEBs will be stored)
PATHDEBPKG=$(CURRENTDIR)/target/DEB

# BZ2 Packaging path (where BZ2s will be stored)
PATHBZ2PKG=$(CURRENTDIR)/target/BZ2

# DOCKER Packaging path (where BZ2s will be stored)
PATHDOCKERPKG=$(CURRENTDIR)/target/DOCKER

# Cross compilation targets
CCTARGETS=darwin/386 darwin/amd64 freebsd/386 freebsd/amd64 freebsd/arm linux/386 linux/amd64 linux/arm openbsd/386 openbsd/amd64 windows/386 windows/amd64

# docker image name for consul (used during testing)
CONSUL_DOCKER_IMAGE_NAME=consul_$(VENDOR)_$(PROJECT)$(DOCKERSUFFIX)

# docker image name for NATS (used during testing)
NATS_DOCKER_IMAGE_NAME=nats_$(VENDOR)_$(PROJECT)$(DOCKERSUFFIX)


# --- MAKE TARGETS ---

# Display general help about this command
help:
	@echo ""
	@echo "$(PROJECT) Makefile."
	@echo "GOPATH=$(GOPATH)"
	@echo "The following commands are available:"
	@echo ""
	@echo "    make qa          : Run all the tests"
	@echo "    make test        : Run the unit tests"
	@echo ""
	@echo "    make format      : Format the source code"
	@echo "    make fmtcheck    : Check if the source code has been formatted"
	@echo "    make vet         : Check for syntax errors"
	@echo "    make lint        : Check for style errors"
	@echo "    make coverage    : Generate the coverage report"
	@echo "    make cyclo       : Generate the cyclomatic complexity report"
	@echo "    make ineffassign : Detect ineffectual assignments"
	@echo "    make misspell    : Detect commonly misspelled words in source files"
	@echo "    make astscan     : GO AST scanner"
	@echo ""
	@echo "    make docs        : Generate source code documentation"
	@echo ""
	@echo "    make deps        : Get the dependencies"
	@echo "    make build       : Compile the application"
	@echo "    make clean       : Remove any build artifact"
	@echo "    make nuke        : Deletes any intermediate file"
	@echo "    make install     : Install this application"
	@echo ""
	@echo "    make rpm         : Build an RPM package"
	@echo "    make deb         : Build a DEB package"
	@echo "    make bz2         : Build a tar bz2 (tbz2) compressed archive"
	@echo "    make docker      : Build a docker container to run this service"
	@echo "    make dockertest  : Test the newly built docker container"
	@echo ""
	@echo "    make buildall    : full build and test sequence"
	@echo "    make dbuild      : build everything inside a Docker container"
	@echo ""

# Alias for help target
all: help

# Run the unit tests (also run the NATS server)
test:
	@mkdir -p target/test
	@mkdir -p target/report
	nohup gnatsd --debug --trace > target/nats.log 2>&1 & echo $$! > target/nats.pid
	GOPATH=$(GOPATH) go test -covermode=count -coverprofile=target/report/coverage.out -bench=. -race -v ./src | \
	tee >(PATH=$(GOPATH)/bin:$(PATH) go-junit-report > target/test/report.xml); \
	test $${PIPESTATUS[0]} -eq 0 ; \
	echo $$? > target/test.exit; \
	kill -9 `cat target/nats.pid` ; \
	exit `cat target/test.exit`

# Format the source code
format:
	@find ./src -type f -name "*.go" -exec gofmt -s -w {} \;

# Check if the source code has been formatted
fmtcheck:
	@mkdir -p target
	@find ./src -type f -name "*.go" -exec gofmt -s -d {} \; | tee target/format.diff
	@test ! -s target/format.diff || { echo "ERROR: the source code has not been formatted - please use 'make format' or 'gofmt'"; exit 1; }

# Check for syntax errors
vet:
	GOPATH=$(GOPATH) go vet ./src

# Check for style errors
lint:
	GOPATH=$(GOPATH) PATH=$(GOPATH)/bin:$(PATH) golint ./src

# Generate the coverage report
coverage:
	@mkdir -p target/report
	GOPATH=$(GOPATH) go tool cover -html=target/report/coverage.out -o target/report/coverage.html

# Report cyclomatic complexity
cyclo:
	@mkdir -p target/report
	GOPATH=$(GOPATH) gocyclo -avg ./src | tee target/report/cyclo.txt ; test $${PIPESTATUS[0]} -eq 0

# Detect ineffectual assignments
ineffassign:
	@mkdir -p target/report
	GOPATH=$(GOPATH) ineffassign ./src | tee target/report/ineffassign.txt ; test $${PIPESTATUS[0]} -eq 0

# Detect commonly misspelled words in source files
misspell:
	@mkdir -p target/report
	GOPATH=$(GOPATH) misspell -error ./src  | tee target/report/misspell.txt ; test $${PIPESTATUS[0]} -eq 0

# AST scanner
astscan:
	@mkdir -p target/report
	GOPATH=$(GOPATH) gas ./src/*.go | tee target/report/astscan.txt ; test $${PIPESTATUS[0]} -eq 0

# Generate source docs
docs:
	@mkdir -p target/docs
	nohup sh -c 'GOPATH=$(GOPATH) godoc -http=127.0.0.1:6060' > target/godoc_server.log 2>&1 &
	wget --directory-prefix=target/docs/ --execute robots=off --retry-connrefused --recursive --no-parent --adjust-extension --page-requisites --convert-links http://127.0.0.1:6060/pkg/github.com/${VENDOR}/${PROJECT}/ ; kill -9 `lsof -ti :6060`
	@echo '<html><head><meta http-equiv="refresh" content="0;./127.0.0.1:6060/pkg/'${CVSPATH}'/'${PROJECT}'/index.html"/></head><a href="./127.0.0.1:6060/pkg/'${CVSPATH}'/'${PROJECT}'/index.html">'${PKGNAME}' Documentation ...</a></html>' > target/docs/index.html

# Alias to run targets: fmtcheck test vet lint coverage
qa: fmtcheck test vet lint coverage cyclo ineffassign misspell astscan

# --- INSTALL ---

# Get the dependencies
deps:
	GOPATH=$(GOPATH) go get -v ./...
	GOPATH=$(GOPATH) go get github.com/golang/lint/golint
	GOPATH=$(GOPATH) go get github.com/jstemmer/go-junit-report
	GOPATH=$(GOPATH) go get github.com/axw/gocov/gocov
	GOPATH=$(GOPATH) go get github.com/fzipp/gocyclo
	GOPATH=$(GOPATH) go get github.com/gordonklaus/ineffassign
	GOPATH=$(GOPATH) go get github.com/client9/misspell/cmd/misspell
	GOPATH=$(GOPATH) go get github.com/inconshreveable/mousetrap
	GOPATH=$(GOPATH) go get github.com/nats-io/gnatsd
	GOPATH=$(GOPATH) go get github.com/HewlettPackard/gas

# Install this application
install: uninstall
	mkdir -p $(PATHINSTBIN)
	cp -r ./target/${BINPATH}* $(PATHINSTBIN)
	find $(PATHINSTBIN) -type d -exec chmod 755 {} \;
	find $(PATHINSTBIN) -type f -exec chmod 755 {} \;
	mkdir -p $(PATHINSTDOC)
	cp -f ./LICENSE $(PATHINSTDOC)
	cp -f ./README.md $(PATHINSTDOC)
	cp -f ./VERSION $(PATHINSTDOC)
	cp -f ./RELEASE $(PATHINSTDOC)
	chmod -R 644 $(PATHINSTDOC)*
ifneq ($(strip $(INITPATH)),)
	mkdir -p $(PATHINSTINIT)
	cp -ru ./resources/${INITPATH}* $(PATHINSTINIT)
	find $(PATHINSTINIT) -type d -exec chmod 755 {} \;
	find $(PATHINSTINIT) -type f -exec chmod 755 {} \;
endif
ifneq ($(strip $(CONFIGPATH)),)
	mkdir -p $(PATHINSTCFG)
	touch -c $(PATHINSTCFG)*
	cp -ru ./resources/${CONFIGPATH}* $(PATHINSTCFG)
	find $(PATHINSTCFG) -type d -exec chmod 755 {} \;
	find $(PATHINSTCFG) -type f -exec chmod 644 {} \;
endif
ifneq ($(strip $(MANPATH)),)
	mkdir -p $(PATHINSTMAN)
	cat ./resources/${MANPATH}${PROJECT}.1 | gzip -9 > $(PATHINSTMAN)${PROJECT}.1.gz
	find $(PATHINSTMAN) -type f -exec chmod 644 {} \;
endif

# Remove all installed files (excluding configuration files)
uninstall:
	rm -rf $(PATHINSTBIN)$(PROJECT)
	rm -rf $(PATHINSTDOC)

# Remove any build artifact
clean:
	GOPATH=$(GOPATH) go clean ./...

# Deletes any intermediate file
nuke:
	rm -rf ./target
	GOPATH=$(GOPATH) go clean -i ./...

# Compile the application
build: deps
	GOPATH=$(GOPATH) \
	CGO_ENABLED=0 \
	go build -ldflags '-extldflags "-static" -w -s -X main.ProgramVersion=${VERSION} -X main.ProgramRelease=${RELEASE}' -o ./target/${BINPATH}$(PROJECT) ./src
ifneq (${UPXENABLED},)
	upx --brute ./target/${BINPATH}$(PROJECT)
endif

# Cross-compile the application for several platforms
crossbuild: deps
	@echo "" > target/ccfailures.txt
	$(foreach TARGET,$(CCTARGETS), \
		$(eval GOOS = $(word 1,$(subst /, ,$(TARGET)))) \
		$(eval GOARCH = $(word 2,$(subst /, ,$(TARGET)))) \
		$(shell which mkdir) -p target/$(TARGET) && \
		GOOS=${GOOS} GOARCH=${GOARCH} GOPATH=$(GOPATH) go build -ldflags '-extldflags "-static" -w -s -X main.ProgramVersion=${VERSION}' -o ./target/${GOOS}/${GOARCH}/$(PROJECT) ./src \
		|| echo $(TARGET) >> target/ccfailures.txt ; \
	)
ifneq ($(strip $(cat target/ccfailures.txt)),)
	echo target/ccfailures.txt
	exit 1
endif

# --- PACKAGING ---

# Build the RPM package for RedHat-like Linux distributions
rpm:
	rm -rf $(PATHRPMPKG)
	rpmbuild \
	--define "_topdir $(PATHRPMPKG)" \
	--define "_vendor $(VENDOR)" \
	--define "_owner $(OWNER)" \
	--define "_project $(PROJECT)" \
	--define "_package $(PKGNAME)" \
	--define "_version $(VERSION)" \
	--define "_release $(RELEASE)" \
	--define "_current_directory $(CURRENTDIR)" \
	--define "_binpath /$(BINPATH)" \
	--define "_docpath /$(DOCPATH)" \
	--define "_configpath /$(CONFIGPATH)" \
	--define "_initpath /$(INITPATH)" \
	--define "_manpath /$(MANPATH)" \
	-bb resources/rpm/rpm.spec

# Build the DEB package for Debian-like Linux distributions
deb:
	rm -rf $(PATHDEBPKG)
	make install DESTDIR=$(PATHDEBPKG)/$(PKGNAME)-$(VERSION)
	rm -f $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/$(DOCPATH)LICENSE
	tar -zcvf $(PATHDEBPKG)/$(PKGNAME)_$(VERSION).orig.tar.gz -C $(PATHDEBPKG)/ $(PKGNAME)-$(VERSION)
	cp -rf ./resources/debian $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian
	mkdir -p $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/missing-sources
	echo "// fake source for lintian" > $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/missing-sources/$(PROJECT).c
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#DATE#~/`date -R`/" {} \;
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#VENDOR#~/$(VENDOR)/" {} \;
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#PROJECT#~/$(PROJECT)/" {} \;
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#PKGNAME#~/$(PKGNAME)/" {} \;
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#VERSION#~/$(VERSION)/" {} \;
	find $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/ -type f -exec sed -i "s/~#RELEASE#~/$(RELEASE)/" {} \;
	echo $(BINPATH) > $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).dirs
	echo "$(BINPATH)* $(BINPATH)" > $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/install
	echo $(DOCPATH) >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).dirs
	echo "$(DOCPATH)* $(DOCPATH)" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/install
ifneq ($(strip $(INITPATH)),)
	echo $(INITPATH) >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).dirs
	echo "$(INITPATH)* $(INITPATH)" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/install
endif
ifneq ($(strip $(CONFIGPATH)),)
	echo $(CONFIGPATH) >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).dirs
	echo "$(CONFIGPATH)* $(CONFIGPATH)" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/install
endif
ifneq ($(strip $(MANPATH)),)
	echo $(MANPATH) >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).dirs
	echo "$(MANPATH)* $(MANPATH)" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/install
endif
	echo "new-package-should-close-itp-bug" > $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	echo "hardening-no-relro $(BINPATH)$(PROJECT)" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	echo "embedded-library $(BINPATH)$(PROJECT): libyaml" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	echo "statically-linked-binary usr/bin/natsping" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	echo "script-with-language-extension usr/bin/md5str.sh" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	echo "binary-without-manpage usr/bin/md5str.sh" >> $(PATHDEBPKG)/$(PKGNAME)-$(VERSION)/debian/$(PKGNAME).lintian-overrides
	cd $(PATHDEBPKG)/$(PKGNAME)-$(VERSION) && debuild -us -uc

# build a compressed bz2 archive
bz2:
	rm -rf $(PATHBZ2PKG)
	make install DESTDIR=$(PATHBZ2PKG)
	tar -jcvf $(PATHBZ2PKG)/$(PKGNAME)-$(VERSION)-$(RELEASE).tbz2 -C $(PATHBZ2PKG) usr/ etc/

# build a docker container to run this service
docker:
	rm -rf $(PATHDOCKERPKG)
	make install DESTDIR=$(PATHDOCKERPKG)
	cp resources/DockerDeploy/Dockerfile $(PATHDOCKERPKG)/
	docker build --no-cache --tag=$(VENDOR)/$(PROJECT)$(DOCKERSUFFIX):latest $(PATHDOCKERPKG)

# check if the deployment container starts
dockertest:
	# clean previous docker containers (if any)
	rm -f target/old_docker_containers.id
	docker ps -a | grep $(NATS_DOCKER_IMAGE_NAME) | awk '{print $$1}' >> target/old_docker_containers.id || true
	docker ps -a | grep $(CONSUL_DOCKER_IMAGE_NAME) | awk '{print $$1}' >> target/old_docker_containers.id || true
	docker ps -a | grep $(VENDOR)/$(PROJECT)$(DOCKERSUFFIX) | awk '{print $$1}' >> target/old_docker_containers.id || true
	docker stop `cat target/old_docker_containers.id` 2> /dev/null || true
	docker rm `cat target/old_docker_containers.id` 2> /dev/null || true
	# start a NATS service inside a container
	docker run --detach=true --name=$(NATS_DOCKER_IMAGE_NAME)_$(VERSION)-$(RELEASE) --publish=4222 --hostname=test.nats nats > target/nats_docker_container.id
	# start a Consul service inside a container
	docker run --detach=true --name=$(CONSUL_DOCKER_IMAGE_NAME)_$(VERSION)-$(RELEASE) --publish=8500 --hostname=test.consul progrium/consul -server -bootstrap > target/consul_docker_container.id
	sleep 5
	# Get Docker ports
	docker inspect --format='{{(index (index .NetworkSettings.Ports "4222/tcp") 0).HostPort}}' `cat target/nats_docker_container.id` > target/nats_docker_container.port
	docker inspect --format='{{(index (index .NetworkSettings.Ports "8500/tcp") 0).HostPort}}' `cat target/consul_docker_container.id` > target/consul_docker_container.port
	# push Consul configuration
	curl -X PUT -d '{"natsAddress":"nats://127.0.0.1:'`cat target/nats_docker_container.port`'","log": {"level": "DEBUG","network": "","address": ""}}' http://127.0.0.1:`cat target/consul_docker_container.port`/v1/kv/config/natsping
	# Start natsping container
	docker run --net="host" --tty=true \
	--env="NATSPING_REMOTECONFIGPROVIDER=consul" \
	--env="NATSPING_REMOTECONFIGENDPOINT=127.0.0.1:`cat target/consul_docker_container.port`" \
	--env="NATSPING_REMOTECONFIGPATH=/config/natsping" \
	--env="NATSPING_REMOTECONFIGSECRETKEYRING=" \
	${VENDOR}/${PROJECT}$(DOCKERSUFFIX):latest > target/project_docker_container.run || true
	sleep 1
	# remove the testing container
	docker stop `cat target/consul_docker_container.id` 2> /dev/null || true
	docker rm `cat target/consul_docker_container.id` 2> /dev/null || true
	docker stop `cat target/nats_docker_container.id` 2> /dev/null || true
	docker rm `cat target/nats_docker_container.id` 2> /dev/null || true
	@exit `grep -ic "error" target/project_docker_container.run`

# Full build and test sequence
# You may want to change this and remove the options you don't need
buildall: build qa rpm deb

# Build everything inside a Docker container
dbuild:
	@mkdir -p target
	@rm -rf target/*
	@echo 0 > target/make.exit
	CVSPATH=$(CVSPATH) VENDOR=$(VENDOR) PROJECT=$(PROJECT) MAKETARGET='$(MAKETARGET)' ./dockerbuild.sh
	@exit `cat target/make.exit`
