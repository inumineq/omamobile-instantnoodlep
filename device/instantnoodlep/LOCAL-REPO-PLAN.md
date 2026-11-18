<!-- SPDX-License-Identifier: MIT -->
# LOCAL-REPO-PLAN: signed local package repository

Status: 2026-11-18, offline design and x86 tests only. Scope: let the owner
install the existing instantnoodlep Mesa, shell and device package builds from
a small local pacman repository, then let `[omamobile]` take over as upstream
versions catch up. No phone access, package installation, or upstream changes
are part of this work.

## 1. Package set and version policy

[V: `GPU-USERSPACE-PLAN.md` §5, `SHELL-UX-PLAN.md` §3/§10,
`packages/omamobile-device-instantnoodlep/{version,PKGBUILD}`] These are the
current local package versions and upstream baselines. The repository design
carries the Mesa split outputs plus patched shell and device package under one
`aarch64` path; `arch=any` shell packages share that path.

| Package | Local package version | Upstream baseline | Architecture |
|---|---:|---:|---|
| `mesa` | `1:26.2.4-1.5` | `1:26.2.4-1.4` | aarch64 |
| `vulkan-freedreno` | `1:26.2.4-1.5` | `1:26.2.4-1.4` | aarch64 |
| `vulkan-panfrost` | `1:26.2.4-1.5` | `1:26.2.4-1.4` | aarch64 |
| `vulkan-mesa-implicit-layers` | `1:26.2.4-1.5` | `1:26.2.4-1.4` | aarch64 |
| `omamobile-shell` | `0.2.133-1.2` | `0.2.133-1` | any |
| `omamobile-device-instantnoodlep` | `0.0.4-2` | none | aarch64 |

`tools/omamobile-localrepo-packages.tsv` is the local allowlist and version
contract. Never rebuild changed contents under an existing package version;
increase `pkgrel` (or `pkgver`) and update the manifest first. Mesa has epoch
1. The local shell release `1.2` includes shell UX patches 0001-0004 from
`SHELL-UX-PLAN.md`; package/device releases match their plan files. [I] The
ALARM rebuild commands and package hashes still need the owner's run.

On the phone, keep upstream `[omamobile]` before `[omamobile-local]` in
`/etc/pacman.conf`. Pacman gives earlier repositories precedence for packages
with identical names even if the later repo has a higher version [V: Arch
`pacman.conf(5)`, repository sections]. To deliberately select an override,
qualify the initial transaction as `omamobile-local/pkgname`; the installed
local version is greater than the recorded upstream baseline [V: table above].
`pacman -Syu` upgrades only when a newer sync version exists [V: Arch
`pacman(8)`, `--sysupgrade`]. Therefore an older upstream candidate cannot
replace the installed local build, and an upstream version greater than local
will win from the earlier repo. If upstream reaches the same version, confirm
its contents include the local change before removing the local repo entry and
reinstalling from `[omamobile]` explicitly. Do not rely on equal-version repo
ordering to replace an installed package. Recheck this policy whenever either
package version moves.

## 2. Repository and signing design

`tools/omamobile-localrepo` manages a workstation-only repository at
`$XDG_DATA_HOME/omamobile-localrepo/aarch64` by default. Commands initialize a
repo, create/export the owner's dedicated key, add or remove allowlisted
packages, and verify package plus database signatures. Package archives are
signed on the owner laptop after ALARM builds; `repo-add --sign --include-sigs --key` signs the repository database and
embeds adjacent package signatures. The key's
GnuPG home defaults to `$XDG_DATA_HOME/omamobile-localrepo/gnupg` (mode 0700),
outside git. The private key is never copied into a build container, phone,
repository, or PR. Export only the armored public key for phone provisioning.

Phone snippet, physically after `[omamobile]`:

```ini
[omamobile-local]
SigLevel = Required TrustedOnly
Server = file:///var/lib/omamobile/localrepo/$arch
```

`Required` applies to the database and package signatures. The owner imports
the public key into pacman's keyring and locally signs/trusts its fingerprint.
The repository is copied to `/var/lib/omamobile/localrepo/aarch64`; no signing
key or repo credentials are stored there. The tool does not edit phone config
or transfer files.

## 3. Rebuild recipes (owner workstation, ALARM container)

Use the pinned ALARM aarch64 container image and the existing in-container
build scripts; package signing always happens after the container exits.
Preserve existing source caches and compare versions/checksums with the plan
before replacing any archive. These are owner workstation commands; they were
not run for this PR.

Set a private build root and clone the source snapshot once:

