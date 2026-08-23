# Silence login(1)'s "Last login: ..." banner in every new terminal
# tab — macOS terminals (ghostty included) start each surface through
# /usr/bin/login, which prints it unless ~/.hushlogin exists. Mac-only:
# Linux terminals don't spawn shells via login.
{ ... }:

{
  home.file.".hushlogin".text = "";
}
