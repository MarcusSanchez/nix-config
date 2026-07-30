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

    # the vendored tokyo-night preset hardcodes its own colours
    # (starship.nix) — keep one source of truth, and the port
    # builds a theme derivation at EVAL time, which no runner or
    # cross-platform eval can build
    starship.enable = false;

    nvim.enable = false;
  };
}
