# omdrop: the AirDrop CLI and receiver (upstream is an Omarchy bar plugin).
# Pinned to 0.14.1, the only version the DMS AirDrop plugin (dmsAirDrop)
# accepts. Its source layout is kept under $out/share/omdrop, because the CLI
# and the DMS plugin both locate files relative to bin/omdrop.
#
# The radio helper comes from `omdrop-owl`; its /usr/lib/omdrop paths are
# pointed at that package.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  bash,
  keyutils,
  openssl,
  coreutils,
  util-linux,
  gawk,
  gnugrep,
  gnused,
  iproute2,
  wl-clipboard,
  desktop-file-utils,
  shared-mime-info,
  xdg-utils,
  hostname,
  glib,
  gobject-introspection,
  omdrop-owl,
}:

let
  inherit (omdrop-owl.passthru) pythonEnv;
  version = "0.14.1";
in
stdenvNoCC.mkDerivation {
  pname = "omdrop";
  inherit version;

  src = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-plugin";
    rev = "v${version}";
    hash = "sha256-l1uNnDDvHW/OXNloJFJH2uSW77C+c76b0Fc9Ed0YiU8=";
  };

  buildInputs = [
    bash
    pythonEnv
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    dir=$out/share/omdrop
    mkdir -p $dir
    cp -r manifest.json README.md LICENSE bin share $dir/

    substituteInPlace $dir/bin/omdrop \
      --replace-fail /usr/lib/omdrop ${omdrop-owl}/lib/omdrop \
      --replace-fail /usr/lib/libkeyutils.so.1 ${lib.getLib keyutils}/lib/libkeyutils.so.1
    # Prepend, not replace: pkexec has to stay the setuid wrapper from PATH.
    sed -i '2i export PATH=${
      lib.makeBinPath [
        pythonEnv
        openssl
        coreutils
        util-linux
        gawk
        gnugrep
        gnused
        iproute2
        wl-clipboard
        desktop-file-utils
        shared-mime-info
        xdg-utils
        hostname
      ]
    }:$PATH\nexport GI_TYPELIB_PATH=${
      lib.makeSearchPath "lib/girepository-1.0" [
        glib.out
        gobject-introspection
      ]
    }' $dir/bin/omdrop

    substituteInPlace $dir/bin/identity.py \
      --replace-fail "CDLL('libkeyutils.so.1'" "CDLL('${lib.getLib keyutils}/lib/libkeyutils.so.1'" \
      --replace-fail "['openssl'" "['${lib.getExe openssl}'"
    substituteInPlace $dir/bin/contacts.py \
      --replace-fail '["openssl"' '["${lib.getExe openssl}"'
    substituteInPlace $dir/share/airdrop-receiver.service \
      --replace-fail /usr/bin/python3 ${pythonEnv}/bin/python3

    runHook postInstall
  '';

  postFixup = ''
    patchShebangs $out/share/omdrop/bin
  '';

  meta = {
    description = "AirDrop CLI and receiver for Linux";
    homepage = "https://github.com/brentkearney/omdrop-plugin";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "omdrop";
  };
}
