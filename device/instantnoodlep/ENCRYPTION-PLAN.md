<!-- SPDX-License-Identifier: MIT -->
# ENCRYPTION-PLAN: LUKS2 on instantnoodlep `userdata`

Status (2026-11-18): **design only. No code or phone changes have been made.** This plan adapts derekross/omarchy-mobile's [SECURITY-PLAN.md](https://github.com/derekross/omarchy-mobile/blob/main/docs/SECURITY-PLAN.md) to the OnePlus 8 Pro (`instantnoodlep`) port. The bootloader remains unlocked (orange state); this plan does not propose relocking it. It covers an encrypted root on `userdata`, the boot unlock path, a two-secret proposal for upstream, and preserving the current ext4 root during migration.

Evidence marks: **[V]** checked against a file, issue, or cited upstream document; **[I]** inference or a device fact that still needs a read-only check. Recommendations and proposed work are design choices, not claims of completed implementation.

## 1. Goal and credential model

| Use | Credential | Where it is checked |
| --- | --- | --- |
| Unlock LUKS2 at boot | Long passphrase | cryptsetup in the initramfs; input first through the existing USB-only dropbear session, later through the on-screen unlock UI |
| `sudo` and polkit | Same long passphrase | Normal account password/PAM |
| Lock screen | Short PIN | Separate lock-screen PAM service and a separate password hash; `faillock` locks it after 10 failed tries |

The on-screen boot prompt accepts the long passphrase only; the short PIN must never unlock or derive the LUKS key. The lock screen uses a dedicated PAM service such as `omarchy-lock-password`, configured to check its own hash and apply a 10-try lockout; it must not fall through to the account-password service. The long passphrase remains the account password for `sudo` and polkit. This is a proposal for upstream SECURITY-PLAN, not a change to upstream behavior.

Why split them: the upstream plan identifies offline guessing of a short PIN from a chip-off image as a weakness when the platform supplies no hardware-backed throttling [V: upstream SECURITY-PLAN.md §1, §4.3]. The split makes that PIN irrelevant to offline LUKS guessing. The repository's issue records that `/usr/bin/omamobile-set-pin` currently sets the account password and SSH is key-only [V: [issue #70](https://github.com/inumineq/omamobile-instantnoodlep/issues/70)]; the exact installed PAM and hash plumbing must be rechecked before implementation [I].

## 2. Threat model and limits

### Protects against

- A powered-off or rebooted phone stolen without its long passphrase: LUKS2 should protect the contents of the encrypted `userdata` [I: proposed behavior; not implemented or device-tested].
- Someone who can read the UFS storage offline: a long, high-entropy passphrase raises the cost of offline key guesses; the short lock PIN is not a disk key [I]. Use a strong passphrase and a calibrated LUKS2 PBKDF. A 10-try lock-screen limit does not throttle offline guesses.

### Does not protect against

- A bootloader-unlocked OnePlus 8 Pro lets an attacker with physical access boot or flash a modified boot image/initramfs. They can replace the unlock UI, capture a passphrase on the next boot, or alter the kernel before the encrypted root is opened [V: unlocked bootloader state is recorded in `device/instantnoodlep/NOTES.md:285`; consequence is inference [I]]. Encryption alone does not provide boot integrity. Keeping USB SSH in the initramfs also means a compromised initramfs or an untrusted laptop can capture the entered passphrase [I]. The current probe path generates a new dropbear host key each boot and disables known-host checking [V: `device/instantnoodlep/NOTES.md:426-430`], so it does not currently authenticate the phone to the laptop. Before sending a passphrase, implementation must add an independently verified per-boot host-key fingerprint or another reviewed channel; never treat `UserKnownHostsFile=/dev/null` as authenticated. Remove the SSH unlock path from any future locked release design unless separately reviewed.
- A phone that is already running with the root unlocked: key material is in RAM and the mounted files are available to root. A lock-screen PIN limits casual access; it is not protection against a kernel/root compromise [I].
- Data copied elsewhere before migration, including backups, swap, logs, or any old plaintext blocks that remain physically readable [I]. `luksFormat` does not prove secure erasure of old ext4 contents. UFS discard/secure erase behavior is unknown [I]; do not promise historical-data sanitization.
- Integrity of root data. LUKS2 encryption alone does not authenticate all sectors; dm-integrity is outside this first port proposal, consistent with upstream SECURITY-PLAN §4.4 [V].
- A weak or reused long passphrase, a forgotten passphrase with no recovery key, or an attacker who observes either secret [I]. Decide on a separately stored recovery key before implementation; do not store it on the phone.

