# Omarchy Setup

My modular Omarchy configuration and setup scripts.

## Install

Run `./install.sh --help` to see the available setup profiles.

The custom mise wrapper guard is optional: `./install.sh --mise-wrapper-resolution`
(or the standalone [feature installer](features/mise-wrapper-resolution/README.md)).
It uses a post-update hook, not an `omarchy-mise-install` override. This is not an
upstream fix or a guarantee against future changes; apply manually after app
installs that regenerate wrappers.

Personal herdr settings are optional too: `./install.sh --herdr` merges
[`features/herdr/overrides.toml`](features/herdr/README.md) into Omarchy's
default herdr config and re-applies it after each Omarchy update.

## Docker access

At the end of setup, the installer runs Omarchy's opt-in flow for sudoless
Docker. If it is not already enabled, Omarchy explains that Docker group access
is root-equivalent and asks for confirmation. Accepting restores the familiar
`docker ...` workflow without `sudo`; reboot when prompted to apply the new
group membership.

To run the flow separately:

```bash
omarchy setup security sudoless docker
```
