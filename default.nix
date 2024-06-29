let
  pkgs = import ./pkgs.nix;
in
pkgs.callPackage ./hackman.nix { }
