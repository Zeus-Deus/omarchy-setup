# Installing Miniconda on Omarchy Linux

## Installation

Follow the official Miniconda installation instructions for Linux:
https://www.anaconda.com/docs/getting-started/miniconda/install#macos-linux-installation

## Why It Doesn't Work on All Terminals (Omarchy-Specific Issue)

After installation, conda commands won't work in new terminals because **Omarchy uses `set -e` in its bash initialization scripts**. This setting causes the shell to exit immediately when any command returns a non-zero exit code. Conda's initialization can trigger these exit codes during setup, which prevents conda from initializing properly in new terminal sessions.

## Fix for Omarchy

After running the Miniconda installer, apply this fix:

1. **Initialize conda for bash:**

```bash
~/miniconda3/bin/conda init bash
```

2. **Edit your `.bashrc` file:**

```bash
nvim ~/.bashrc
```

3. **Add `set +e` before the conda initialization block:**

Find the `# >>> conda initialize >>>` line and add `set +e` right above it:

```bash
set +e

# >>> conda initialize >>>

# !! Contents within this block are managed by 'conda init' !!

**conda_setup="$('/home/user/miniconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
   if [ $? -eq 0 ]; then
       eval "$**conda_setup"
else
if [ -f "/home/user/miniconda3/etc/profile.d/conda.sh" ]; then
. "/home/user/miniconda3/etc/profile.d/conda.sh"
else
export PATH="/home/user/miniconda3/bin:$PATH"
fi
fi
unset \_\_conda_setup

# <<< conda initialize <<<
```

4. **Apply the changes:**

```bash
source ~/.bashrc
```

(You may see "bash: hash: hashing disabled" - this is normal and harmless)

5. **Verify it works:**

```bash
conda --version
conda list
```

**Note:** The `(base)` environment indicator may not appear in Omarchy's custom prompt theme, but conda is fully functional. You can verify the base environment is active with `echo $CONDA_DEFAULT_ENV`.
