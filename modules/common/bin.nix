# The repo's operational scripts (bin/*), on PATH everywhere — thin
# wrappers that run the LIVE working-tree scripts, so editing bin/
# stays rebuild-free, the same philosophy as the dotfile links. Each
# wrapper execs its script from the repo root (the scripts resolve
# their pieces via git rev-parse); the caller's shell keeps its own
# directory untouched, as any child process guarantees. One derivation
# carries all of them because a store path's own NAME cannot contain
# the colon the script names use — the files inside it can.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  environment.systemPackages = [
    (pkgs.runCommand "repo-bin" { } ''
      mkdir -p $out/bin
      ${lib.concatMapStrings
        (name: ''
            cat > "$out/bin/${name}" <<'WRAP'
          #!/usr/bin/env bash
          cd ${config.identity.repo} || exit 1
          exec ./bin/${name} "$@"
          WRAP
            chmod +x "$out/bin/${name}"
        '')
        [
          "age:place"
          "config:check"
          "secrets:drop"
          "secrets:edit"
          "secrets:status"
        ]
      }
    '')
  ];
}
