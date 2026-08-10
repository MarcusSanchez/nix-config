# A bare `pinentry` on PATH, aliased to the gnome3 flavor: tpm-fido
# shells out to that exact name for its touch-confirmation prompt, and
# the gnome3 flavor prompts via gcr instead of a dead tty.
{ runCommand, pinentry-gnome3 }:

runCommand "pinentry-alias" { } ''
  mkdir -p $out/bin
  ln -s ${pinentry-gnome3}/bin/pinentry-gnome3 $out/bin/pinentry
''
