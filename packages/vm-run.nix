# vm-run: start a throwaway microVM from a template, run one command in it,
# and discard the VM when the command exits.
#
#   vm-run <template> [-p DIR[:ro]]... [--cpus N] [--mem SIZE] [-- COMMAND...]
#                                         run COMMAND (default: a login shell)
#   vm-run attach <id> [-- COMMAND...]    another session in a running VM
#   vm-run mount [--ro] <id> DIR [NAME]   map DIR into a running VM at /work/NAME
#   vm-run umount <id> NAME               unmap it
#   vm-run ls                             VMs and their mapped directories
#   vm-run stop <id>                      kill a VM (e.g. one left by a killed vm-run)
#   vm-run templates                      template names
#
# Everything runs as the calling user. QEMU needs only /dev/kvm and
# /dev/vhost-vsock, which systemd's udev rules make world-accessible. The host
# reaches the guest's sshd over vsock (systemd-ssh-proxy), which is not tied
# to a network namespace.
#
# Network: QEMU's user-mode network turns guest connections into sockets of
# the QEMU process, and libslirp's only switches are all-or-nothing (QEMU
# 11.1 does not even pass on libslirp's disable_host_loopback). So QEMU runs
# in a network namespace of its own, made by pasta, whose nftables rules let
# its sockets reach the internet and nothing local: not the host's loopback
# services, the LAN, or the tailnet. pasta forwards no host ports into the
# namespace (-T/-U none) and does not map its gateway to the host
# (--no-map-gw); DNS reaches the host's resolver only through pasta's DNS
# forwarding at `guestDns`. QEMU itself runs in a nested user namespace as an
# unprivileged uid, so it holds no capability over that namespace's rules or
# mounts. The nested namespace maps the caller's uid to the guest user's uid,
# so mapped files belong to the guest user whatever the host uid is.
#
# Mapped directories: QEMU exports one directory, the run's `work`, over 9p;
# the guest mounts it at `workMount`. Mapping a directory bind-mounts it onto
# `work/<name>` inside QEMU's private mount namespace, at start or later: the
# 9p server opens paths when the guest asks, so a later mapping shows up in a
# running guest. The host never sees these mounts. A helper process
# (argv[0] "vm-run-holder:<run dir>") stays in that mount namespace
# and its user namespace, the one that may change the mounts, so that
# `vm-run mount`/`umount` can enter it with nsenter.
#
# Each run gets a fresh SSH key and a random vsock CID, kept with the pid, the
# console log and any disk images the template declares in
# $XDG_CACHE_HOME/vm-run/<id>, which is removed when the run ends. That
# directory must be on disk, not tmpfs: disk images grow there.
#
# The runners take their per-run values from the environment (the guest's
# `microvm.extraArgsScript`, set up by the vm-run Home Manager module):
# VM_RUN_DIR (holds key.pub and work), VM_RUN_CID, VM_RUN_CPU and, when set,
# VM_RUN_SEED, VM_RUN_CPUS and VM_RUN_MEM.
#
# A template may have a seed program (the guest's `vm-run.seed`): vm-run runs
# it on the host before boot with the run's empty seed directory, which the
# guest copies into its user's home.
{
  lib,
  writeShellApplication,
  writeShellScript,
  bash,
  coreutils,
  findutils,
  gawk,
  nftables,
  openssh,
  passt,
  procps,
  systemd,
  util-linux,
  # Template name -> { runner (`config.microvm.declaredRunner`); seed (a
  # program or null) }.
  templates ? { },
  # Where the guest mounts the run's `work` directory.
  workMount ? "/work",
  # The guest's login user and its uid and gid.
  guestUser ? "user",
  guestUid ? 1000,
  guestGid ? 100,
  # The address pasta answers DNS on (the guest's only nameserver).
  guestDns ? "169.254.1.1",
}:
let
  # Run by pasta as root of the new user and network namespace: install the
  # egress rules, then continue in a private mount namespace.
  # Address ranges: the IANA IPv4 and IPv6 special-purpose address registries
  # (RFC 6890); 100.64.0.0/10 (RFC 6598) is shared address space, which
  # covers Tailscale.
  inNamespace = writeShellScript "vm-run-in-namespace" ''
    set -eu
    ${nftables}/bin/nft -f - <<'EOF'
    table inet vm_run {
      chain output {
        type filter hook output priority filter; policy accept;
        oifname "lo" accept
        ip daddr ${guestDns} meta l4proto { tcp, udp } th dport 53 accept
        ip daddr { 0.0.0.0/8, 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.0.0.0/24, 192.168.0.0/16, 198.18.0.0/15, 224.0.0.0/3 } reject
        ip6 daddr { ::1/128, fc00::/7, fe80::/10, ff00::/8 } reject
      }
    }
    EOF
    exec ${util-linux}/bin/unshare --mount --propagation private -- ${inMountNamespace} "$@"
  '';

  # Still root of pasta's user namespace, now in QEMU's mount namespace: map
  # the directories given at start, leave the holder behind, and start the
  # runner as the unprivileged guest uid.
  inMountNamespace = writeShellScript "vm-run-in-mount-namespace" ''
    set -eu
    runner=$1
    while IFS=$'\t' read -r name mode path; do
      ${util-linux}/bin/mount --bind -- "$path" "$VM_RUN_DIR/work/$name"
      if [ "$mode" = ro ]; then
        ${util-linux}/bin/mount -o remount,bind,ro -- "$VM_RUN_DIR/work/$name"
      fi
    done < "$VM_RUN_DIR/mounts"
    # bash, not sleep: coreutils is one multi-call binary that picks the
    # program by argv[0], so a renamed sleep would not run.
    ( exec -a "vm-run-holder:$VM_RUN_DIR" ${bash}/bin/bash -c 'while :; do ${coreutils}/bin/sleep 3600; done' ) &
    cd "$VM_RUN_DIR"
    exec ${util-linux}/bin/unshare --user --map-user=${toString guestUid} --map-group=${toString guestGid} \
      -- "$runner/bin/microvm-run"
  '';