## 3. Current facts and device constraints

- The port's current root is ext4 on `userdata`; the migration is destructive to that partition unless the backup is complete and verified [V: `device/instantnoodlep/STORAGE-M2-PLAN.md:59-73`; issue #70].
- Upstream's shared initramfs currently contains dropbear for USB SSH, per issue #70 [V: issue #70]. The local probe notes say its host key is newly generated each boot and the laptop uses `UserKnownHostsFile=/dev/null` [V: `device/instantnoodlep/NOTES.md:426-430`]. A separate host-authentication solution is a precondition for sending the disk passphrase [I].
- The slim kernel config is a delta from daily K3, not a complete `.config` [V: `device/instantnoodlep/kernel-slim.config:2-8`]; it currently has no encryption-specific entries [V: file scan]. The exact final symbols and their built-in/module status must be checked in the merged `.config` after adding the fragment [I].
- The ABL ceiling is `image_size` **0x2b60000**; larger tested images hang before USB, while the preferred slim target is **0x2560000** for 6 MiB headroom [V: `device/instantnoodlep/KERNEL-SIZE.md:34-38,152-154` and `.trail/learnings/2026-11-17-kernel-image-size-above-0x2b60000-hangs-claude.md`]. Encryption support must not push the image over the ceiling.
- The working device has slot B active and the Arch root on `userdata` [V: `docs/agents/state.md:35-37`]; the latest noted bootloader state is unlocked [V: `device/instantnoodlep/NOTES.md:285`]. A stock Android boot can erase the Arch root on `userdata` [V: learning `2026-11-17-a-stock-boot-can-erase-the-claude.md`]. Keep slot B active through migration and do not boot slot A with the encrypted `userdata` attached [I: operational consequence].

## 4. Design

### 4.1 Kernel crypto support

Add the required options to the instantnoodlep kernel configuration, then verify dependencies and the final merged config against the kernel tree's Kconfig (do not assume a symbol name or default from another kernel version):

- `CONFIG_BLK_DEV_DM=y` and `CONFIG_DM_CRYPT=y` for device mapper and dm-crypt.
- `CONFIG_CRYPTO_AES=y`, `CONFIG_CRYPTO_XTS=y`, and the selected ARM64 AES implementation/accelerator. Upstream records `CONFIG_CRYPTO_AES_ARM64_CE_BLK=y` in its reference config [V: upstream SECURITY-PLAN.md §2]; confirm the exact symbol and dependencies in this kernel tree before using it [I].
- Enable any hash/crypto providers cryptsetup's chosen LUKS2 setup requires, and retain the UFS, SCSI, block, and ext4 support already needed to find and mount `userdata`.
- Prefer built-in support for the initramfs path so unlock does not depend on loading modules from the still-encrypted root. If any required component is modular, include matching modules and dependencies in the initramfs and prove they load before `cryptsetup open`.

These are candidate requirements [I] until validated against the actual kernel tree and a built `.config`. Benchmark AES-XTS and the selected PBKDF on the phone before choosing a cost. Record both the kernel `Image` header `image_size` and initramfs size; hard stop if `image_size` exceeds `0x2b60000`, and target `0x2560000` or below [V: KERNEL-SIZE.md]. If crypto support exceeds the budget, remove unrelated built-in features with review; do not silently omit encryption support or boot an over-limit image.

### 4.2 Initramfs unlock path

