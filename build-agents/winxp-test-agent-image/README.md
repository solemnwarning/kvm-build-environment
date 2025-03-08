# winxp-test-agent

## Introduction

This is a Buildkite agent for testing software under Windows XP.

The current generation of buildkite-agent doesn't run on Windows XP, so instead of running it directly, we run buildkite-agent under Linux and spin up a Windows XP VM using nested QEMU virtualisation for running chosen commands via the `win` command within the jobs.

The buildkite-agent checkout directory is exported into the job's VM using Samba from the outer Linux VM and commands are executed using SSH.
