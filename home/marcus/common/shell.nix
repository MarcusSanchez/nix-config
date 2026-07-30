# Interactive shell: zsh + oh-my-zsh, plus the CLI helpers hooked into it.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  home.sessionVariables = {
    # NixOS ships nano as the default $EDITOR; make git/rebase/etc. open nvim
    EDITOR = "nvim";
    SUDO_EDITOR = "nvim";

    # Let `npm install -g` work natively: install into a writable prefix
    # instead of the read-only nix store. Deliberately impure — global npm
    # CLIs are throwaway convenience tools here, and nix-ld covers any
    # native binaries they ship.
    NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  };
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  programs = {
    zoxide.enable = true;

    atuin = {
      enable = true;
      settings = {
        # E2E key comes from sops (modules/nixos/secrets.nix), not from
        # whatever `atuin login` last wrote. NOTE: no trailing newline in
        # the secret or atuin fails with "failed to parse header value".
        key_path = "/run/secrets/atuin_key";

        # With sync on, history is pooled across machines — but a mac
        # command surfacing in a WSL Ctrl-R is just noise. Default the
        # search to this host and cycle out to global with another Ctrl-R
        # inside the search UI when you actually want it. Hostnames are
        # distinct per box, so the split is exact rather than heuristic.
        # (The inline grey suggestion is zsh-autosuggestions reading the
        # local $HISTFILE — atuin never feeds it, synced or not.)
        filter_mode = "host";
        # up-arrow behaves like plain shell history: this session only
        filter_mode_shell_up_key_binding = "session";
        # sync ships history end-to-end encrypted, but a command with a
        # secret pasted inline still leaves the machine — don't record those
        history_filter = [
          "(TOKEN|SECRET|PASSWORD|PASSWD|CREDENTIAL|APIKEY|API_KEY)=[^ ]"
          "AGE-SECRET-KEY-"
          "^\\s*(sops|age|age-keygen|atuin (login|register))\\b"
        ];
      };
    };

    # Auto-load per-project dev shells: a project with an .envrc saying
    # `use flake` gets its devShell on cd-in, dropped on cd-out.
    # nix-direnv caches the shell so re-entry is instant.
    direnv = {
      enable = true;
      nix-direnv.enable = true;
      # Silence the per-cd chatter; only log lines matching "error"
      # survive, so a broken .envrc still shows up loud. (The old
      # DIRENV_LOG_FORMAT="" trick no longer silences direnv 2.37+.)
      config.global.log_filter = "error";
      # Same idea for devenv projects: its direnv shim honors DEVENV_BIN,
      # so route only direnv-driven runs through a wrapper that drops the
      # TUI and its plain-log fallback (--tui false alone still prints
      # the •/✓ step lines). Failures still print (red ×, exit 1);
      # manual `devenv` invocations keep the TUI.
      stdlib = ''
        export DEVENV_BIN=${pkgs.writeShellScript "devenv-quiet" ''
          exec ${lib.getExe pkgs.devenv} --tui false --quiet "$@"
        ''}
      '';
    };

    zsh = {
      enable = true;
      enableCompletion = true;

      syntaxHighlighting.enable = true;
      autosuggestion.enable = true;
      autosuggestion.strategy = [
        "history"
        "completion"
      ];

      oh-my-zsh = {
        enable = true;
        # empty: starship.nix owns the prompt (oh-my-zsh is here for its
        # plugins). Restore "robbyrussell" if starship is ever dropped.
        theme = "";
        plugins = [
          "git"
          "sudo"
          "last-working-dir"
        ];
      };

      # Ordered after tool integrations (zoxide/atuin, order 1000) so the
      # keybindings below always win, regardless of module import order.
      initContent = lib.mkOrder 1200 ''
        alias cls='clear'
        precmd() { echo }

        bindkey '^I' autosuggest-accept
        # kcbt (back-tab) is undefined on terminals that don't report it —
        # notably over ssh, where the client's TERM may be missing or
        # unknown to the remote terminfo db. Binding an empty sequence
        # errors out with "cannot bind to an empty key sequence" on every
        # login, so only bind it when the terminal actually has one.
        [[ -n "$terminfo[kcbt]" ]] && bindkey "$terminfo[kcbt]" expand-or-complete
      '';
    };
  };
}
