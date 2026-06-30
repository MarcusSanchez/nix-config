{ inputs, config, pkgs, lib, ... }:

{
  imports = [ inputs.catppuccin.homeModules.default ];

  home.username = "marcus";
  home.homeDirectory = "/home/marcus";

  home.stateVersion = "25.05";

  home.packages = with pkgs; [
    croc
    buf

    # lazyvim deps
    tree-sitter
    ripgrep
    fd
    fzf
    xclip
  ];

  programs.neovim = {
    enable = true;
    package =  inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
  };

  programs.zoxide.enable = true;
  programs.atuin.enable = true;

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    autosuggestion.strategy = [ "history" "completion" ];

    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      plugins = [ "git" "sudo" "last-working-dir" ];
    };

    initContent = ''
      alias cls='clear'
      precmd() { echo }

      bindkey '^I' autosuggest-accept
      bindkey "$terminfo[kcbt]" expand-or-complete
    '';
  };

  catppuccin = { 
    enable = true;
    flavor = "mocha";
    accent = "blue";

    zsh-syntax-highlighting.enable = true;
    atuin.enable = true;
    nvim.enable = false;
  };

  programs.git = {
    enable = true;
    settings.user = {
      name = "Marcus Sanchez";
      email = "marcussanchez031@gmail.com";
    };
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper = {
      enable = true;
    };
  };

  home.file = { };

  home.sessionVariables = {
    SUDO_EDITOR = "nvim";
  };
}
  

