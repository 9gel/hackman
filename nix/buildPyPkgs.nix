/*
  Only build the dependent python packages here.
  Do not access the internet. See comments in downloadPyPkgs.nix.
  Do not build anything inside the hackman project. This is so we can build all
  dependent packages separately before the content of the hackman project, which
  saves time and allows for rapid iteration of hackman nix package.
*/
{
  pkgs,
  stdenv,
  lib,

  python-to-use,

  postgresql,
  redis,
  sqlite,

  bzip2,
  hidapi,
  libffi,
  libudev-zero,
  libusb1,
  openssl,
  readline,
  zlib,

  poetry,
}:

let
  root = ./..;
  projectDef = (builtins.fromTOML (builtins.readFile ../pyproject.toml));
  projectGit = fetchGit ./..;

  # Build from source include path
  include-path = "${hidapi}/include/hidapi";

  # Note: this assumes all packages are in the root directory. Won't work for
  # poetry packages with the "from" key
  hackmanPkgs = map (p: ../. + "/${p.include}") projectDef.tool.poetry.packages;

  fs = lib.fileset;
  files = fs.unions ([ ../pyproject.toml ../poetry.lock ] ++ hackmanPkgs);

  downloadPyPkgs = pkgs.callPackage ./downloadPyPkgs.nix { };
in

stdenv.mkDerivation {
  pname = "__hackman_build_pypkgs";
  version = "${projectDef.tool.poetry.version}-${projectGit.shortRev}";
  src = fs.toSource { root=root; fileset=files; };

  nativeBuildInputs = [
    python-to-use

    postgresql
    redis
    sqlite

    bzip2
    hidapi
    libffi
    libudev-zero
    libusb1
    openssl
    readline
    zlib

    poetry
  ];

  buildIinputs = [
    python-to-use
    postgresql
    redis
    sqlite
  ];

  configurePhase = downloadPyPkgs.configurePhase;  # expects to set poetry dir in curr dir
  postConfigure = ''
    export C_INCLUDE_PATH="${include-path}"
    unset POETRY_VIRTUALENVS_IN_PROJECT
    export POETRY_VIRTUALENVS_PATH=$out/venv
  '';

  buildPhase = ''
    runHook preBuild

    poetry env use --no-interaction --no-ansi "${python-to-use}/bin/python"

    cp ${downloadPyPkgs}/requirements.txt .

    # replace github url with version
    hidapiver="$(egrep '^hidapi' requirements.txt | sed 's/^.*hidapi-\(.*\)\.tar.gz.*$/\1/')"
    sed -ie "s|^hidapi @ http.* ;|hidapi==$hidapiver ;|" requirements.txt
    rapidfuzzver="$(egrep '^rapidfuzz' requirements.txt | sed 's/^.*rapidfuzz-\(.*\)\.tar.gz.*$/\1/')"
    sed -ie "s|^rapidfuzz @ http.* ;|rapidfuzz==$rapidfuzzver ;|" requirements.txt

    # Install latest setuptool first
    poetry run pip --disable-pip-version-check --require-virtualenv --no-color \
      uninstall -y setuptools
    poetry run pip --disable-pip-version-check --require-virtualenv --no-color \
      install --no-cache-dir --no-index -f ${downloadPyPkgs}/pypkgs setuptools

    # Parallelize
    splits=40
    workers=4
    lines=$(($(wc -l requirements.txt | awk '{print $1}') / $splits + 1))
    split -l$lines -d -a4 --additional-suffix=.txt requirements.txt requirements

    # Build and install dependent python package
    ls requirements0*.txt | xargs --max-args=1 --max-procs=$workers \
      poetry run pip --disable-pip-version-check --require-virtualenv --no-color \
        install --no-cache-dir --no-index -f ${downloadPyPkgs}/pypkgs -r

    # Replace hackman paths to nix friendly before they get installed
    sed -ie 's|"__static_root__"|os.path.dirname(os.path.realpath(__file__))+"/../../../../../../static"|' hackman/settings_prod.py

    # Build and install hackman package
    poetry build --no-ansi -f wheel
    poetry run pip --disable-pip-version-check --require-virtualenv --no-color \
      install --no-cache-dir --no-deps --no-color dist/hackman-*-py3-none-any.whl

    # Collect Django static files into $out
    source $(poetry env info -p)/bin/activate
    env DJANGO_SETTINGS_MODULE=hackman.settings_prod \
      hackman-manage collectstatic --no-input --no-color

    echo "$(poetry env info -p)" > $out/venv_path

    runHook postBuild
  '';
}
