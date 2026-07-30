# nix-config

One flake, three machines. Each NixOS box resolves its own config **by
hostname** — `nixos-rebuild --flake /etc/nixos` with no `#attr` builds
`nixosConfigurations.<hostname>`, so the flake attribute and
`networking.hostName` have to stay equal.

| host | machine | user | repo symlinked to |
|---|---|---|---|
| `nixos` | WSL, dev | `marcus` | `/etc/nixos` |
| `nixos-lite` | WSL, headless | `marcus` | `/etc/nixos` |
| `Marcuss-MacBook-Air` | nix-darwin, Determinate Nix | `marcussanchez` | `/etc/nix-darwin` |

The repo lives at `~/nix-config` everywhere; the symlink is what bare
`nixos-rebuild` / `darwin-rebuild` look for.

## Layout

```
flake.nix                inputs + all three host wirings
.sops.yaml               which age keys can decrypt
secrets/secrets.yaml     credentials, age-encrypted (safe to push)
hosts/                   per-host values only — wsl/, wsl-lite/, mac/
modules/common/          shared system layer
modules/nixos/           WSL system layer — both WSL hosts, unchanged
modules/darwin/          mac system layer
home/marcus/             Home Manager: common/ + wsl/ + mac/, with
                         wsl.nix / wsl-lite.nix / mac.nix as entry points
```

One concern per file, and a file does nothing until it's in its directory's
`default.nix`. Every file opens with a comment explaining itself.

## Common operations

**WSL**

```sh
nh os switch                  # apply
nh os switch -u               # apply + update inputs
nvd diff /run/booted-system /run/current-system
```

**Mac**

```sh
nh darwin switch
nh darwin switch -u
nvd diff $(ls -d1v /nix/var/nix/profiles/system-*-link | tail -2)
```

**Both**

```sh
nix fmt                       # format
nix flake check               # validate before switching
nix flake update              # bump inputs
```

Both WSL boxes rebuild weekly from pushed main, so one push deploys to two
machines. The mac doesn't — update it by hand with `-u`.

## Bootstrapping a WSL machine

Both boxes install identically. Pick the name first — you'll type it as the
`--name` and as the `#attr`, and the config sets the hostname to match. Those
are three separate identifiers we keep equal by convention: `--name` is only
Windows' handle for the distro (`wsl -d`, `wsl -t`, `\\wsl$\<name>`), and it
does **not** set the hostname. The hostname comes from `networking.hostName`
via `/etc/wsl.conf`, which is why the `#attr` on the first rebuild is what
actually decides what this box becomes.

| name | what you get |
|---|---|
| `nixos` | the dev machine — everything, including the Zed/IdeaVim sync with the Windows side |
| `nixos-lite` | headless: same toolchains and shell, minus that sync |

A fresh instance boots as the stock `nixos` user and the first rebuild creates
`marcus`, which is why there's a restart in the middle.

