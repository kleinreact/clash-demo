
{ pkgs ? import nix/nixpkgs.nix {} }:
pkgs.mkShell {
  name = "shell";
  buildInputs =
    [
      pkgs.buildPackages.cabal-install
      pkgs.buildPackages.dtc
      pkgs.buildPackages.gcc
      pkgs.buildPackages.ghc
      pkgs.buildPackages.pkg-config
      pkgs.buildPackages.git
    ]
    ;

  shellHook = ''
    export LC_ALL="C.UTF-8";
    export CABAL_DIR="$HOME/.cabal-nix";

    # Allow usage of local binaries
    export PATH="$(git rev-parse --show-toplevel)/bin:$PATH";
  '';
}
