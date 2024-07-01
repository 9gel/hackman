let

p = rec {
  sources = import ./sources.nix;
  overlay = _: pkgs: {
    python-to-use =pkgs.python39;   
  };
  pkgs = import sources.nixpkgs { 
    config = {
      allowUnfree = false;  # maybe necessary for some packages
    };
    overlays = [ overlay ];
  };

};

in

p.pkgs