```sh
R=$PWD
B=$HOME/orca/build-out/omamobile-localrepo
mkdir -p "$B/work" "$B/out" "$B/src"
git clone https://github.com/derekross/omarchy-mobile.git "$B/upstream"
git -C "$B/upstream" checkout c4623572be1c141d602cf99a83ae0bf9e3eea09c
```

1. **Mesa/freedreno:** apply the package patch at upstream root and stage its
   Mesa directory. The source-signing public keys used by the existing GPU
   recipe go into `/work/pgp.asc`; they verify Mesa source tarballs and are
   distinct from the local pacman-repository key.

   ```sh
   git -C "$B/upstream" apply --check "$R/device/instantnoodlep/patches/mesa-freedreno.patch"
   git -C "$B/upstream" apply "$R/device/instantnoodlep/patches/mesa-freedreno.patch"
   cp -a "$B/upstream/packages/mesa" "$B/work/mesa"
   cp "$R/device/instantnoodlep/tools/mesa-build-in-alarm.sh" "$B/build-in-container.sh"
   cp "$MESA_SOURCE_SIGNER_KEYS" "$B/work/pgp.asc"
   docker run --rm --platform linux/arm64 \
     -v "$B/work:/work" -v "$B/out:/out" -v "$B/src:/srcdest" \
     -v "$B/build-in-container.sh:/build.sh:ro" \
     alarm-aarch64:20260805-42a4eeaa bash /build.sh
   ```

   The output must contain `mesa`, `vulkan-freedreno`, `vulkan-panfrost`, and
   `vulkan-mesa-implicit-layers`, all at `1:26.2.4-1.5`; add all four archives
   to the repository.
2. **omamobile-shell:** prepare the package directory from the pinned checkout,
   apply all four local shell patches in order, and set `pkgrel=1.2` plus the
   local package description. This yields `0.2.133-1.2` after the recorded
   `0.2.133-1.1` build.

   ```sh
   mkdir -p "$B/shell/work" "$B/shell/out"
   for patch in "$R"/patches/000{1,2,3,4}-*.patch; do
     git -C "$B/upstream" apply --check "$patch"
     git -C "$B/upstream" apply "$patch"
   done
   cp -a "$B/upstream/packages/omamobile-shell" "$B/shell/work/omamobile-shell"
   # Set pkgrel=1.2 and the local pkgdesc in the staged PKGBUILD.
   cp "$R/device/instantnoodlep/tools/shellpkg-build-in-alarm.sh" "$B/shell/build-in-container.sh"
   docker run --rm --platform linux/arm64 \
     -v "$B/shell/work:/work" -v "$B/shell/out:/out" \
     -v "$B/shell/build-in-container.sh:/build.sh:ro" \
     alarm-aarch64:20260805-42a4eeaa bash /build.sh
   ```

   The package check must pass `test/all` plus QML checks and emit
   `omamobile-shell-0.2.133-1.2-any.pkg.tar.zst`.
3. **device package:** preserve the package test's repository-relative firmware
   map path in the staged tree; run the new ALARM container recipe.

   ```sh
   mkdir -p "$B/device/work/repo/packages" "$B/device/work/repo/device/instantnoodlep" "$B/device/out"
   cp -a "$R/packages/omamobile-device-instantnoodlep" "$B/device/work/repo/packages/"
   cp "$R/device/instantnoodlep/firmware.map" "$B/device/work/repo/device/instantnoodlep/firmware.map"
   cp "$R/device/instantnoodlep/tools/devicepkg-build-in-alarm.sh" "$B/device/build-in-container.sh"
   docker run --rm --platform linux/arm64 \
     -v "$B/device/work/repo:/work/repo" -v "$B/device/out:/out" \
     -v "$B/device/build-in-container.sh:/build.sh:ro" \
     alarm-aarch64:20260805-42a4eeaa bash /build.sh
   ```

   `test/all` must pass and emit
   `omamobile-device-instantnoodlep-0.0.4-2-aarch64.pkg.tar.zst`.

Only after all archive versions and package names match the manifest, create
the dedicated signing key once on the owner's laptop, export only its public
key, and assemble the repository:

```sh
tools/omamobile-localrepo init
tools/omamobile-localrepo keygen
# Export the printed fingerprint to a public-key file outside this checkout.
tools/omamobile-localrepo export-key <fingerprint> "$B/omamobile-localrepo.pub"
OMAMOBILE_LOCALREPO_KEY=<fingerprint> tools/omamobile-localrepo add \
  "$B"/out/*.pkg.tar.zst \
  "$B"/shell/out/omamobile-shell-0.2.133-1.2-any.pkg.tar.zst \
  "$B"/device/out/omamobile-device-instantnoodlep-0.0.4-2-aarch64.pkg.tar.zst
OMAMOBILE_LOCALREPO_KEY=<fingerprint> tools/omamobile-localrepo verify
```

