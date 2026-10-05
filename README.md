# Omarchy Setup

My modular Omarchy configuration and setup scripts.

## Install

Run `./install.sh --help` to see the available setup profiles.

The custom mise wrapper guard is optional: `./install.sh --mise-wrapper-resolution`
(or the standalone [feature installer](features/mise-wrapper-resolution/README.md)).
It uses a post-update hook, not an `omarchy-mise-install` override. This is not an
upstream fix or a guarantee against future changes; apply manually after app
installs that regenerate wrappers.
