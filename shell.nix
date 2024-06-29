let
  pkgs = import ./nix/pkgs.nix;
  hackman = pkgs.callPackage ./nix/hackman.nix { };
  icat = pkgs.callPackage ./nix/icat.nix { };
  devPkgs = with pkgs; [
    # Packages only for development use. All other necessary packages
    # for hackman should go to hackman.nix or pyproject.toml
    cowsay
    lolcat
  ];

in

pkgs.mkShell {
  packages = hackman.buildInputs ++ icat.buildInputs ++ devPkgs ++ [ icat ];

  GREETING = "WELCOME TO HACKMAN";
  shellHook = ''
    echo '$the_cow = <<EOC;' > /tmp/bao.cow
    echo ' $thoughts' >> /tmp/bao.cow
    echo '  $thoughts' >> /tmp/bao.cow
    icat -w 28 hackman/static/screen/dsl-logo-bao.png >> /tmp/bao.cow
    echo ' ' >> /tmp/bao.cow
    echo 'EOC' >> /tmp/bao.cow
    if [ $(($RANDOM%2)) -eq 0 ]; then
      echo "$GREETING" | cowsay -f /tmp/bao.cow | lolcat
    else
      echo "$GREETING" | cowsay -f /tmp/bao.cow
    fi
    rm /tmp/bao.cow
  '';

  lib-path = with pkgs; lib.makeLibraryPath [
    libffi
    openssl
    stdenv.cc.cc
  ];
}
