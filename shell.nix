let
  GREETING = "WELCOME TO HACKMAN";

  pkgs = import nix/pkgs.nix;

  buildPyPkgs = pkgs.callPackage nix/buildPyPkgs.nix { };
  icat = pkgs.callPackage nix/icat.nix { };

  devPkgs = [ icat ] ++ (with pkgs; [
    # Packages only for development use. All other necessary packages
    # for Hackman should go to pyproject.toml, buildPyPkgs.nix or hackman.nix
    cowsay
    lolcat
    niv
    usbutils
  ]);
in

pkgs.mkShell {
  packages = devPkgs;
  inputsFrom = [ buildPyPkgs ];

  preShellHook = buildPyPkgs.configurePhase or null;
  postConfigure = buildPyPkgs.postConfigure or null;

  shellHook = ''
    runHook preShellHook

    # enable poetry and enter virtual environment
    poetry env use "${pkgs.python-to-use}/bin/python"
    source $(poetry env info --path)/bin/activate
    poetry install --no-interaction

    runHook postShellHook
  '';

  postShellHook = ''
    baofile=/tmp/bao-$(whoami)-$(date +%s)
    echo '$the_cow = <<EOC;' > "$baofile"
    echo ' $thoughts' >> "$baofile"
    echo '  $thoughts' >> "$baofile"
    icat -w 28 hackman/static/screen/dsl-logo-bao.png >> "$baofile"
    echo ' ' >> "$baofile"
    echo 'EOC' >> "$baofile"
    if [ $(($RANDOM%2)) -eq 0 ]; then
      echo "${GREETING}" | cowsay -f "$baofile" | lolcat
    else
      echo "${GREETING}" | cowsay -f "$baofile"
    fi
    rm "$baofile"
  '';
}
