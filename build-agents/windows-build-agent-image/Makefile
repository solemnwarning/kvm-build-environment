# This Makefile produces a Windows build agent image using a pipelined packer
# process where each step takes an input image, runs Packer on it to produce an
# output for the next pipeline step.
#
# The longer and less-often-changed parts of the pipeline are in earlier steps
# to speed up build times when iterating on the end stages.
#
# Steps:
#
# 1) Build base Windows image from ISO (based on Packer-Win2022).
#
# 2) Download the latest Visual Studio Build Tools installer and build an NTFS
#    disk image containing the installer "layout" for offline installations.
#
# 3) Take (1) and apply any pending Windows updates.
#
# 4) Take (1) and (2) and install the Visual Studio Build Tools.
#
# 5) Take (4) and install MSYS2 and any packages in the MSYS2 environment.
#
# 6) Take (5) and install remaining software/configuration for the final image.

# Windows evals are good for 180 days before needing to be activated, so we
# rebuild the base Windows image if 120 days has passed since it was built.
WINDOWS_BASE_IMAGE_INTERVAL_DAYS := 120

# Windows and VS both supposedly have weekly-ish update release cycles... so we
# do updates every couple of weeks to not fall behind too much.
WINDOWS_UPDATE_INTERVAL_DAYS := 14
VISUAL_STUDIO_UPDATE_INTERVAL_DAYS := 14

# MSYS2 has no specific update cycle... might as well do 2 weeks here too.
MSYS2_UPDATE_INTERVAL_DAYS := 14

# Make has no built-in way of saying "rebuild this target if it is more than x days old", so we
# create "chaser" files whose modification timestamp is set to X days before the current time and
# list them as dependencies of the periodic targets.
#
# When the target is first built, the chaser file will be X days before the current time, and the
# chaser file is updated every time make runs until its timestamp finally overtakes the last build
# of the target and triggers it to be rebuilt.

S01_WINDOWS_BASE_CHASER := step-01-windows-base/.chaser
X := $(shell touch -d @"$$(($$(date +%s) - $$((60 * 60 * 24 * $(WINDOWS_BASE_IMAGE_INTERVAL_DAYS)))))" $(S01_WINDOWS_BASE_CHASER))

S02_DOWNLOAD_VS_TOOLS_CHASER := step-02-download-vs-build-tools/.chaser
X := $(shell touch -d @"$$(($$(date +%s) - $$((60 * 60 * 24 * $(VISUAL_STUDIO_UPDATE_INTERVAL_DAYS)))))" $(S02_DOWNLOAD_VS_TOOLS_CHASER))

S03_WINDOWS_UPDATE_CHASER := step-03-windows-update/.chaser
X := $(shell touch -d @"$$(($$(date +%s) - $$((60 * 60 * 24 * $(WINDOWS_UPDATE_INTERVAL_DAYS)))))" $(S03_WINDOWS_UPDATE_CHASER))

S05_MSYS2_CHASER := step-05-install-msys2/.chaser
X := $(shell touch -d @"$$(($$(date +%s) - $$((60 * 60 * 24 * $(MSYS2_UPDATE_INTERVAL_DAYS)))))" $(S05_MSYS2_CHASER))

.PHONY: all
all: step-06-everything-else

S01_WINDOWS_BASE_TARGET := step-01-windows-base/.last-successful-build

S01_WINDOWS_BASE_DEPS := \
	$(S01_WINDOWS_BASE_CHASER)

.PHONY: step-01-windows-base
step-01-windows-base: $(S01_WINDOWS_BASE_TARGET)

$(S01_WINDOWS_BASE_TARGET): $(S01_WINDOWS_BASE_DEPS)
	test -e "packer-Win2022/virtio-win-0.1.229.iso" \
		|| wget "https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.229-1/virtio-win-0.1.229.iso" \
			-O "packer-Win2022/virtio-win-0.1.229.iso"
	
	rm -rf "packer-Win2022/output-qemu"
	
	(cd packer-Win2022/ && packer build -timestamp-ui -only=qemu -var "disk_size=120G" win2022-gui.json)
	
	timestamp=$$(date --utc '+%Y-%m-%dT%H:%M:%SZ') \
		&& mkdir -p "step-01-windows-base/builds/$${timestamp}" \
		&& ln "packer-Win2022/output-qemu/Win2022_20324.qcow2" "step-01-windows-base/builds/$${timestamp}/step-01-windows-base.qcow2" \
		&& (cd "step-01-windows-base/builds/$${timestamp}/" && sha256sum step-01-windows-base.qcow2 > SHA256SUMS) \
		&& ln -snf "$$timestamp" step-01-windows-base/builds/latest
	
	test -e step-01-windows-base/.first-successful-build || touch step-01-windows-base/.first-successful-build
	touch step-01-windows-base/.last-successful-build

