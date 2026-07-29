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

Both boxes install identically. Pick the name first: it's the `--name`, the
`#attr`, and the hostname, all the same string.

| name | what you get |
|---|---|
| `nixos` | the dev machine — everything, including the Zed/IdeaVim sync with the Windows side |
| `nixos-lite` | headless: same toolchains and shell, minus that sync |

A fresh instance boots as the stock `nixos` user and the first rebuild creates
`marcus`, which is why there's a restart in the middle.

> **One expected error.** Until this box's key is registered, the rebuild prints
> `Activation script snippet 'setupSecrets' failed`. Harmless — activation
> records it and carries on, so packages install and the host key gets created.
> Register it per [Secrets](#secrets) and rebuild again. Nothing needs
> pre-placing: the machine decrypts with the host key it generates here.

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

# Move the repo home and recreate the /etc/nixos symlink (not managed by the
# config; bare `nixos-rebuild` depends on it)
sudo mv /tmp/nixos-config /home/marcus/nix-config
sudo chown -R marcus:users /home/marcus/nix-config
sudo ln -sfn /home/marcus/nix-config /etc/nixos
exit
```

**On Windows again** — restart so `wsl.defaultUser` takes effect:

```powershell
wsl -t nixos
wsl -d nixos        # lands as marcus

# ...or the headless one
wsl -t nixos-lite
wsl -d nixos-lite
```

**First login as marcus.** `hostname` now prints the name you chose, so bare
`nh os switch` resolves with no `#name`. The neovim config is already cloned to
`~/.config/nvim`. Two things left:

1. Open `nvim` once so lazy.nvim installs plugins from `lazy-lock.json`
2. `fly auth login` — flyctl issues a session macaroon that's replaced when the
   session ends, so a stored copy goes stale rather than staying useful

`gh` and `atuin` come up authenticated; sops-nix put their credentials in place
during activation.

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

Same expected `setupSecrets failed` as on WSL, and the same fix: register this
mac per [Secrets](#secrets) and switch again. macOS generates
`/etc/ssh/ssh_host_ed25519_key` itself, so there's nothing to create. After that
the only thing left is opening `nvim` once — `gh`, `flyctl` and `atuin` all come
up authenticated.

## Secrets

Credentials live age-encrypted in `secrets/secrets.yaml` (in this repo), which
is why the repo can be public. sops-nix decrypts them at every activation and
every boot into `/run/secrets/`, and each tool is pointed at its file — so no
machine ever runs `gh auth login`. Only the *values* are encrypted; the keys
stay readable, so a diff shows *that* a credential changed without showing it.

**Every machine decrypts using its own SSH host key**
(`/etc/ssh/ssh_host_ed25519_key`, which is why `modules/nixos/ssh.nix` runs
sshd). No private key is ever copied between machines. Two files control this,
both at the root of this repo:

| file | what it is |
|---|---|
| `~/nix-config/.sops.yaml` | the list of keys allowed to decrypt |
| `~/nix-config/secrets/secrets.yaml` | the encrypted credentials |

### Editing a credential

From anywhere inside the repo, on a machine that can already decrypt:

```sh
sops ~/nix-config/secrets/secrets.yaml
```

It opens the decrypted file in `$EDITOR` and re-encrypts when you save. Commit
and push as normal.

### Adding a new machine

Both routes do the same three things: read the new machine's age key, add it to
`.sops.yaml`, re-encrypt. They differ only in *where* the re-encrypt runs,
because `sops updatekeys` has to decrypt first — so it needs a machine that
already can. Route A makes the new machine that machine; route B borrows an
existing one.

**First, on the NEW machine**, once it's been through the bootstrap above,
print its age public key. It's a *public* key: safe to paste anywhere.

```sh
sudo cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age
# -> age1abc123...
```

The `.sops.yaml` edit is identical either way. The new key goes in **two**
places — define it under `keys:`, then reference it under `creation_rules:`:

```yaml
keys:
  - &marcus age17fldh0l...          # your personal editing key
  - &nixos age1dqh47zg...
  - &mac age1nux0jf7...
  - &lite age1abc123...             # <- 1. add here, pick any name

creation_rules:
  - path_regex: secrets/[^/]+\.yaml$
    key_groups:
      - age:
          - *marcus
          - *nixos
          - *mac
          - *lite                   # <- 2. and reference it here
```

#### Route A — all on the new machine

Use this when the new machine is all you have. It works over a terminal alone,
no browser and no second machine, which is the `nixos-lite` case. The cost is
fetching your personal key, since that's the only identity the new box can get
hold of that already decrypts.

rbw arrives with the first switch — the one that printed `setupSecrets failed`.

```sh
rbw login
mkdir -p ~/.config/sops/age
rbw get -f notes "sops age key - nix-config (all machines)" \
  > ~/.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

That machine now decrypts, so everything else is local:

```sh
cd ~/nix-config
$EDITOR .sops.yaml                  # the edit shown above
sops updatekeys secrets/secrets.yaml
git add -A && git commit -m "secrets: add <machine>" && git push
nh os switch                        # or: nh darwin switch
```

The personal key has done its job at that point — the machine decrypts with its
own host key from here on. Delete it if you'd rather not leave it on the box;
you'd just fetch it again the next time you want to *edit* secrets there.

#### Route B — from a machine that already decrypts

No personal key needed: the existing machine decrypts with its own host key.

**On the existing machine:**

```sh
cd ~/nix-config
$EDITOR .sops.yaml                  # the edit shown above
sops updatekeys secrets/secrets.yaml
git add -A && git commit -m "secrets: add <machine>" && git push
```

**Back on the new machine:**

```sh
cd ~/nix-config && git pull
nh os switch                        # or: nh darwin switch
```

Either way you're done. `gh`, `flyctl` and `atuin` are all authenticated —
atuin logs itself in during activation, so nothing is typed.

### The personal key

`~/.config/sops/age/keys.txt` is the identity that lets *you* run `sops` to
edit secrets. Machines never need it — they use their host keys. It's backed
up in Bitwarden (`rbw get -f notes "sops age key - nix-config (all machines)"`).

Losing it is cheap: you can add a new personal key from any machine that still
decrypts. **Leaking it is not** — git history is permanent, so anyone with it
can decrypt every version ever committed. That means revoking at GitHub/fly,
not re-encrypting.