1. Keep the existing initramfs storage guard and boot flow. Identify `userdata` by GPT `PARTNAME`, keep all unrelated partitions read-only, and do not mount the ext4 root before unlock [V: upstream initramfs flow summarized in `STORAGE-M2-PLAN.md` §1.3].
2. Include `cryptsetup` plus its runtime libraries, device-mapper tools/support, and any required crypto modules in the initramfs. Confirm the executable and dependencies are present in the generated cpio before any device boot [I].
3. Initial implementation: boot to initramfs, bring up the existing USB gadget and dropbear, authenticate with the owner's SSH key from a trusted laptop, and run `cryptsetup open` interactively on the `userdata` block device. Do not put the passphrase in a command argument, environment variable, shell history, or log. A PTY prompt over USB SSH is the temporary input route; do not expose dropbear on Wi-Fi [I].
4. Mount the mapped device as ext4, run filesystem checks/resizing against the mapping (never raw `userdata`), then continue the existing `switch_root` path [I]. Fail closed on missing mapper, wrong LUKS UUID, or failed filesystem check; never fall back to mounting raw `userdata` as ext4.
5. Later shared upstream work: add an on-screen passphrase entry UI in the initramfs. Keep USB SSH as an owner/debug mode only until touch input, screen privacy, retry behavior, and shell removal have been reviewed. The UI must not expose the entered secret in logs or kernel command line [I].

The two-secret lock-screen PAM service is a separate userspace change. It must use its own hash, impose a 10-try lockout, and not modify the long account password. Test lock, unlock, `sudo`, polkit, faillock reset policy, and account recovery before rollout [I].

## 5. Migration plan

The migration preserves the existing root by making and validating an off-device backup before any write. A successful backup is not enough: verify the archive contents and checksums, retain it outside the repository, and test that it can be read before reformatting. The source filesystem must be mounted read-only and unmounted before LUKS formatting. Confirm the actual `userdata` partition path, byte size, GPT label, and slot state from fresh read-only device data in the runbook; placeholders below must be filled in before the owner considers a write.

This runbook is a plan only. No command below has been run. Every write step requires a separate explicit owner go immediately before that step. No step writes `super` or an `_a` partition; all UFS writes are limited to `userdata`.

### Read-only preparation (no go required)

**P0 — Identify and inspect.** From the existing USB SSH session, record `PARTNAME`, partition size, ext4 UUID/label, mount state, active slot, and free laptop backup space. Use the established read-only stage-0/`STORAGE-M2-PLAN.md` procedures; do not guess `/dev/sdX` names. **Expect:** one `userdata` partition containing the current ext4 root and slot B active. **Stop:** ambiguous device, slot A active, dirty filesystem, or source mounted read-write. **Rollback:** none; no writes.

### Gated writes

**W1 — Read-only root backup over USB.** First boot the plan's guarded initramfs and independently verify its per-boot USB SSH host key; do not disable known-host checking. Mount `userdata` read-only (ext4 `ro,noload`) in the initramfs, then stream a numeric-owner archive to an off-repository laptop path:

```sh
# Phone/initramfs; {{USERDATA_PART}} is filled from P0, never guessed.
blockdev --getro {{USERDATA_PART}}
e2fsck -fn {{USERDATA_PART}}
mkdir -p /mnt/oldroot
mount -t ext4 -o ro,noload {{USERDATA_PART}} /mnt/oldroot
# On the laptop, receive through SSH after independently verifying the host key:
ssh -p {{USB_SSH_PORT}} root@{{USB_PHONE_IP}} \
  'tar --numeric-owner --xattrs --acls --sparse -C /mnt/oldroot -cpf - .' \
  > {{BACKUP_DIR}}/instantnoodlep-userdata-root.tar
sha256sum {{BACKUP_DIR}}/instantnoodlep-userdata-root.tar \
  > {{BACKUP_DIR}}/instantnoodlep-userdata-root.tar.sha256
sha256sum -c {{BACKUP_DIR}}/instantnoodlep-userdata-root.tar.sha256
```

**Owner go:** required before starting backup reads/streaming that consume the phone's USB session, as requested for this runbook. Independently verify the per-boot host key before sending any credential. **Expect:** ext4 check is clean or repair needs are understood; archive completes; checksum verifies; archive listing includes `/usr`, `/etc`, `/home`, permissions, xattrs and ACLs; backup is outside the repository. **Stop:** check reports errors, SSH host key is not verified, stream exits nonzero, checksum/listing fails, or backup storage is insufficient. **Rollback:** no partition changed; unmount `/mnt/oldroot`, preserve partial backup only for diagnosis, and return to the existing ext4 boot.

**W2 — Reformat `userdata` as LUKS2.** Unmount the read-only source, verify it is not mounted, recheck the exact partition and size against P0, and ask for a separate owner go. Use an interactive passphrase prompt; never place secrets in command arguments or logs.

