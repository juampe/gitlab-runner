DOCKER_TAG := juampe/gitlab-runner
RUNNER := 14.5.0
ARCH := $(shell docker version -f "{{.Server.Arch}}")
ARCHS := riscv64
UBUNTU := ubuntu:impish
LATEST_TAG := $(DOCKER_TAG):latest
RELEASE_TAG := $(DOCKER_TAG):$(RUNNER)
ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG)

all: $(addprefix build-, $(ARCHS))
archs: $(addprefix build-, $(ARCHS))

qemu:
	docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

build-%: qemu
	$(eval ARCH := $(subst build-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	docker image rm $(UBUNTU) || true
	docker build --platform linux/$(ARCH) --build-arg TARGETARCH=$(ARCH) --build-arg UBUNTU=$(UBUNTU) -t $(ARCH_TAG) -f Dockerfile .

#Phase 2 pipeline	
#needs cli plugin https://github.com/christian-korneck/docker-pushrm
publish: $(addprefix build-, $(ARCHS)) manifest

push-%:
	$(eval ARCH := $(subst push-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	@echo "Push $(ARCH_TAG)"
	docker push $(ARCH_TAG)
	docker pushrm $(ARCH_TAG)

push: $(addprefix push-, $(ARCHS))

pull-%:
	$(eval ARCH := $(subst pull-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	@echo "Pull $(ARCH_TAG)"
	docker pull --platform linux/$(ARCH) $(ARCH_TAG)

pull: $(addprefix pull-, $(ARCHS))

manifest-%:
	$(eval ARCH := $(subst manifest-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	@echo "Publish $(ARCH_TAG)"
	docker pull --platform linux/$(ARCH) $(ARCH_TAG)
#	docker rm $(ARCH_TAG)
	docker manifest create $(ARCH_TAG) --amend $(ARCH_TAG)
	docker manifest annotate --arch $(ARCH) $(RELEASE_TAG) $(ARCH_TAG)
	docker manifest annotate --arch $(ARCH) $(ARCH_TAG) $(ARCH_TAG)
	docker manifest push $(ARCH_TAG)

amend-%:
	$(eval ARCH := $(subst amend-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	$(eval AMEND := $(AMEND) --amend $(ARCH_TAG))
	@echo "Amend $(ARCH_TAG)"

manifest-clean-%: 
	$(eval ARCH := $(subst manifest-clean-,,$@))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(ARCH)$(DOCKER_SUBTAG))
	@echo "Clear manifest $(ARCH_TAG)"
	docker manifest rm $(ARCH_TAG) || return 0 >/dev/null

manifest-clean: $(addprefix manifest-clean-,$(ARCHS))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(CARDANO_VERSION))
	@echo "Clear manifest $(DOCKER_TAG):latest"
	docker manifest rm $(DOCKER_TAG):latest || return 0 >/dev/null
	
manifest-base: $(addprefix amend-,$(ARCHS))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(CARDANO_VERSION))
	@echo "Publish base release $(RELEASE_TAG)"
	docker manifest create $(LATEST_TAG) $(AMEND)
	docker manifest push $(LATEST_TAG)
	docker manifest create $(RELEASE_TAG) $(AMEND)
	docker manifest push $(RELEASE_TAG)

manifest: push manifest-base $(addprefix manifest-,$(ARCHS))
	$(eval ARCH_TAG := $(DOCKER_TAG):$(CARDANO_VERSION))
	@echo "Publish update $(DOCKER_TAG)"
	docker manifest push $(LATEST_TAG)
	docker manifest push $(RELEASE_TAG)

