let
  GREETING = "WELCOME TO HACKMAN";

  pkgs = import nix/pkgs.nix;

  hackman = pkgs.callPackage nix/hackman.nix { };
  icat = pkgs.callPackage nix/icat.nix { };

  devPkgs = with pkgs; [
    # Packages only for development use. All other necessary packages
    # for hackman should go to hackman.nix or pyproject.toml
    cowsay
    lolcat
    niv
  ];

in

pkgs.mkShell {
  packages = hackman.buildInputs ++ devPkgs ++ [ icat ];

  preShellHook = hackman.configurePhase or null;

  shellHook = ''
    runHook preShellHook

    # enable poetry and enter virtual environment
    export POETRY_CACHE_DIR="$PWD/.cache"
    poetry env use "${pkgs.python-to-use.outPath}/bin/python"
    poetry install --no-interaction --no-root
    source $(poetry env info --path)/bin/activate

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
