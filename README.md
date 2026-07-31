# nix-config

One flake, three machines. Each NixOS box resolves its own config **by
hostname** — `nixos-rebuild --flake /etc/nixos` with no `#attr` builds
`nixosConfigurations.<hostname>`, so the flake attribute and
`networking.hostName` have to stay equal.

| host | machine | user | repo symlinked to |
|---|---|---|---|
| `bedroom-wsl` | WSL, dev | `marcus` | `/etc/nixos` |
| `nixos-lite`, `office-lite-wsl-1`, `office-lite-wsl-2` | WSL, headless — one config, one instance per PC | `marcus` | `/etc/nixos` |
| `macbook-air` | nix-darwin, Determinate Nix | `marcussanchez` | `/etc/nix-darwin` |

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

Every WSL box rebuilds weekly from pushed main, so one push deploys to all
of them. The mac doesn't — update it with a pull + switch. CI bumps
`flake.lock` Sundays (only if the full eval gate passes), so those weekly
rebuilds actually carry new packages; `-u` is for bumping by hand.

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
| `bedroom-wsl` | the dev machine — everything, including the Zed/IdeaVim sync with the Windows side |
| `nixos-lite`, `office-lite-wsl-*` | headless: same toolchains and shell, minus that sync. Any name listed in `flake.nix` works — add a line there first |

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
wsl --install --from-file nixos.wsl --name bedroom-wsl
wsl -d bedroom-wsl

# ...or the headless one
wsl --install --from-file nixos.wsl --name nixos-lite
wsl -d nixos-lite
```

**Inside, as the default `nixos` user:**

```sh
HOSTNAME=<host-name>   # any attribute in flake.nix, matching the --name above

# The stock image has flakes disabled, so these two pass the feature flags
# explicitly (an env var would be stripped by sudo). After the first switch
# the config enables flakes permanently.
sudo nix --extra-experimental-features 'nix-command flakes' run nixpkgs#git -- clone https://github.com/MarcusSanchez/nix-config.git /tmp/nixos-config
sudo nixos-rebuild switch --option experimental-features 'nix-command flakes' --flake /tmp/nixos-config#$HOSTNAME

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
startup, so until now this box still calls itself `nixos` (the stock image's
name) no matter what you
passed to `--name`. Don't run a bare `nh os switch` before it: with the old
hostname it would resolve `nixosConfigurations.nixos`, which does not exist,
or worse a config meant for another box.

```powershell
wsl -t bedroom-wsl
wsl -d bedroom-wsl        # lands as marcus

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
# installs everything declared in homebrew.nix, so it's slow).
# The #macbook-air is needed exactly once: bare resolution goes by
# LocalHostName, which Apple autogenerates on a fresh mac — this switch is
# what sets it to macbook-air, and bare works from then on.
sudo nix run nix-darwin/master#darwin-rebuild -- switch --flake ~/nix-config#macbook-air

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

Inside the repo (`direnv allow` once per machine, then the repo's devenv
scripts are on PATH whenever you're cd'd in):

```sh
secrets:edit
```

Which is just `sops ~/nix-config/secrets/secrets.yaml`, if the shell isn't
loaded.

It opens the decrypted file in `$EDITOR` and re-encrypts when you save. Commit
and push as normal.

### Placing the key

This is the whole of onboarding a machine — nothing to paste into
`.sops.yaml`, no `updatekeys`, no second machine involved. As one command
(after `rbw login` and `direnv allow ~/nix-config`):

```sh
age:place    # fetches from Bitwarden, places both copies, verifies
             # against .sops.yaml, tells you the next step
```

Or by hand:

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

## Tailscale on a new PC

Only relevant if that box will be a tailnet node. Both `hosts/wsl` and
`hosts/wsl-lite` import `modules/nixos/tailscale.nix`, so every WSL host is
one unless you drop the import.

**Windows needs mirrored networking.** This is a Windows-side file the repo
can't manage, and it's per-PC rather than per-distro:

```powershell
@"
[wsl2]
networkingMode=mirrored
"@ | Set-Content $env:USERPROFILE\.wslconfig
wsl --shutdown
```

Order doesn't matter — before or after installing the distro, it just needs
the `wsl --shutdown` to take effect.

Two things break without it. NAT mode's MTU is 1280, which breaks SSH and TLS
while leaving `ping` working, so it looks like everything is fine until
nothing you actually use works. And the MagicDNS fix in `tailscale.nix` points
resolved at `10.255.255.254`, a resolver that only exists in mirrored mode —
without it, DNS falls back to `1.1.1.1`/`8.8.8.8`, so the internet works and
LAN and tailnet names quietly don't.

**Then enrol the box**, which is interactive and stores nothing in the repo:

```sh
sudo tailscale up --ssh
```

**The mac needs only this step.** Everything Windows-side above is
WSL-specific; on a fresh mac the daemon, its launchd job, and the
/etc/resolver/ts.net split-DNS hook all land with the first switch, and the
activation hook re-asserts `--ssh` on every rebuild. No reboot either — that
was only ever needed when migrating off the GUI app, whose network extension
lingers until restart.

**One node per PC.** Two WSL distros on one machine share a network namespace,
so two `tailscaled` would fight over `tailscale0`, UDP 41641 and the
`100.64.0.0/10` route. If a PC ever hosts two, the second one drops the
`tailscale.nix` import from its host module. Also don't run Tailscale on the
Windows side while a distro has it — the traffic gets encapsulated twice.