```sh
umount /mnt/oldroot
findmnt {{USERDATA_PART}}   # must print no mount
# Human verifies device path, PARTNAME=userdata, and size again.
cryptsetup luksFormat --type luks2 --pbkdf argon2id \
  --cipher aes-xts-plain64 --key-size 512 {{USERDATA_PART}}
```

**Owner go:** required immediately before `luksFormat`; this destroys the current ext4 metadata. **Expect:** cryptsetup confirms LUKS2 format, then `cryptsetup luksDump` reports LUKS2, aes-xts-plain64, and the chosen PBKDF settings. **Stop:** any path/label/size mismatch, prompt is non-interactive, backup verification is absent, or format output differs. **Rollback:** stop; restoration requires a separate owner go before recreating ext4 on `userdata` and extracting the verified archive (W3), then boot the existing slot-B ext4 initramfs/kernel. The backup is the rollback source; do not attempt to recover the overwritten ext4 in place.

**W3 — Open, make ext4 in the mapper, restore.** This writes a new filesystem and restored files. Ask for a separate owner go. Ensure the target mapper is the only writable mapping for `userdata`.

```sh
cryptsetup open {{USERDATA_PART}} root
# Verify /dev/mapper/root resolves to the LUKS mapping on {{USERDATA_PART}}.
# Owner go now, immediately before this filesystem write:
mkfs.ext4 -L omamobile-root /dev/mapper/root
mount /dev/mapper/root /mnt/newroot
# Owner gives a second go immediately before the archive restore write.
# On the laptop, stream the verified archive back over the authenticated USB SSH session:
ssh -p {{USB_SSH_PORT}} root@{{USB_PHONE_IP}} \
  'tar --numeric-owner --xattrs --acls --sparse -C /mnt/newroot -xpf -' \
  < {{BACKUP_DIR}}/instantnoodlep-userdata-root.tar
sync
umount /mnt/newroot
cryptsetup close root
```

**Owner go:** required immediately before `mkfs.ext4`; obtain a second separate go immediately before the archive restore. `cryptsetup open` only creates the mapping; do not run `mkfs` until the mapper target is verified. **Expect:** mapper reports the expected LUKS UUID; ext4 is created on `/dev/mapper/root`; restored file count, ownership, modes, xattrs and ACLs match the backup; critical files compare by checksum; a read-only filesystem check passes. **Stop:** mapper is not backed by `userdata`, restore is incomplete, or any verification differs. **Rollback:** rollback also requires a separate owner go before reformatting `userdata` as ext4 and restoring from the verified archive; do not boot an incomplete root.

**W4 — RAM-boot and validate encrypted root.** After offline image/initramfs build checks, the owner gives a separate go before the boot. This command boots the image in RAM and writes no partition; it leaves slot B active and does not activate or boot slot A. A persistent slot-B install requires a separately approved, supported `qcom-abl` update path; the current upstream `bin/omamobile push` explicitly refuses that method [V: upstream `bin/omamobile:1311-1320`, read 2026-11-18].

```sh
fastboot boot {{BOOT_IMAGE}}
```

**Expect:** initramfs dropbear comes up only over USB; after independently verifying its host key, interactive cryptsetup unlock succeeds; root mounts only through `/dev/mapper/root`; Arch reaches the normal session. **Stop:** a wrong device/UUID, raw ext4 fallback, unlock loop, filesystem errors, host-key verification failure, or any request to write outside `userdata` and slot-B boot images. **Rollback:** reboot to fastboot and boot the previous known-good RAM image; if the root must be rebuilt, obtain separate owner go and restore from the laptop archive as W3. Keep the archive until multiple verified boots and a separate backup exist.

**W5 — Validate both credentials.** Once the system is booted and backed up, test the long passphrase at boot and for `sudo`/polkit, then test the short PIN only on the lock screen. Exercise 10 failed PIN attempts and verify lockout; verify the PIN cannot authenticate `sudo`, polkit, SSH, or LUKS. **Owner go:** required before installing/activating the PAM changes or rebooting. **Expect:** each credential is accepted only in its intended context and lockout works. **Stop:** shared hash/service, PAM fallback, lockout bypass, or recovery path failure. **Rollback:** restore the previous PAM/account configuration from the verified backup using USB SSH; keep the long password usable and do not enable unattended credential changes.