in
writeShellApplication {
  name = "vm-run";
  runtimeInputs = [
    bash
    coreutils
    findutils
    gawk
    openssh
    passt
    procps
    util-linux
  ];
  text = ''
    declare -A runners=(
      ${lib.concatStrings (
        lib.mapAttrsToList (name: t: "[${lib.escapeShellArg name}]=${t.runner}\n") templates
      )}
    )
    declare -A seeds=(
      ${lib.concatStrings (
        lib.mapAttrsToList (name: t: "[${lib.escapeShellArg name}]=${lib.getExe t.seed}\n") (
          lib.filterAttrs (_: t: t.seed != null) templates
        )
      )}
    )
    state_root="''${XDG_CACHE_HOME:-$HOME/.cache}/vm-run"
    ssh_proxy=${systemd}/lib/systemd/systemd-ssh-proxy

    die() { echo "vm-run: $*" >&2; exit 1; }

    usage() {
      cat >&2 <<'EOF'
    usage: vm-run <template> [-p DIR[:ro]]... [--cpus N] [--mem SIZE] [-- COMMAND...]
                                            run COMMAND (default: a login shell); each DIR
                                            appears at /work/<its name>, the session starts
                                            in the first; SIZE as QEMU's -m takes it (8G)
           vm-run attach <id> [-- COMMAND...]    another session in a running VM
           vm-run mount [--ro] <id> DIR [NAME]   map DIR into a running VM at /work/NAME
           vm-run umount <id> NAME               unmap it
           vm-run ls                             VMs and their mapped directories
           vm-run stop <id>                      kill a VM
           vm-run templates                      template names
    EOF
      exit "''${1:-1}"
    }

    # ssh into instance dir $1, running the shell-quoted remote command $2.
    guest_ssh() {
      local dir=$1 remote=$2 tty=-T
      if [ -t 0 ] && [ -t 1 ]; then tty=-t; fi
      # -F /dev/null: no host ssh config, so no SendEnv, agent or forwarding.
      # The pty request carries TERM (RFC 4254 6.2), so it is set to a
      # common value rather than the host terminal's name.
      TERM=xterm-256color ssh -F /dev/null "$tty" \
        -i "$dir/key" -o IdentitiesOnly=yes \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR \
        -o ProxyCommand="$ssh_proxy vsock/$(cat "$dir/cid") 22" -o ProxyUseFdpass=yes \
        ${guestUser}@vm "$remote"
    }

    # The remote command of instance dir $1, which the guest user's shell
    # runs: start in the run's first mapped directory if it has one, then run
    # the remaining words (quoted with printf %q, which bash and zsh both
    # read) or a login shell.
    remote_command() {
      local dir=$1; shift
      # $SHELL is expanded by the guest's shell, not here.
      # shellcheck disable=SC2016
      local cmd='exec "$SHELL" -l'
      if [ "$#" -gt 0 ]; then cmd="exec $(printf '%q ' "$@")"; fi
      local first
      first=$(awk -F'\t' 'NR == 1 { print $1 }' "$dir/mounts")
      if [ -n "$first" ]; then cmd="cd $(printf '%q' "${workMount}/$first") && $cmd"; fi
      printf '%s' "$cmd"
    }

    # pid is pasta's, which leads the run's process group (QEMU included).
    instance_alive() { [ -f "$1/pid" ] && kill -0 "$(cat "$1/pid")" 2>/dev/null; }
    instance_kill() { kill -- "-$(cat "$1/pid")" 2>/dev/null || true; }

    # The holder of instance dir $1 (see the top of packages/vm-run.nix).
    holder_pid() {
      local pid
      for pid in $(pgrep -f -- "^vm-run-holder:"); do
        if [ "$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | head -n 1)" = "vm-run-holder:$1" ]; then
          printf '%s' "$pid"
          return 0
        fi
      done
      die "no mount helper for $(basename "$1"); is it running?"
    }

    # Run a command in instance dir $1's mount namespace, as root of its user
    # namespace.
    in_mount_namespace() {
      # `|| exit`: callers run this in `if`, where errexit is off.
      local holder; holder=$(holder_pid "$1") || exit 1; shift
      nsenter -t "$holder" -U -m --preserve-credentials -- "$@"
    }

    # A name under /work: the given one or DIR's basename, which must be
    # usable as a single path component.
    mount_name() {
      local name=$1
      [[ $name =~ ^[A-Za-z0-9._-]+$ && $name != . && $name != .. ]] \
        || die "'$name' cannot be a name under ${workMount}; give one (letters, digits, . _ -)"
      printf '%s' "$name"
    }

    # The guest's CPU model, by host vendor: one of QEMU's named models, so
    # the guest sees the vendor (which KVM passes through anyway) and a name
    # every guest of that model shares, not the host's CPU. Both models are
    # old enough that current CPUs have all their features, and both include
    # the extensions binaries commonly require (AES-NI, PCLMULQDQ). On
    # aarch64, KVM needs the host model ("Named CPU models generally do not
    # work with KVM", QEMU docs/system/arm/cpu-features.rst), which the
    # runner already uses, so nothing is chosen.
    guest_cpu() {
      case $(uname -m) in
        x86_64) ;;
        aarch64) return 0 ;;
        *) die "vm-run supports x86_64 and aarch64 hosts only" ;;
      esac
      local vendor
      vendor=$(awk -F': ' '$1 ~ /^vendor_id/ { print $2; exit }' /proc/cpuinfo)
      case $vendor in
        GenuineIntel) printf 'Skylake-Client-v4' ;;
        AuthenticAMD) printf 'EPYC-v4' ;;
        *) die "no guest CPU model for vendor '$vendor'" ;;
      esac
    }

    instance_dir() {
      local dir="$state_root/$1"
      [ -d "$dir" ] || die "no VM '$1' (see vm-run ls)"
      printf '%s' "$dir"
    }

    # Delete instance dir $1 once its VM is gone. The mapped directories are
    # mounted only inside the VM's mount namespace, so here their mount
    # points are empty; rmdir, rather than a recursive delete, makes sure no
    # mapped directory's files could ever be removed.
    remove_instance_dir() {
      local dir=$1
      if [ -d "$dir/work" ]; then
        # find, not a glob: names may start with a dot (-p ~/.dotfiles).
        find "$dir/work" -mindepth 1 -maxdepth 1 -exec rmdir -- {} + \
          || die "a mount point in $dir/work is not empty; leaving $dir in place"
        rmdir -- "$dir/work"
      fi
      rm -rf -- "$dir"
    }

    # The EXIT trap of a run: stop its VM and delete its directory.
    run_dir=""
    cleanup_run() {
      if [ -n "$run_dir" ]; then
        if [ -f "$run_dir/pid" ]; then instance_kill "$run_dir"; wait 2>/dev/null || true; fi
        remove_instance_dir "$run_dir"
      fi
    }

    cmd_run() {
      local template=$1; shift
      local runner=''${runners[$template]:-}
      [ -n "$runner" ] || die "unknown template '$template' (have: ''${!runners[*]})"

      local cpus="" mem="" arg path mode name
      local -a mounts=()
      declare -A names=()
      while [ "$#" -gt 0 ]; do
        case $1 in
          -p) [ "$#" -ge 2 ] || usage; arg=$2; shift 2
            mode=rw
            if [[ $arg == *:ro ]]; then mode=ro; arg=''${arg%:ro}; fi
            path=$(realpath -e -- "$arg") || die "no such directory: $arg"
            [ -d "$path" ] || die "not a directory: $path"
            name=$(mount_name "$(basename "$path")")
            [ -z "''${names[$name]:-}" ] || die "two directories named '$name'; map one later with vm-run mount and a NAME"
            names[$name]=1
            mounts+=("$name"$'\t'"$mode"$'\t'"$path") ;;
          --cpus) [ "$#" -ge 2 ] || usage; cpus=$2; shift 2
            [[ $cpus =~ ^[1-9][0-9]*$ ]] || die "--cpus takes a positive number: $cpus" ;;
          --mem) [ "$#" -ge 2 ] || usage; mem=$2; shift 2
            [[ $mem =~ ^[1-9][0-9]*[MG]$ ]] || die "--mem takes a size such as 8G or 4096M: $mem" ;;
          --) shift; break ;;
          *) usage ;;
        esac
      done

      local cpu
      cpu=$(guest_cpu)

      # pasta forwards DNS to the host's first nameserver.
      local resolver
      resolver=$(awk '$1 == "nameserver" { print $2; exit }' /etc/resolv.conf)
      [ -n "$resolver" ] || die "no nameserver in /etc/resolv.conf"

      # A random 32-bit CID; 0-2 are reserved, 2^32-1 is VMADDR_CID_ANY.
      local cid
      cid=$(( $(od -An -N4 -tu4 /dev/urandom) % 4294967292 + 3 ))
      local id="$template-$cid"
      run_dir="$state_root/$id"
      local dir=$run_dir
      # QEMU splits -fsdev options on commas, and the runner splits its extra
      # arguments on whitespace; the shared directories sit in the run
      # directory.
      case $dir in *[,[:space:]]*) die "run directory path must not contain commas or whitespace: $dir" ;; esac
      mkdir -p "$state_root"
      mkdir -m 0700 "$dir" "$dir/work"
      echo "$cid" > "$dir/cid"
      : > "$dir/mounts"
      local entry
      for entry in "''${mounts[@]}"; do
        mkdir "$dir/work/''${entry%%$'\t'*}"
        printf '%s\n' "$entry" >> "$dir/mounts"
      done

      trap cleanup_run EXIT
      trap 'exit 130' INT TERM HUP

      ssh-keygen -q -t ed25519 -N "" -C "" -f "$dir/key"

      local seed=""
      if [ -n "''${seeds[$template]:-}" ]; then
        seed="$dir/seed"
        mkdir -m 0700 "$seed"
        "''${seeds[$template]}" "$seed" || die "seed program of '$template' failed"
      fi

      # setsid: pasta leads a new process group, so killing the group stops
      # pasta, QEMU and the holder together.
      VM_RUN_DIR=$dir VM_RUN_CID=$cid VM_RUN_SEED=$seed \
        VM_RUN_CPU=$cpu VM_RUN_CPUS=$cpus VM_RUN_MEM=$mem \
        setsid pasta --config-net --quiet --no-map-gw \
          -t none -u none -T none -U none \
          --dns-forward ${guestDns} --dns-host "$resolver" \
          -- ${inNamespace} "$runner" \
        > "$dir/console.log" 2>&1 &
      echo "$!" > "$dir/pid"

      # Boot takes a few seconds. sshd answers early (its vsock socket comes
      # from systemd's generator), so wait for the boot itself to finish:
      # templates prepare the user's environment in boot services.
      local tries=0
      until guest_ssh "$dir" 'systemctl is-system-running --wait >/dev/null; true' </dev/null >/dev/null 2>&1; do
        if ! instance_alive "$dir"; then
          tail -n 20 "$dir/console.log" >&2
          die "VM exited during boot"
        fi
        tries=$((tries + 1))
        if [ "$tries" -ge 120 ]; then
          tail -n 20 "$dir/console.log" >&2
          die "VM did not finish booting within 60 s"
        fi
        sleep 0.5
      done
      echo "vm-run: $id up" >&2

      local status=0
      guest_ssh "$dir" "$(remote_command "$dir" "$@")" || status=$?
      exit "$status"
    }

    cmd_attach() {
      [ "$#" -ge 1 ] || usage
      local dir; dir=$(instance_dir "$1"); shift
      instance_alive "$dir" || die "VM '$(basename "$dir")' is not running"
      if [ "''${1:-}" = "--" ]; then shift; fi
      guest_ssh "$dir" "$(remote_command "$dir" "$@")"
    }

    cmd_mount() {
      local mode=rw
      if [ "''${1:-}" = --ro ]; then mode=ro; shift; fi
      [ "$#" -ge 2 ] && [ "$#" -le 3 ] || usage
      local dir path name
      dir=$(instance_dir "$1")
      instance_alive "$dir" || die "VM '$(basename "$dir")' is not running"
      path=$(realpath -e -- "$2") || die "no such directory: $2"
      [ -d "$path" ] || die "not a directory: $path"
      name=$(mount_name "''${3:-$(basename "$path")}")
      ! awk -F'\t' -v n="$name" '$1 == n { found = 1 } END { exit !found }' "$dir/mounts" \
        || die "'$name' is already mapped in $(basename "$dir"); give another NAME"
      mkdir -- "$dir/work/$name"
      if ! in_mount_namespace "$dir" mount --bind -- "$path" "$dir/work/$name"; then
        rmdir -- "$dir/work/$name"
        die "could not map $path"
      fi
      if [ "$mode" = ro ]; then
        in_mount_namespace "$dir" mount -o remount,bind,ro -- "$dir/work/$name"
      fi
      printf '%s\t%s\t%s\n' "$name" "$mode" "$path" >> "$dir/mounts"
      echo "vm-run: $path -> ${workMount}/$name ($mode)" >&2
    }

    cmd_umount() {
      [ "$#" -eq 2 ] || usage
      local dir name=$2
      dir=$(instance_dir "$1")
      instance_alive "$dir" || die "VM '$(basename "$dir")' is not running"
      awk -F'\t' -v n="$name" '$1 == n { found = 1 } END { exit !found }' "$dir/mounts" \
        || die "'$name' is not mapped in $(basename "$dir")"
      in_mount_namespace "$dir" umount -- "$dir/work/$name"
      rmdir -- "$dir/work/$name"
      awk -F'\t' -v n="$name" '$1 != n' "$dir/mounts" > "$dir/mounts.new"
      mv -- "$dir/mounts.new" "$dir/mounts"
    }

    cmd_ls() {
      local dir
      for dir in "$state_root"/*/; do
        [ -d "$dir" ] || continue
        dir=''${dir%/}
        local state=running
        instance_alive "$dir" || state=stopped
        printf '%s\t%s\n' "$(basename "$dir")" "$state"
        if [ -f "$dir/mounts" ]; then
          awk -F'\t' '{ printf "  ${workMount}/%s\t%s\t%s\n", $1, $2, $3 }' "$dir/mounts"
        fi
      done
    }

    cmd_stop() {
      [ "$#" -eq 1 ] || usage
      local dir; dir=$(instance_dir "$1")
      if instance_alive "$dir"; then
        instance_kill "$dir"
        while instance_alive "$dir"; do sleep 0.2; done
      fi
      remove_instance_dir "$dir"
    }

    [ "$#" -ge 1 ] || usage
    case $1 in
      -h|--help) usage 0 ;;
      ls) shift; cmd_ls ;;
      attach) shift; cmd_attach "$@" ;;
      mount) shift; cmd_mount "$@" ;;
      umount) shift; cmd_umount "$@" ;;
      stop) shift; cmd_stop "$@" ;;
      templates) printf '%s\n' "''${!runners[@]}" | sort ;;
      *) cmd_run "$@" ;;
    esac
  '';
}
