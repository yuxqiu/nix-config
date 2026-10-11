# omdrop-owl: AirDrop radio backend for omdrop on non-Broadcom Wi-Fi, running
# AWDL in userspace through OWL. Mirrors upstream's PKGBUILD: OWL at the commit
# pinned in omdrop-owl's `pins` file, with omdrop-owl's patches, plus the
# radio-independent tools from omdrop-awdl, all in $out/lib/omdrop.
#
# To update: bump `src` (follow:branch main), then set `owl` and `omdrop-awdl`
# to the commits in its `pins` file.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libpcap,
  libev,
  libnl,
  python3,
  coreutils,
  gawk,
  gnugrep,
  gnused,
  iw,
  iproute2,
  iputils,
  networkmanager,
  procps,
  util-linux,
  glib,
  gobject-introspection,
}:

let
  src = fetchFromGitHub {
    owner = "t4t5";
    repo = "omdrop-owl";
    rev = "ee6a57d971c207c933a424c0d705044a02985b0a"; # follow:branch main
    hash = "sha256-YnBx/k6ao+y7m+p3PxFGCudrbG3/K3g3Ak1NwBdAQbs=";
  };

  # OWL_COMMIT in omdrop-owl's `pins`.
  owl = fetchFromGitHub {
    owner = "jedbillyb";
    repo = "owl";
    rev = "832d70f815c3d4a06a02117bf0fc5e868daa1ff0";
    hash = "sha256-wke+tR6E4mfmzlGw1tgXiYOkSxeIRvaOmOYNWXIUVR8=";
    fetchSubmodules = true;
  };

  # OMDROP_AWDL_COMMIT in omdrop-owl's `pins`.
  omdrop-awdl = fetchFromGitHub {
    owner = "brentkearney";
    repo = "omdrop-awdl";
    rev = "534f91a525337951ca19c311e53d333bd6d55100";
    hash = "sha256-GqxaM/5Qnj458AQPdHp1Jyfa6HK7tdybO6xDBbKUWc4=";
  };

  pythonEnv = python3.withPackages (
    ps: with ps; [
      libarchive-c
      pillow
      zeroconf
      ifaddr
      dbus-python
      pygobject3
    ]
  );

  # The helper runs through pkexec, which resets PATH, so it gets a fixed one.
  runtimePath = lib.makeBinPath [
    pythonEnv
    coreutils
    gawk
    gnugrep
    gnused
    iw
    iproute2
    iputils
    networkmanager
    procps
    util-linux
  ];

  # omdrop-awdl's tools, installed unmodified beside the helper.
  fromOmdropAwdl = [
    "send-to-peer"
    "airdrop-send.py"
    "awdl-af-parse.py"
    "awdl_identity.py"
    "awdl_debug.py"
    "ble-airdrop-adv.py"
    "awdl-airdrop-adv.py"
    "awdl-mdns-respond.py"
  ];
in
stdenv.mkDerivation {
  pname = "omdrop-owl";
  version = "0.1.0-unstable-2026-10-11";

  src = owl;

  patches = map (p: "${src}/patches/${p}") [
    "owl-01-tx-rate.patch"
    "owl-02-awdl-addr.patch"
    "owl-03-fixed-radio.patch"
    "owl-04-election-metric.patch"
    "owl-05-fixed-radio-noack.patch"
    "owl-06-fixed-radio-pin.patch"
    "owl-07-intel-reliability.patch"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  buildInputs = [
    libpcap
    libev
    libnl
    pythonEnv
  ];

  # The bundled googletest predates CMake 3.5; only the owl target is needed.
  cmakeFlags = [
    "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
    "-Wno-dev"
  ];
  buildFlags = [ "owl" ];

  installPhase = ''
    runHook preInstall

    lib=$out/lib/omdrop
    install -Dm755 daemon/owl $lib/owl
    install -Dm755 ${src}/userspace/omdrop-discoverable $lib/omdrop-discoverable
    install -Dm644 ${src}/userspace/owl-profiles $lib/owl-profiles
    for f in ${lib.concatStringsSep " " fromOmdropAwdl}; do
      install -Dm755 ${omdrop-awdl}/userspace/$f $lib/$f
    done

    sed -i '2i export PATH=${runtimePath}\nexport GI_TYPELIB_PATH=${
      lib.makeSearchPath "lib/girepository-1.0" [
        glib.out
        gobject-introspection
      ]
    }' $lib/omdrop-discoverable

    install -Dm644 ${src}/packaging/omdrop-owl.policy \
      $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy
    substituteInPlace $out/share/polkit-1/actions/io.github.t4t5.omdrop-owl.policy \
      --replace-fail /usr/lib/omdrop/omdrop-discoverable $lib/omdrop-discoverable

    runHook postInstall
  '';

  postFixup = ''
    patchShebangs $out/lib/omdrop
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    case "$($out/lib/omdrop/owl -S intersect -R 12 -m 02:00:00:00:00:01 -F -E -h 2>&1 || true)" in
      *"invalid option"*|*"-R takes"*|*"-m takes"*) echo "owl lacks the patched options"; exit 1 ;;
    esac
  '';

  passthru = { inherit pythonEnv; };

  meta = {
    description = "AirDrop radio backend for omdrop: AWDL in userspace through OWL";
    homepage = "https://github.com/t4t5/omdrop-owl";
    license = with lib.licenses; [
      gpl3Plus
      gpl2Only
      isc
    ];
    platforms = lib.platforms.linux;
  };
}