### Rollback boundary

Before W2, rollback is simply stop and retain the existing ext4. After W2, the ext4 root exists only in the external verified archive until restore is complete. If the archive is missing or corrupt, stop: do not format. After encryption, a boot failure is recoverable only while the owner retains the archive and a bootable slot-B initramfs capable of opening the LUKS mapping. Slot A stock may not understand encrypted `userdata` and may trigger recovery or erase it; do not boot slot A during migration [I].

## 6. Phases and upstream proposal

1. **P0, read-only facts:** confirm current initramfs dropbear contents/key handling, device-mapper and UFS behavior, exact root backup size, PAM service/hash behavior, and available recovery path.
2. **P1, offline kernel/initramfs work:** add config, cryptsetup packaging and mapper-aware init; measure kernel `image_size` and initramfs sizes; test on host images before any phone boot.
3. **P2, gated migration:** execute W1-W4 only with the owner's per-step go and a verified backup. W4 is RAM-only; a persistent slot-B install remains blocked on the upstream qcom-abl update path.
4. **P3, two-secret proposal:** send upstream a design proposal for the long disk/account passphrase plus a separate short lock-screen PIN hash/service with a 10-try lockout. Keep this proposal distinct from changing the upstream SECURITY-PLAN's default boot credential; no upstream posting is part of this plan.
5. **P4, on-screen boot entry:** implement after USB SSH unlock has been validated; share the UI design upstream.

## 7. Open questions [I]

1. What independent channel will authenticate the per-boot dropbear host key? The existing probe generates a new key each boot and disables known-host checks [V: `device/instantnoodlep/NOTES.md:426-430`]. Does the exact initramfs image bind dropbear only to USB?
2. Which crypto options are selected in the actual merged slim `.config`, which are needed by cryptsetup for LUKS2 on this kernel, and what is their built-in `Image` size cost?
3. Does the phone's UFS/ABL path expose `userdata` early enough for dm-crypt, and does its partition remain writable under the existing guard when the mapper is created?
4. Can the current initramfs run cryptsetup's LUKS2 Argon2id PBKDF with enough memory and acceptable latency? What measured time/memory settings are safe at boot?
5. Can the interactive PTY path avoid leaking the passphrase through command output, shell history, logs or crash dumps?
6. Does the exact ext4 root contain data outside a normal tar backup's coverage (ACLs, xattrs, capabilities, sparse files, hard links, special files), and can a restore be validated without losing system ownership/metadata?
7. How can prior plaintext blocks on UFS be treated after reformatting? No secure-erasure guarantee is assumed.
8. What is the supported recovery path if the long passphrase is forgotten? Should the design include a separately stored recovery key in a second LUKS keyslot?
9. Can the upstream lock-screen PAM stack maintain a dedicated PIN hash and independent `faillock` counter without allowing a fallback to the account password?
10. What exactly does Android stock do when booted from slot A with a LUKS2 `userdata` partition? Until confirmed, treat slot A as unsafe during and after migration.
11. What touch controller/input path is available before `switch_root`, and can the upstream on-screen passphrase UI be made reliable without exposing an initramfs shell?

## 8. Sources

- Upstream derekross/omarchy-mobile [`docs/SECURITY-PLAN.md`](https://github.com/derekross/omarchy-mobile/blob/main/docs/SECURITY-PLAN.md), read 2026-11-18; especially §§1, 4.3-4.4, 5, 7-9. This plan follows its LUKS2-first/development-mode direction and scopes the two-secret model as a proposal.
- This repository: issue [#70](https://github.com/inumineq/omamobile-instantnoodlep/issues/70); [`STORAGE-M2-PLAN.md`](STORAGE-M2-PLAN.md) §§1.2-1.3; [`kernel-slim.config`](kernel-slim.config); [`KERNEL-SIZE.md`](KERNEL-SIZE.md); [`BRINGUP-M1-PLAN.md`](BRINGUP-M1-PLAN.md); [`NOTES.md`](NOTES.md); [`docs/agents/state.md`](../../docs/agents/state.md); and the ABL ceiling learning in `.trail/learnings/`.
