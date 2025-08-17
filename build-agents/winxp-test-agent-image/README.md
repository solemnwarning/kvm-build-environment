# winxp-test-agent

## Introduction

This is a Buildkite agent for testing software under Windows XP.

The current generation of buildkite-agent doesn't run on Windows XP, so instead of running it directly, we run buildkite-agent under Linux and spin up a <s>Windows XP VM using nested QEMU virtualisation</s> PXE-booted Windows XP image on a real machine[^1] for running chosen commands via the `win` command within the jobs.

The buildkite-agent checkout directory is exported into the target using Samba from the Linux VM and commands are executed using SSH.

[^1] This used to use a QEMU VM, and that might be best for most people, but I wanted to be absolutely sure my binaries would run on period-correct CPUs, and had already missed such issues due to QEMU not enforcing available CPU features for guests. If you want to see how that worked, check out this directory at commit 13dafb038d9c2281e9b2378705705ad4e4159d32.
