# Mise wrapper resolution

Temporary workaround until Omarchy ships package-scoped mise wrapper resolution.

Run:

```bash
./features/mise-wrapper-resolution/install.sh
```

It installs a user-owned wrapper generator and only regenerates recognized, unmodified Omarchy wrappers. Customized wrappers and symlinks are left untouched. Do not manually edit these wrappers while the feature installer is running.

Remove this feature after the equivalent upstream migration is installed:

```bash
generator="$HOME/.local/bin/omarchy-mise-install"
backup="$generator.before-mise-wrapper-resolution"
if [[ -e $backup || -L $backup ]]; then
  mv -f -- "$backup" "$generator"
else
  rm -f -- "$generator"
fi
```

This restores a generator that the feature backed up; otherwise the packaged generator takes over. Existing wrappers can remain until Omarchy regenerates them.
