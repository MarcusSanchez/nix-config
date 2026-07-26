# Interactive shell: zsh + oh-my-zsh, plus the CLI helpers hooked into it.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Let `npm install -g` work natively: install into a writable prefix
  # instead of the read-only nix store. Deliberately impure — global npm
  # CLIs are throwaway convenience tools here, and nix-ld covers any
  # native binaries they ship.
  home.sessionVariables.NPM_CONFIG_PREFIX = "${config.home.homeDirectory}/.npm-global";
  home.sessionPath = [ "${config.home.homeDirectory}/.npm-global/bin" ];

  programs = {
    zoxide.enable = true;
    atuin.enable = true;

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
        theme = "robbyrussell";
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
        bindkey "$terminfo[kcbt]" expand-or-complete

        # Native devenv auto-activation (no .envrc needed): cd into a
        # `devenv allow`-ed project spawns a `devenv shell` subshell —
        # TUI and all, deliberately unquieted — and cd out exits it.
        eval "$(${lib.getExe pkgs.devenv} hook zsh)"
      '';
    };
  };
}
