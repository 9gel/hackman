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
}:

let
  fs = lib.fileset;
  sourceFiles = fs.gitTracked ./.;
  pytoml = builtins.fromTOML (builtins.readFile ./pyproject.toml);
  version = pytoml.tool.poetry.version;
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
  ];

  installPhase = ''
    # Build python package
    mkdir -p /opt/hackman/pypoetry
    poetry config cache-dir /opt/hackman/pypoetry
    poetry install --no-interaction --no-root --only main
    venvpath=`poetry env info -p`
    mkdir -p $out/opt/hackman

    # Generate Django static files
    env DJANGO_SETTINGS_MODULE=hackman.settings_prod hackman-manage collectstatic

    # Copy built package
    cp -r /opt/hackman/pypoetry $out/opt/hackman/

    # Create symlinks to all binaries starting with hackman* or dsl* in /usr/bin
    mkdir -p $out/usr/bin
    for bin in $venvpath/bin/dsl* $venvpath/bin/hackman*; do
      ln -s $venvpath/bin/$(basename $bin) $out/usr/bin/$(basename $bin)
    done

    # Copy systemd units
    mkdir -p $out/lib/systemd
    cp -rv systemd $out/lib/systemd/system

    # Copy udev units
    mkdir -p $out/lib/udev
    cp -rv udev $out/lib/udev/rules.d

    # Copy nginx configuration
    cp -rv nginx $out/opt/hackman/nginx
  '';
}
