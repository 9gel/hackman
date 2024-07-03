/*
  Only build the Hackman package here. Do not access the internet while doing so.
  See comments in downloadPyPkgs.nix.
*/
{
  pkgs,
  stdenv,
  lib,

  python-to-use,

  poetry,
}:

let
  root = ./..;
  projectDef = (builtins.fromTOML (builtins.readFile ../pyproject.toml));
  projectGit = fetchGit ./..;

  fs = lib.fileset;
  srcFiles = fs.unions [ (fs.gitTracked root) ];

  buildPyPkgs = pkgs.callPackage ./buildPyPkgs.nix { };
in

stdenv.mkDerivation {
  pname = "hackman";
  version = "${projectDef.tool.poetry.version}-${projectGit.shortRev}";
  src = fs.toSource { root = root; fileset = srcFiles; };

  nativeBuildInputs = [ python-to-use poetry ];
  buildInputs = [ python-to-use buildPyPkgs ];

  buildPhase = ''
    runHook preBuild

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Link over the static directory
    ln -s ${buildPyPkgs}/static static

    # Create symlinks to all binaries starting with hackman* or dsl* in bin dir
    VENVPATH="$(cat ${buildPyPkgs}/venv_path)"
    BINPATH=$out/bin
    mkdir -p $BINPATH
    for bin in $VENVPATH/bin/dsl* $VENVPATH/bin/hackman*; do
      ln -s $VENVPATH/bin/$(basename $bin) $BINPATH/$(basename $bin)
    done

    # Install systemd, udev and nginx rules
    install -Dt $out/lib/systemd systemd/*
    install -Dt $out/lib/udev/rules.d udev/*
    install -Dt $out/lib/nginx/sites-enabled nginx/*

    runHook postInstall
  '';
}
