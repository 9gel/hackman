let
  pkgs = import ./nix/pkgs.nix;
in
{
  hackman = pkgs.callPackage ./nix/hackman.nix { };
  buildPyPkgs = pkgs.callPackage ./nix/buildPyPkgs.nix { };
  downloadPyPkgs = pkgs.callPackage ./nix/downloadPyPkgs.nix { };
}