Stop a build on a patch mismatch, changed version outside this table, failing
package check, missing source-verification key, or unexpected package set.
Keep previous signed archives for rollback; never rebuild changed contents
under the same package version.

## 4. Gated phone switch and rollback

All steps below are owner-attended and are not run by this task. They write
phone files and install packages in the rootfs, but never flash a partition.
Verify the existing USB SSH host key, announce any shell restart, and get the
owner's go before the first phone write and again before the package transaction.
Connection examples use the known USB SSH endpoint `root@172.16.42.1`.

1. **Read the baseline and preserve rollback packages.** On the phone, capture
   the exact package versions and pending upgrades, then copy one cached
   archive per installed local package into a dedicated rollback directory:

   ```sh
   pacman -Q mesa vulkan-freedreno vulkan-panfrost \
     vulkan-mesa-implicit-layers omamobile-shell \
     omamobile-device-instantnoodlep
   pacman -Qm
   pacman -Qu
   install -d -m 700 /root/omamobile-localrepo-rollback
   for name in mesa vulkan-freedreno vulkan-panfrost \
     vulkan-mesa-implicit-layers omamobile-shell \
     omamobile-device-instantnoodlep; do
     version=$(pacman -Q "$name" | awk '{print $2}')
     arch=$(pacman -Qi "$name" | awk -F ': ' '$1 == "Architecture" {print $2}')
     package=/var/cache/pacman/pkg/$name-$version-$arch.pkg.tar.zst
     test -s "$package" || exit 1
     cp -p -- "$package" /root/omamobile-localrepo-rollback/
   done
   test "$(find /root/omamobile-localrepo-rollback -maxdepth 1 -name '*.pkg.tar.zst' | wc -l)" -eq 6
   sha256sum /root/omamobile-localrepo-rollback/*.pkg.tar.zst
   ```

   Expect: six matching package rows, one archive per package, and recorded
   hashes. Stop if any cache archive is missing, any installed version differs
   from the planned target, `pacman -Qm` shows an unexpected package, or
   `pacman -Qu` lists unrelated pending upgrades. No writes before the owner
   approves archive capture; rollback is not needed yet.
2. **Verify and stage signed files.** On the workstation, run
   `OMAMOBILE_LOCALREPO_KEY=<fingerprint> tools/omamobile-localrepo verify` and
   independently display the fingerprint with GPG. After the owner approves
   the transfer, preserve repository symlinks while copying to phone `/tmp`,
   then copy the repository and public key into place:

   ```sh
   REPO_ROOT=${OMAMOBILE_LOCALREPO_ROOT:-${XDG_DATA_HOME:-$HOME/.local/share}/omamobile-localrepo}
   PUBKEY="$HOME/orca/build-out/omamobile-localrepo/omamobile-localrepo.pub"
   set -o pipefail
   tar -C "$REPO_ROOT" -cpf - aarch64 | \
     ssh root@172.16.42.1 'mkdir -p /tmp/omamobile-localrepo && tar -xpf - -C /tmp/omamobile-localrepo'
   scp "$PUBKEY" root@172.16.42.1:/tmp/omamobile-localrepo.pub
   scp device/instantnoodlep/pacman/omamobile-local.conf \
     root@172.16.42.1:/tmp/omamobile-local.conf
   ```

   Then on the phone:

   ```sh
   install -d -m 755 /var/lib/omamobile/localrepo
   cp -a /tmp/omamobile-localrepo/aarch64 /var/lib/omamobile/localrepo/
   install -m 644 /tmp/omamobile-localrepo.pub /root/omamobile-localrepo.pub
   ls -l /var/lib/omamobile/localrepo/aarch64/omamobile-local.db*
   ```

   Expect the `.db` and `.files` names to link to their signed `.tar.zst`
   databases, and every archive to have a matching `.sig`. Stop if transfer,
   hash, symlink, signature, or package-set checks differ. Remove only the
   temporary `/tmp/omamobile-localrepo*` staging files to roll back this step.
