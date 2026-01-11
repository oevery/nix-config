# nix-config

This repository contains my personal Nix configuration files for managing my development environment and system settings using Nix.

## 🚀 Quick Start

Ensure Nix is installed on your system. Your /etc/nix/nix.conf should include:

```nix
build-users-group = nixbld
# Enable the modern nix-command and Flakes support
experimental-features = nix-command flakes
# Using Tsinghua (TUNA) mirror for faster downloads in mainland China
substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
# Allow the following users to connect to the Nix daemon and manage settings
trusted-users = root oevery
# Enable sandboxing for builds to ensure they are isolated and reproducible
sandbox = true
# Automatically detect and hard-link identical files in the store to save space
auto-optimise-store = true
# Prevent Nix from deleting build dependencies of currently installed packages
keep-outputs = true
keep-derivations = true
# Allow builders to use binary substitutes for faster builds
builders-use-substitutes = true
```