S02_DOWNLOAD_VS_TOOLS_TARGET := step-02-download-vs-build-tools/.last-successful-build

S02_DOWNLOAD_VS_TOOLS_DEPS := \
	$(S01_WINDOWS_BASE_TARGET) \
	step-02-download-vs-build-tools/step-02-download-vs-build-tools.pkr.hcl \
	$(S02_DOWNLOAD_VS_TOOLS_CHASER)

.PHONY: step-02-download-vs-build-tools
step-02-download-vs-build-tools: S02_DOWNLOAD_VS_TOOLS_TARGET

$(S02_DOWNLOAD_VS_TOOLS_TARGET): $(S02_DOWNLOAD_VS_TOOLS_DEPS)
	./build-step.sh step-02-download-vs-build-tools

S03_WINDOWS_UPDATE_TARGET := step-03-windows-update/.last-successful-build

S03_WINDOWS_UPDATE_DEPS := \
	$(S01_WINDOWS_BASE_TARGET) \
	step-03-windows-update/step-03-windows-update.pkr.hcl \
	$(S03_WINDOWS_UPDATE_CHASER)

.PHONY: step-03-windows-update
step-03-windows-update: $(S03_WINDOWS_UPDATE_TARGET)

$(S03_WINDOWS_UPDATE_TARGET): $(S03_WINDOWS_UPDATE_DEPS)
	./build-step.sh step-03-windows-update \
		-var "base_image_version=$(shell readlink step-01-windows-base/builds/latest)"

S04_INSTALL_VS_BUILD_TOOLS_TARGET := step-04-install-vs-build-tools/.last-successful-build

S04_INSTALL_VS_BUILD_TOOLS_DEPS := \
	$(S02_DOWNLOAD_VS_TOOLS_TARGET) \
	$(S03_WINDOWS_UPDATE_TARGET) \
	step-04-install-vs-build-tools/step-04-install-vs-build-tools.pkr.hcl

.PHONY: step-04-install-vs-build-tools
step-04-install-vs-build-tools: $(S04_INSTALL_VS_BUILD_TOOLS_TARGET)

$(S04_INSTALL_VS_BUILD_TOOLS_TARGET): $(S04_INSTALL_VS_BUILD_TOOLS_DEPS)
	./build-step.sh step-04-install-vs-build-tools \
		-var "base_image_version=$(shell readlink step-03-windows-update/builds/latest)"

S05_MSYS2_TARGET := step-05-install-msys2/.last-successful-build

S05_MSYS2_DEPS := \
	$(S04_INSTALL_VS_BUILD_TOOLS_TARGET) \
	step-05-install-msys2/step-05-install-msys2.pkr.hcl \
	$(S05_MSYS2_CHASER)

.PHONY: step-05-install-msys2
step-05-install-msys2: $(S05_MSYS2_TARGET)

$(S05_MSYS2_TARGET): $(S05_MSYS2_DEPS)
	./build-step.sh step-05-install-msys2 \
		-var "base_image_version=$(shell readlink step-04-install-vs-build-tools/builds/latest)"

S06_EVERYTHING_ELSE_TARGET := step-06-everything-else/.last-successful-build

S06_EVERYTHING_ELSE_DEPS := \
	$(S05_MSYS2_TARGET) \
	step-06-everything-else/autologon.ps1 \
	step-06-everything-else/buildkite-agent-run.bat \
	step-06-everything-else/buildkite-command-hook.bat \
	step-06-everything-else/buildkite-environment-hook.bat \
	step-06-everything-else/ccache.ps1 \
	step-06-everything-else/Get-RandomPassword.ps1 \
	step-06-everything-else/git.ps1 \
	step-06-everything-else/gitconfig \
	step-06-everything-else/htmlhelp.ps1 \
	step-06-everything-else/Set-UserRights.ps1 \
	step-06-everything-else/step-06-everything-else.pkr.hcl \
	step-06-everything-else/stunnel.conf

.PHONY: step-06-everything-else
step-06-everything-else: $(S06_EVERYTHING_ELSE_TARGET)

$(S06_EVERYTHING_ELSE_TARGET): $(S06_EVERYTHING_ELSE_DEPS)
	./build-step.sh step-06-everything-else \
		-var-file=../../windows-build-agent.pkrvars.hcl \
		-var "base_image_version=$(shell readlink step-05-install-msys2/builds/latest)"
