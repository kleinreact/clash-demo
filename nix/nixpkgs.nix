{ sources ? import ./sources.nix }:

let
  overlay = _: nixpkgs: {
    niv = (import sources.niv {}).niv;
    gitignore = import sources.gitignore { inherit (nixpkgs) lib; };

    mc = import ./mc.nix { inherit (nixpkgs) pkgs; };

    haskellPackages = nixpkgs.haskellPackages.override {
      overrides = self: super: {
        applyPrefs = p:
          (nixpkgs.haskell.lib.disableLibraryProfiling
            (nixpkgs.haskell.lib.dontHaddock
              (nixpkgs.haskell.lib.dontCheck p)));
      };
    };
  };

in import sources.nixpkgs { overlays = [ overlay ]; }