3. **Trust and configure.** Back up `/etc/pacman.conf` before editing. Add the
   public key, compare its full fingerprint against the workstation out of
   band, and locally trust it:

   ```sh
   cp -a /etc/pacman.conf /root/pacman.conf.pre-omamobile-localrepo
   pacman-key --add /root/omamobile-localrepo.pub
   pacman-key --finger <fingerprint>
   pacman-key --lsign-key <fingerprint>
   ```

   Copy the committed snippet to `/tmp/omamobile-local.conf`; insert it at the
   end of the existing `[omamobile]` section (immediately before the next
   `[...]` header), not inside that section. Keep its contents exact:
   `[omamobile-local]`, `SigLevel = Required TrustedOnly`, and
   `Server = file:///var/lib/omamobile/localrepo/$arch`. Insert it safely with
   this root-side command, which preserves the original file mode and refuses
   a duplicate section:

   ```sh
   python3 - /tmp/omamobile-local.conf /etc/pacman.conf <<'PY'
   import os
   import stat
   import sys
   from pathlib import Path

   snippet_path, config_path = map(Path, sys.argv[1:])
   lines = config_path.read_text().splitlines(keepends=True)
   if any(line.strip() == "[omamobile-local]" for line in lines):
       raise SystemExit("[omamobile-local] already exists; stop and inspect config")
   start = next((i for i, line in enumerate(lines) if line.strip() == "[omamobile]"), None)
   if start is None:
       raise SystemExit("[omamobile] section not found; stop")
   end = next((i for i in range(start + 1, len(lines)) if lines[i].lstrip().startswith("[")), len(lines))
   snippet = snippet_path.read_text().splitlines(keepends=True)
   original_mode = stat.S_IMODE(config_path.stat().st_mode)
   temp_path = config_path.with_name(config_path.name + ".localrepo-tmp")
   temp_path.write_text("".join(lines[:end] + ["\n"] + snippet + lines[end:]))
   os.chmod(temp_path, original_mode)
   os.replace(temp_path, config_path)
   PY
   ```

   Check
   `pacman-conf --repo-list` lists `[omamobile]` before
   `[omamobile-local]`; `pacman-conf omamobile-local SigLevel` reads
   `Required TrustedOnly`; and `pacman -Sy` accepts the signed database. This
   refresh must be followed immediately by the full transaction below; do not
   install after a standalone `-Sy`. Stop on signature, parse, ordering, or
   mirror errors. Before package installation, rollback by restoring the saved
   config and deleting the key only if it is not trusted elsewhere.
4. **Preview and install.** Review `pacman -Qu` and preview the complete
   transaction. Stop if any unexpected upgrade, downgrade, or removal appears.
   After the owner gives a second go, run one full system upgrade with explicit
   local package targets:

   ```sh
   pacman -Syu --print omamobile-local/mesa \
     omamobile-local/vulkan-freedreno omamobile-local/vulkan-panfrost \
     omamobile-local/vulkan-mesa-implicit-layers \
     omamobile-local/omamobile-shell \
     omamobile-local/omamobile-device-instantnoodlep
   # Owner reviews the printed transaction, then runs the same command without --print.
   pacman -Syu omamobile-local/mesa \
     omamobile-local/vulkan-freedreno omamobile-local/vulkan-panfrost \
     omamobile-local/vulkan-mesa-implicit-layers \
     omamobile-local/omamobile-shell \
     omamobile-local/omamobile-device-instantnoodlep
   ```

   Expect the target versions in §1, successful package signature checks, and
   `pacman -Dk` dependency validation. Confirm `pacman -Q` versions and that a
   second `pacman -Syu` does not propose downgrades. Stop on any signature,
   dependency, version, or shell-session error. Roll back as in step 5; no
   reboot is needed for repository configuration.
5. **Rollback.** If installation or smoke checks fail, use the six preserved
   exact archives as one transaction, then verify the original version list:

   ```sh
   pacman -U -- /root/omamobile-localrepo-rollback/*.pkg.tar.zst
   pacman -Q mesa vulkan-freedreno vulkan-panfrost \
     vulkan-mesa-implicit-layers omamobile-shell \
     omamobile-device-instantnoodlep
   ```

   Restore `/etc/pacman.conf`, remove the repository tree and public-key file,
   and delete the key from pacman's keyring only if it is not trusted elsewhere.
   Stop if any saved hash differs; do not substitute another package or reboot.
   The package rollback uses rootfs package management only, not a partition write.

## 5. Sources and offline validation

- [V] Arch pacman repository priority and signature policy:
  <https://man.archlinux.org/man/pacman.conf.5.en>
- [V] Arch `repo-add` signing and `--include-sigs` behavior:
  <https://man.archlinux.org/man/repo-add.8>
- [V] Arch `pacman -Syu` update behavior:
  <https://man.archlinux.org/man/pacman.8.en>

`tools/omamobile-localrepo test` builds dummy package archives under a temporary
x86 work directory, generates a throwaway GPG key there, signs the packages and
database, then verifies both signatures and metadata. It never invokes a phone,
uses the owner's GPG home, or writes under the repo. Also run `bash -n`,
ShellCheck, `scripts/trail-lite lint`, and `git diff --check`. No ARM package
build is part of repo-tool validation.
