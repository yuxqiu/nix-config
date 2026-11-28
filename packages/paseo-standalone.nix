# Paseo with a private copy of the node it was built with, named `paseo`, at
# libexec/paseo/paseo. Paseo otherwise runs on a shared node, which OpenSnitch
# can't tell apart from any other node program; the private copy gives
# firewall rules a path to match.
{
  lib,
  runCommand,
  paseo,
}:
let
  paseoNode = lib.getExe' paseo.nodejs "node";
in
runCommand "paseo-standalone" { } ''
  install -Dm755 ${paseoNode} $out/libexec/paseo/paseo
  mkdir -p $out/bin
  substitute ${paseo}/bin/paseo-server $out/bin/paseo-server \
    --replace-fail ${paseoNode} $out/libexec/paseo/paseo
  chmod +x $out/bin/paseo-server
  ln -s ${paseo}/bin/paseo $out/bin/paseo
''
