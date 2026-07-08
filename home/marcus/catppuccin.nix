# Catppuccin theming across CLI tools. nvim is themed by LazyVim itself.
{ inputs, ... }:

{
  imports = [ inputs.catppuccin.homeModules.default ];

  catppuccin = {
    enable = true;
    # Explicit to match the upcoming default; today `enable = true` already
    # auto-enrolls every port (hence the nvim opt-out below).
    autoEnable = true;
    flavor = "mocha";
    accent = "blue";

    zsh-syntax-highlighting.enable = true;
    atuin.enable = true;
    nvim.enable = false;
  };
}
