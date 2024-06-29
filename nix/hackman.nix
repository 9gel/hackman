# Complete hackman build
{
  stdenv,
  lib,
  python311,
  libffi,
  openssl,
  readline,
  redis,
  postgresql,
  sqlite,
  bzip2,
  systemd,
  fpm,
  libusb1,
  libudev-zero,
  poetry,
  docker,
}:

let
  fs = lib.fileset;
  sourceFiles = fs.gitTracked ./.;
  pytoml = builtins.fromTOML (builtins.readFile ./pyproject.toml);
  version = pytoml.tool.poetry.version;
  destdir = "/opt/hackman";
in
stdenv.mkDerivation {
  pname = "hackman";
  version = version;

  src = fs.toSource {
    root = ./.;
    fileset = sourceFiles;
  };

  buildInputs = [
    python311
    libffi
    openssl
    readline
    redis
    postgresql
    sqlite
    bzip2
    systemd
    fpm
    libusb1
    libudev-zero
    poetry
    docker
  ];

  buildPhase = ''
    # Build python package
    mkdir -p ${destdir}/pypoetry
    poetry config cache-dir ${destdir}/pypoetry
    poetry install --no-interaction --no-root --only main
    venvpath=`poetry env info -p`

    # Generate Django static files
    env DJANGO_SETTINGS_MODULE=hackman.settings_prod hackman-manage collectstatic

    # Create symlinks of binaries
    mkdir -p ${destdir}/bin
    for bin in $venvpath/bin/dsl* $venvpath/bin/hackman*; do
      ln -s $venvpath/bin/$(basename $bin) ${destdir}/bin/$(basename $bin)
    done
  '';

  installPhase = ''
    # Copy built package
    cp -r build/pypoetry $out/${destdir}/

    # Create symlinks to all binaries starting with hackman* or dsl* in /usr/bin
    mkdir -p $out/usr/bin

    # Copy systemd units
    mkdir -p $out/lib/systemd
    cp -rv systemd $out/lib/systemd/system

    # Copy udev units
    mkdir -p $out/lib/udev
    cp -rv udev $out/lib/udev/rules.d

    # Copy nginx configuration
    cp -rv nginx $out/${destdir}/nginx
  '';
}
