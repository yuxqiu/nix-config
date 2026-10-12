# Happier relay server - https://github.com/happier-dev/happier
# Repackages the upstream release tarball (a Bun-compiled `happier-server`
# plus Prisma engines, SQLite migrations and the bundled web UI).
#
# To update:
#   1. Change `version`
#   2. Update each `hashes` entry (set to "" and build — nix will tell you)
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  openssl,
}:

let
  version = "0.2.16";
  arch =
    {
      x86_64-linux = "x64";
      aarch64-linux = "arm64";
    }
    .${stdenv.hostPlatform.system};
  hashes = {
    x64 = "sha256-FQ52yBxZBX7BpmCcdWksd0/oD3jP1IlPLMMefn/I+s4=";
    arm64 = "sha256-nwUovsMYF3hv45XzaTGE2/SqCRaJx6aD73uaVpDUwLc=";
  };
  # Prisma's platform detection does not recognise NixOS; point it at the
  # engine built for this architecture instead.
  queryEngine =
    {
      x64 = "libquery_engine-debian-openssl-3.0.x.so.node";
      arm64 = "libquery_engine-linux-arm64-openssl-3.0.x.so.node";
    }
    .${arch};
in
stdenv.mkDerivation {
  pname = "happier-server";
  inherit version;

  src = fetchurl {
    url = "https://github.com/happier-dev/happier/releases/download/server-v${version}/happier-server-v${version}-linux-${arch}.tar.gz";
    hash = hashes.${arch};
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  buildInputs = [
    stdenv.cc.cc.lib
    openssl
  ];

  # Stripping corrupts the payload Bun appends to the compiled executable.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Native modules and Prisma engines ship for every platform; keep only
    # glibc Linux ones so autoPatchelf has nothing unresolvable to chase.
    find . -depth -type d -name '*musl*' -exec rm -rf {} +
    find . -type f \( -name '*.musl.node' -o -name '*darwin*' -o -name '*windows*' \) -delete

    mkdir -p $out/lib/happier-server $out/bin
    cp -r . $out/lib/happier-server

    makeWrapper $out/lib/happier-server/happier-server $out/bin/happier-server \
      --set-default NODE_ENV production \
      --set-default HAPPIER_SERVER_FLAVOR light \
      --set-default HAPPIER_DB_PROVIDER sqlite \
      --set-default HAPPIER_SQLITE_AUTO_MIGRATE 1 \
      --set-default HAPPIER_SQLITE_MIGRATIONS_DIR $out/lib/happier-server/prisma/sqlite/migrations \
      --set-default HAPPIER_SERVER_UI_DIR $out/lib/happier-server/ui-web/current \
      --set-default HAPPIER_SERVER_UI_PREFIX / \
      --set-default PRISMA_QUERY_ENGINE_LIBRARY $out/lib/happier-server/generated/sqlite-client/${queryEngine}

    runHook postInstall
  '';

  meta = {
    description = "Self-hosted relay server for Happier";
    homepage = "https://github.com/happier-dev/happier";
    license = lib.licenses.mit;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    mainProgram = "happier-server";
  };
}
