/* 
   This fixed-output derivation is used for downloading all dependent python packages
   for Hackman. Only download files and packages here, do not build.

   If you update python package definitions or set a package to no-binary, the outputHash
   will change and you will get an error running 'nix-build -A downloadPyPkgs'. Get the
   new outputHash and update the outputHash below.

   Why not fetch and build all in the same derivation? Normal derivations cannot 
   access the network or anything outside the chroot, so you need to make a 
   derivation that accesses the network a fixed-output derivation with a 
   pre-determined outputHash (below). But fixed-output derivations cannot
   contain *any* references to the Nix store /nix/store . Any compilation
   or build will likely result in references to /nix/store. So we do it
   in two steps: first derivation - downloadPyPkgs - fetches the packages,
   second derivation uses the fetched package to do offline builds.

   If you run into errors with missing dependencies after adding a new python package,
   add build dependencies by:
   poetry add -G build <package>==<version>
 */
{
  pkgs,
  stdenv,
  lib,

  python-to-use,

  postgresql,

  poetry,
  cacert,
  git,
}:

let 
  # update this if changes
  outputHash = "sha256-cfh6qm05c2DREppQZxqCjX0Nb5n5SE5AEMDHZg0FCqU=";

  root = ./..;
  projectDef = (builtins.fromTOML (builtins.readFile ../pyproject.toml));
  projectGit = fetchGit ./..;

  # build these packages from source only to link system libraries properly
  pypkg-no-binary="gevent,greenlet,hidapi,msgpack,rapidfuzz";

  fs = lib.fileset;
  files = fs.unions [ ../pyproject.toml ../poetry.lock ];

  outdir = "pypkgs";
in

stdenv.mkDerivation {
  pname = "__hackman_download_pypkgs";
  version = "${projectDef.tool.poetry.version}-${projectGit.shortRev}";
  src = fs.toSource { root=root; fileset=files; };

  outputHash = outputHash;
  outputHashMode = "recursive";
  outputHashAlgo = "sha256";

  nativeBuildInputs = [
    python-to-use
    poetry
    git
    postgresql  # for psycopg2 script to determine build dependencies
  ];

  configurePhase = ''
    runHook preConfigure

    export POETRY_DIR="$PWD/.poetry"
    export POETRY_CONFIG_DIR="$POETRY_DIR/config"
    export POETRY_DATA_DIR="$POETRY_DIR/data"
    export POETRY_CACHE_DIR="$POETRY_DIR/cache"
    export POETRY_VIRTUALENVS_IN_PROJECT=true
    export POETRY_INSTALLER_NO_BINARY="${pypkg-no-binary}"
    poetry config warnings.export false

    runHook postConfigure
  '';

  postConfigure = ''
    export NIX_SSL_CERT_FILE="${cacert}/etc/ssl/certs/ca-bundle.crt"
  '';

  buildPhase = ''
    runHook preBuild

    mkdir -p ${outdir}
    poetry env use --no-interaction --no-ansi "${pkgs.python-to-use}/bin/python"

    # Install build dependencies to satisfy --check-build-dependencies below
    poetry export  --no-ansi --without-hashes --only build \
      -f requirements.txt > requirements-build.txt
    poetry run pip --no-cache-dir --disable-pip-version-check --no-color \
      download --use-pep517 --progress-bar off --no-binary "${pypkg-no-binary}" \
      -d ${outdir} -r requirements-build.txt
    poetry run pip --no-cache-dir --disable-pip-version-check --no-color \
      install  --use-pep517 --progress-bar off --check-build-dependencies --no-index \
      -f ${outdir} -r requirements-build.txt

    # Download packages and dependencies
    poetry export  --no-ansi --without-hashes --without build \
      -f requirements.txt > requirements.txt
    poetry run pip --no-cache-dir --disable-pip-version-check --no-color \
      download --use-pep517 --check-build-dependencies --no-build-isolation \
      --progress-bar off --no-binary "${pypkg-no-binary}" \
      -d ${outdir} -r requirements.txt 

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/${outdir}
    cp -r ${outdir}/* $out/${outdir}/
    cp requirements.txt $out/

    runHook postInstall
  '';
}
