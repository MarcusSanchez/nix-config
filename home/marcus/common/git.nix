# Git identity and GitHub CLI (gh also acts as the git credential helper).
{ ... }:

{
  programs.git = {
    enable = true;
    settings.user = {
      name = "Marcus Sanchez";
      email = "marcussanchez031@gmail.com";
    };
    # syntax-highlighted, word-level diffs for diff/log/show — delta
    # reads git's colors, so catppuccin theming carries through
    delta.enable = true;
  };

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
    # HM manages gh's config.yml read-only, so declare what `gh auth login`
    # would otherwise try (and fail) to write into it
    settings.git_protocol = "https";
  };
}
