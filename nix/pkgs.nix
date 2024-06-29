let

p = rec {
  nixpkgs = fetchTarball "https://github.com/NixOS/nixpkgs/tarball/nixos-23.11";
  pkgs = import nixpkgs {
    config = {
      allowUnfree = false;  # maybe necessary for some packages
    };
    overlays = [
    ];
  };
};

in

p.pkgs