> **One expected error.** The rebuild ends with
> `sops-install-secrets: cannot read keyfile '/var/lib/sops-nix/key.txt': no
> such file or directory`, then `Failed to run activate script` and a non-zero
> exit — because the age key isn't on this box yet. Harmless: activation
> carries on past it (you'll see it go on to reload user units), so everything
> else installs, including the `rbw` you'll use to fetch that key. You place it
> at the end of this section, then switch once more.
>
> Expect the same error again if you run `nh os switch` after the restart but
> before placing the key. Same cause, nothing new.

**On Windows** — download the latest `nixos.wsl` from
[NixOS-WSL releases](https://github.com/nix-community/NixOS-WSL/releases), then
run one of these (WSL refuses a `--name` that already exists on this PC):

```powershell
# the dev machine
wsl --install --from-file nixos.wsl --name nixos
wsl -d nixos

# ...or the headless one
wsl --install --from-file nixos.wsl --name nixos-lite
wsl -d nixos-lite
```

**Inside, as the default `nixos` user:**

```sh
CFG=nixos   # or nixos-lite — must match the --name above

# The stock image has flakes disabled, so these two pass the feature flags
# explicitly (an env var would be stripped by sudo). After the first switch
# the config enables flakes permanently.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git /tmp/nixos-config
sudo nixos-rebuild switch --option experimental-features 'nix-command flakes' --flake /tmp/nixos-config#$CFG

# Move the repo home and replace /etc/nixos with a symlink to it (not managed
# by the config; bare `nixos-rebuild` and NH_FLAKE both depend on it).
# The rm matters: /etc/nixos is a real directory on a fresh image, and
# `ln -s` into an existing directory silently creates the link *inside* it
# (/etc/nixos/nix-config) instead of replacing it. All it holds is the stock
# configuration.nix, which is unused once we build from the flake.
sudo mv /tmp/nixos-config /home/marcus/nix-config
sudo chown -R marcus:users /home/marcus/nix-config
sudo rm -rf /etc/nixos
sudo ln -s /home/marcus/nix-config /etc/nixos
ls -ld /etc/nixos    # must print a symlink, not a directory
exit
```

**On Windows again.** This restart is mandatory, and it's what applies both
`wsl.defaultUser` *and* the hostname — WSL reads `/etc/wsl.conf` only at distro
startup, so until now this box still calls itself `nixos` no matter what you
passed to `--name`. Don't run a bare `nh os switch` before it: with the old
hostname it would resolve `nixosConfigurations.nixos` and build the dev config
here, without erroring.

```powershell
wsl -t nixos
wsl -d nixos        # lands as marcus

# ...or the headless one
wsl -t nixos-lite
wsl -d nixos-lite
```

**First login as marcus.** Check `hostname` before anything else — it must
print the name you chose, since that's what makes bare `nh os switch` resolve
with no `#name`.

Nothing is authenticated yet — the first switch couldn't decrypt secrets, so
`gh`, `flyctl` and `atuin` are all still logged out. Do
[Placing the key](#placing-the-key) now; it ends with a second `nh os switch`,
after which they're all authenticated.

Then the last step: open `nvim` once so lazy.nvim installs plugins from
`lazy-lock.json` — the config itself is already cloned to `~/.config/nvim`.

## Bootstrapping a new Mac

Two blocks with a **mandatory new terminal between them** — that gap is the one
thing a paste-the-whole-section run gets wrong. Each block on its own can be
copied blindly.

```sh
# Install Homebrew — it also installs the Xcode Command Line Tools, which
# provide the git used below (a fresh Mac has neither). nix-darwin drives
# brew declaratively but never installs it.
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Determinate Nix (needs sudo)
curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
```

> ### ⛔ Open a new terminal before continuing
>
> The installer puts `nix` on `PATH` through a shell profile, but *this* shell
> read its profile before that existed — so `nix` is still "command not found"
> here, and the next block dies on it. Quit the terminal and open a fresh one.

```sh
# Clone the config
git clone https://github.com/MarcusSanchez/nix-config.git ~/nix-config

# First activation (bootstraps darwin-rebuild itself; this is also where brew
# installs everything declared in homebrew.nix, so it's slow)
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config

# Symlink so bare `sudo darwin-rebuild switch` works — the analog of the WSL
# machines keeping their config at /etc/nixos
sudo ln -s ~/nix-config /etc/nix-darwin

# Wire in the claude-code + devenv binary caches. Manual on the mac: daemon
# config is Determinate's, not nix-darwin's. Keys are public.
printf 'extra-substituters = https://claude-code.cachix.org https://devenv.cachix.org\nextra-trusted-public-keys = claude-code.cachix.org-1:YeXf2aNu7UTX8Vwrze0za1WEDS+4DuI2kVeWEE4fsRk= devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=\n' | sudo tee -a /etc/nix/nix.custom.conf
sudo launchctl kickstart -k system/systems.determinate.nix-daemon
```

Then open **one more terminal** — that activation replaced your login shell, and
Home Manager's session variables only land in a shell started after it.

Same expected `cannot read keyfile` error as on WSL, and the same fix: run
[Placing the key](#placing-the-key) to place the age key, then
`nh darwin switch` again. After that the only thing left is opening `nvim`
once — `gh`, `flyctl` and `atuin` all come up authenticated.

## Secrets

Credentials live age-encrypted in `secrets/secrets.yaml` (in this repo), which
is why the repo can be public. sops-nix decrypts them at every activation and
every boot into `/run/secrets/`, and each tool is pointed at its file — so no
machine ever runs `gh auth login`. Only the *values* are encrypted; the keys
stay readable, so a diff shows *that* a credential changed without showing it.

**Every machine decrypts with the same key** — your personal age key, backed up
in Bitwarden. There is one recipient, so adding a machine never edits the
recipient list and never re-encrypts anything.

| file | what it is |
|---|---|
| `~/nix-config/.sops.yaml` | the one key allowed to decrypt |
| `~/nix-config/secrets/secrets.yaml` | the encrypted credentials |
| `/var/lib/sops-nix/key.txt` | that key, on each machine (root, 0400) |
| `~/.config/sops/age/keys.txt` | the same key, for editing as your user |

### Editing a credential

From anywhere inside the repo:

```sh
sops ~/nix-config/secrets/secrets.yaml
```

It opens the decrypted file in `$EDITOR` and re-encrypts when you save. Commit
and push as normal.

### Placing the key

This is the whole of onboarding a machine — nothing to paste into
`.sops.yaml`, no `updatekeys`, no second machine involved.

```sh
rbw login                                   # your Bitwarden master password
sudo install -d -m 0700 /var/lib/sops-nix
rbw get -f notes "sops age key - nix-config (all machines)" \
  | sudo tee /var/lib/sops-nix/key.txt >/dev/null
  sudo chmod 0400 /var/lib/sops-nix/key.txt

nh os switch                                # or: nh darwin switch
```

`tee` rather than `install /dev/stdin`, because BSD `install` rejects a
non-regular source and that form fails on the mac. The `0700` parent is what
keeps the file private in between. If `rbw get` can't find the item, the note's
name has drifted — `rbw list | grep -i sops` gives the current one.

Optionally, so you can *edit* secrets from this machine too:

```sh
mkdir -p ~/.config/sops/age
rbw get -f notes "sops age key - nix-config (all machines)" \
  > ~/.config/sops/age/keys.txt
  chmod 600 ~/.config/sops/age/keys.txt
```

To confirm it worked, check the tools rather than the directory — atuin logs
itself in during activation, so nothing is typed:

```sh
gh auth status
atuin status | grep Username
zsh -lc 'fly auth whoami'    # -l matters: FLY_API_TOKEN is set by a login
                             # shell, so your current one won't have it yet
```

`ls /run/secrets/` is *denied by design* (mode `751`, so nothing can enumerate
what secrets exist) and looks like a failure when it isn't.

> **The key must exist before the switch that installs secrets.** sops-nix
> treats a missing `/var/lib/sops-nix/key.txt` as fatal rather than falling
> back, so secret installation aborts with `cannot read keyfile`. That's the
> harmless error both bootstrap sections mention — on a fresh box, the switch
> that fails is the one that installs `rbw` so you can fetch the key at all.

### The key itself

One age key does everything: machines decrypt with it, and you edit with it.
Bitwarden holds the master copy —
`rbw get -f notes "sops age key - nix-config (all machines)"`.

Losing every copy is the one unrecoverable case, so Bitwarden is the backup
that matters. Every machine also holds a copy, which makes that unlikely.

**Leaking it is the real risk** — git history is permanent, so anyone with this
key can decrypt every version ever committed, including credentials you've
since rotated. Per-machine keys would have bounded that, and were dropped on
purpose: revoking a recipient never un-exposes what it already read, so the
only remediation that works is rotating the credential at GitHub/fly/atuin.
Re-encrypting achieves nothing.
