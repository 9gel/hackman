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
  git,
}:

let
  fs = lib.fileset;
  root = ./..;
  sourceFiles = fs.gitTracked root;
  pytoml = builtins.fromTOML (builtins.readFile ./../pyproject.toml);
  version = pytoml.tool.poetry.version;
  workdir = "/hackman";
  destdir = "/opt/hackman";
  dockerfile = "Dockerfile";
  dockertag = "hackman_build:${builtins.toString builtins.currentTime}";
  build_script_file = "build.sh";
  venv_path_file = "venv.path";

  dockerfile_body = ''
    FROM nixos/nix:2.18.1-arm64
    RUN mkdir -p ${workdir}
    WORKDIR ${workdir}
    COPY ${build_script_file} ${build_script_file}
    COPY . ${workdir}
    VOLUME ["${destdir}"]
  '';

  build_script = ''
    set -x
    set -e

    mkdir -p ${destdir}/pypoetry
    poetry config cache-dir ${destdir}/pypoetry
    poetry install --no-interaction --no-root --only main
    echo "$(poetry env info -p)" > ${destdir}/${venv_path_file}

    # Generate Django static files
    DJANGO_SETTINGS_MODULE=hackman.settings_prod hackman-manage collectstatic
  '';
in
stdenv.mkDerivation {
  pname = "hackman";
  version = version;

  src = fs.toSource {
    root = root;
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
    git
  ];

  buildPhase = ''
    export HOME=$(pwd)  # awful way of working around a nix bug. WTF is /homeless-shelter???

    echo "${build_script}" > "${build_script_file}"
    echo "${dockerfile_body}" > "${dockerfile}"

    whoami
    id -u
    groups
    docker image build -t ${dockertag} - < "${dockerfile}"
    docker container run -v "$out:${destdir}" ${dockertag} bash ${build_script_file}
  '';

  installPhase = ''
    venvpath=$(cat $out/${venv_path_file})

    # Create symlinks of binaries
    mkdir -p $out/bin
    for bin in $venvpath/bin/dsl* $venvpath/bin/hackman*; do
      ln -s $venvpath/bin/$(basename $bin) $out/bin/$(basename $bin)
    done

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
