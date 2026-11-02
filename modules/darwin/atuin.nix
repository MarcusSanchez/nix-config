# atuin is built from source here while the darwin binary cache lacks its
# current release, and two of its e2e cases (the Pi-agent resume paths)
# fail inside the darwin build sandbox. They join the skip list nixpkgs
# already passes to the test run; everything else still runs. Remove once
# the plain package substitutes again.
{ ... }:

{
  nixpkgs.overlays = [
    (_: prev: {
      atuin = prev.atuin.overrideAttrs (old: {
        checkFlags = (old.checkFlags or [ ]) ++ [
          "--skip=a_diverged_copy_resumes_only_as_chosen"
          "--skip=a_session_gone_on_with_elsewhere_catches_up_where_it_came_from"
        ];
      });
    })
  ];
}
