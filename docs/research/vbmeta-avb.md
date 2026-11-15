<!-- SPDX-License-Identifier: MIT -->
# Research: vbmeta and AVB on an unlocked Qualcomm ABL

Ticket #10: "vbmeta/AVB handling on an unlocked Qualcomm ABL" (grilling,
blocked). This note prepares that ticket. It does not decide it, and it
authorises no command on the phone. Research date: 2026-11-16.

Evidence marks: **[V]** means checked against the cited source.
**[I]** means an inference still to check on instantnoodlep. A statement
about generic Qualcomm ABL is [V] only for that source, never for OnePlus's
closed ABL fork.

## 0. Safety boundary and source pins

- [V] No `vbmeta` partition on either slot is writable for this work.
  Upstream's never-flash list names `vbmeta`, alongside slot A, bootloader,
  radio and calibration partitions
  ([UP/CONTRIBUTING.md#L55-L63](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/CONTRIBUTING.md#L55-L63)).
  The local draft is wrong where it says `BOOT_IMAGES="boot dtbo vbmeta"`
  and `UFS_RW="boot_b dtbo_b vbmeta_b userdata"`
  (`device/instantnoodlep/device.conf:64-69`). The M1a proposal already has
  `BOOT_IMAGES=""` and `UFS_RW=""`; M1b should carry `vbmeta` nowhere
  (`device/instantnoodlep/BRINGUP-M1-PLAN.md:335-362`).
- [V] M1a is RAM-only. It permits no flash, erase or slot change
  (`device/instantnoodlep/BRINGUP-M1-PLAN.md:26-55`). M1b also needs the
  separate slot-B/GPT decision (`docs/research/gpt-exception-prep.md:1-14`).
  Nothing here weakens either gate.

Source abbreviations used below:

- `UP` = `derekross/omarchy-mobile` at
  `6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4`.
- `Q` = the public generic Qualcomm `QcomModulePkg` mirror,
  `QRD-Development/abl` at
  `6922a8a066a6c75b4cbdfda73fc10e11d84e8763`. It is not OnePlus's ABL.
  Only its protocol and control flow are described; no code is copied.
- `AVB` = AOSP `platform/external/avb` at
  `3328b7b60ae384e1a92f44d7e6f3ac021c2b05be`.
- `AL25` = `bc-abe/omarchy-mobile` at
  `2a9b1cd37c46d1fc17c8004eb7fb9c54283ce02f`, the head of upstream PR #25.
- `PM` = `postmarketOS/pmaports` at
  `ce3ebdba08cdd09a6fb9a01da7d750f05638a25e`.
- `NU` = `naorunaoru/oneplus-instantnoodlep-nura-unofficial` at
  `65b22ce9f236d6249102b9791d469a0b69b0f08a`.

## 1. M1a: `fastboot boot` of an unsigned RAM image

### 1.1 Generic Qualcomm AVB2 path

**Short answer: [V] Generic Q: the downloaded RAM `boot` image is not checked
against a `vbmeta` hash descriptor. AVB as a whole is not skipped. [I] The
OnePlus SM8250 fork still has to prove the same behaviour.**

The call sequence in generic Q is:

1. [V] `CmdBoot` refuses a locked device. It puts the downloaded bytes in
   `Info.Images[0]`, sets the name to `boot`, and sets
   `Info.NumLoadedImages = 1`. It then calls the same `LoadImageAndAuth`
   dispatcher used for a normal boot
   ([Q/FastbootCmds.c#L2806-L2869](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/FastbootLib/FastbootCmds.c#L2806-L2869),
   [Q/LinuxLoader.c#L303-L319](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Application/LinuxLoader/LinuxLoader.c#L303-L319)).
2. [V] `LoadImageAndAuth` selects no-AVB, AVB1, AVB2 or LE according to the
   platform. The conclusions below are specifically for AVB2
   ([Q/VerifiedBoot.c#L1807-L1826](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1807-L1826)).
3. [V] `LoadImageAndAuthVB2` sets
   `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR` when `IsUnlocked()` is
   true. In its normal mission-boot branch it adds `boot` to the AVB request
   list **only if `NumLoadedImages` is zero**. It adds `dtbo` separately.
   For this header-v2 shape, the preload from step 1 therefore leaves a
   requested hash-partition list containing `dtbo`, not the RAM `boot` image
   ([Q/VerifiedBoot.c#L1131-L1163](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1131-L1163),
   [Q/VerifiedBoot.c#L1268-L1297](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1268-L1297)).
4. [V] libavb checks a hash descriptor only when its partition is in that
   request list. An unrequested descriptor returns success without loading or
   hashing that partition
   ([Q/libavb/avb_slot_verify.c#L101-L151](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L101-L151)).
   The preloaded RAM buffer is later reused as `boot`, rather than replaced
   by a copy read from flash
   ([Q/VerifiedBoot.c#L1345-L1404](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1345-L1404)).
5. [V] This is not an AVB bypass. `avb_slot_verify` still starts at top-level
   `vbmeta`, processes the requested `dtbo`, and follows chain descriptors.
   Chain-descriptor reads name on-flash partitions, not the downloaded RAM
   buffer ([Q/libavb/avb_slot_verify.c#L790-L872](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L790-L872),
   [Q/libavb/avb_slot_verify.c#L1483-L1505](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L1483-L1505)).
   The boot-image header and the separate DTBO rules still apply. The M1a
   plan's DTBO risk is therefore independent of this AVB result
   (`device/instantnoodlep/BRINGUP-M1-PLAN.md:196-237`).

[V] Generic Q also marks a successful unlocked AVB2 path orange. The flag
allows verification to continue; it does not promise a green state
([Q/VerifiedBoot.c#L1434-L1451](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1434-L1451)).

### 1.2 What is known for OnePlus SM8250

- [V] Current Nura instructions for instantnoodlep document persistent
  flashing, not a RAM boot (`NU/README.md#L39-L54`). They do not answer the
  M1a control-flow question
  ([NU/README.md#L39-L54](https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial/blob/65b22ce9f236d6249102b9791d469a0b69b0f08a/README.md#L39-L54)).
- [V] Our device-specific RAM test is stage-0 D3: a Magisk-patched stock boot
  image sent with `fastboot boot`. Its result is still pending in the M1
  plan (`docs/runbooks/STAGE-0-RUNBOOK.md:381-400`;
  `device/instantnoodlep/BRINGUP-M1-PLAN.md:15-16,127-129`).
- [I] D3 success would prove acceptance of that image. It would not by itself
  distinguish which AVB checks ran.
- [I] Expect generic Q's unsigned RAM-boot path to be the right working
  model for IN2023, but do not promote it to a device fact from other
  Qualcomm phones. An additional OnePlus authentication or metadata check is
  not ruled out by the public sources read here.

**M1a design consequence [I]:** use a plain header-v2 image with no AVB
footer first. A test-key signature on the RAM image has no effect on generic
Q's omitted RAM-hash check. Failure could still come from a OnePlus ABL
difference, image layout, DTB selection or DTBO handling.

## 2. M1b: custom `boot_b` beside stock `vbmeta_b`

### 2.1 A direct stock hash descriptor

[V] Generic Q: normal persistent boot has no preloaded image, so `boot` and
`dtbo` enter the AVB request list
([Q/VerifiedBoot.c#L1288-L1297](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1288-L1297)).
If stock `vbmeta_b` contains a hash descriptor for stock `boot`, replacing
`boot_b` changes the calculated digest and yields
`AVB_SLOT_VERIFY_RESULT_ERROR_VERIFICATION`
([Q/libavb/avb_slot_verify.c#L226-L258](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L226-L258)).

[V] Generic Q also requests `dtbo` in this header-v2 flow. A DTBO hash
mismatch follows the same verification-error path. Failure to read the
requested DTBO data is instead `ERROR_IO`
([Q/VerifiedBoot.c#L1295-L1297](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1295-L1297),
[Q/libavb/avb_slot_verify.c#L200-L214](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L200-L214)).
[I] Do not infer that an erased or unreadable `dtbo_b` is acceptable from the
boot-hash allow-errors result. The no-op DTBO design and its physical effect
remain a separate gate (`device/instantnoodlep/BRINGUP-M1-PLAN.md:196-247`).

[V] Generic Q: unlock changes that result from fatal to recoverable:

- AOSP specifies `ALLOW_VERIFICATION_ERROR` for unlocked devices. It makes
  public-key rejection, verification failure and rollback-index failure
  non-fatal ([AVB/README.md#L790-L808](https://android.googlesource.com/platform/external/avb/+/3328b7b60ae384e1a92f44d7e6f3ac021c2b05be/README.md#790-L808)).
- Q's own `ResultShouldContinue` admits exactly those three verification
  results plus `OK`. It rejects OOM, I/O, invalid metadata, unsupported
  version and invalid argument
  ([Q/VerifiedBoot.c#L741-L760](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L741-L760)).
- Q then accepts the loaded slot data, sets `ORANGE`, and continues the boot.
  A digest mismatch is therefore **orange-state boot**, not refusal and not
  green boot ([Q/VerifiedBoot.c#L1322-L1343](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1322-L1343),
  [Q/VerifiedBoot.c#L1434-L1442](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1434-L1442)).
- A hard error takes the error exit. For an A/B boot, generic Q marks the
  active slot unbootable and hands off to its slot-selection path
  ([Q/VerifiedBoot.c#L1498-L1522](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1498-L1522)).
  [I] Whether OnePlus presents that as fastboot, a red screen or a fallback
  boot must not be guessed.

### 2.2 A chain descriptor is different

[V] A chain descriptor delegates verification to metadata in the named
partition. Its footer locates that metadata. This lets `boot.img` change
without rewriting top-level `vbmeta`
([AVB/README.md#L65-L85](https://android.googlesource.com/platform/external/avb/+/3328b7b60ae384e1a92f44d7e6f3ac021c2b05be/README.md#65-L85)).

[V] Generic Q: libavb looks near the end of a chained partition for the
footer. With no footer it reads the partition start as a vbmeta candidate.
Ordinary Android boot bytes are not a valid vbmeta header, so this becomes
`ERROR_INVALID_METADATA`. That error is not allowed through in unlocked mode
([Q/libavb/avb_slot_verify.c#L455-L497](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L455-L497),
[Q/libavb/avb_slot_verify.c#L567-L595](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L567-L595),
[Q/VerifiedBoot.c#L741-L760](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L741-L760)).

[V] A structurally valid chained vbmeta signed by an untrusted test key gives
`ERROR_PUBLIC_KEY_REJECTED` when its key differs from the chain descriptor's
key. That error is recoverable in unlocked mode
([Q/libavb/avb_slot_verify.c#L617-L683](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L617-L683)).
This is why a footer can matter even when a wrong hash is tolerated.

### 2.3 Flags that matter

- [V] `AVB_SLOT_VERIFY_FLAGS_ALLOW_VERIFICATION_ERROR` is the relevant
  bootloader input. It is not a general "ignore all errors" switch
  ([Q/libavb/avb_slot_verify.h#L81-L117](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.h#L81-L117)).
- [V] `AVB_VBMETA_IMAGE_FLAGS_VERIFICATION_DISABLED` is top-level vbmeta bit
  1. It stops descriptor processing and loads requested partitions without
  their hash checks. `AVB_VBMETA_IMAGE_FLAGS_HASHTREE_DISABLED` is bit 0 and
  concerns runtime hashtree verification; it is not the switch that skips a
  `boot` hash descriptor ([Q/libavb/avb_vbmeta_image.h#L51-L62](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_vbmeta_image.h#L51-L62),
  [Q/libavb/avb_slot_verify.c#L752-L784](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L752-L784)).
- [V] Generic Q does not set `AVB_SLOT_VERIFY_FLAGS_NO_VBMETA_PARTITION` on
  its normal A/B mission-boot path. The flag appears in its special recovery
  case for non-A/B images
  ([Q/VerifiedBoot.c#L1224-L1236](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/VerifiedBoot.c#L1224-L1236)).
  Do not assume that a `boot_b` footer replaces stock top-level `vbmeta_b`.
- [V] A chained vbmeta must itself have flags zero. Nonzero flags there are
  invalid metadata. In particular, copying Lineage's top-level disable flags
  into a `boot` footer is not the footer design described here
  ([Q/libavb/avb_slot_verify.c#L598-L613](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L598-L613)).

[I] The generic result is a strong protocol model, not a guarantee for the
OnePlus build. R4 must first establish whether instantnoodlep has the direct
hash case, the chain case, or already-disabled verification.

## 3. Precedents, with their limits

### 3.1 Upstream omarchy-mobile

| Device | Checked precedent | What it does **not** prove |
| --- | --- | --- |
| Pixel 4 XL `coral` | [V] Its packer adds a 64 MiB `boot` hash footer with `--algorithm NONE` ([coral pack-bootimg.py#L304-L328](https://github.com/HemangKumawat/omarchy-mobile-coral/blob/78f77e861cfed7cbb57aea7eedc3c539ae1c8e81/tools/pack-bootimg.py#L304-L328)). | [V] This is **not** evidence for stock `vbmeta_b`; the experimental image was on `boot_a`, not `boot_b`. The notes say `vbmeta_a` had already been flashed with verification disabled, and explicitly call the stock-`vbmeta_b` case untested. The slot-B recipe itself was untested too ([UP/device/coral/BRINGUP-M1.md#L191-L210](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/coral/BRINGUP-M1.md#L191-L210)). |
| Pixel 4 `flame` | [V] Unlocked Android fastboot accepted a temporary U-Boot RAM stage, which then fastboot-booted Linux. Direct Linux boot images were rejected ([UP/device/flame/BRINGUP-M1.md#L44-L58](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/flame/BRINGUP-M1.md#L44-L58), [UP/device/flame/BRINGUP-M1.md#L127-L159](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/flame/BRINGUP-M1.md#L127-L159), [UP/device/flame/BRINGUP-M1.md#L182-L192](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/flame/BRINGUP-M1.md#L182-L192)). | [V] The notes do not isolate AVB as the reason for direct-image rejection and provide no persistent stock-`vbmeta_b` test. They support only a RAM-only chainloader fallback. |
| OnePlus 6 `enchilada` | [V] A custom header-v0 image ran from `boot_b`, and the port says it never writes `vbmeta`. Its RAM-only first light also worked ([UP/device/enchilada/NOTES.md#L28-L47](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/enchilada/NOTES.md#L28-L47), [UP/device/enchilada/NOTES.md#L134-L151](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/enchilada/NOTES.md#L134-L151), [UP/device/enchilada/NOTES.md#L169-L189](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/enchilada/NOTES.md#L169-L189)). | [I] This is not clean proof of stock, verification-on `vbmeta_b`: a third-party Android install preceded the port, and the notes contain no `avbtool info_image` baseline. It is a useful OnePlus precedent, not a descriptor-level control. |
| Xiaomi Mi 8 `dipper` | [V] The shipped path is deliberately RAM-only and keeps stock `dtbo` untouched; it has no persistent writer ([UP/device/dipper/BRINGUP-M1.md#L18-L21](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/dipper/BRINGUP-M1.md#L18-L21), [UP/device/dipper/BRINGUP-M1.md#L79-L81](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/device/dipper/BRINGUP-M1.md#L79-L81)). | [V] It answers no M1b question about a replaced persistent `boot_b` beside stock `vbmeta_b`. |
| POCO F3 `alioth`, PR #25 | [V] The proposed SM8250 builder emits plain `mkbootimg` output, with no AVB footer step. The installer writes `boot_b`, erases `dtbo_b`, and never writes `vbmeta` ([AL25/tools/alioth/build-boot.py#L38-L65](https://github.com/bc-abe/omarchy-mobile/blob/2a9b1cd37c46d1fc17c8004eb7fb9c54283ce02f/tools/alioth/build-boot.py#L38-L65), [AL25/tools/alioth/install.py#L57-L68](https://github.com/bc-abe/omarchy-mobile/blob/2a9b1cd37c46d1fc17c8004eb7fb9c54283ce02f/tools/alioth/install.py#L57-L68)). | [V] [PR #25](https://github.com/derekross/omarchy-mobile/pull/25) is closed and unmerged. Its notes say the independent source assembly had not had a clean physical reflash; existing-phone results came from the reference release ([AL25/device/alioth/BRINGUP-M1.md#L4-L8](https://github.com/bc-abe/omarchy-mobile/blob/2a9b1cd37c46d1fc17c8004eb7fb9c54283ce02f/device/alioth/BRINGUP-M1.md#L4-L8), [AL25/device/alioth/BRINGUP-M1.md#L121-L133](https://github.com/bc-abe/omarchy-mobile/blob/2a9b1cd37c46d1fc17c8004eb7fb9c54283ce02f/device/alioth/BRINGUP-M1.md#L121-L133)). It does not prove the exact new no-footer assembly on hardware. |

[V] Upstream's generic descriptor documentation already states the key
conditional: chain descriptors need a footer even when unlocked; direct hash
descriptors and disabled verification do not read that footer
([UP/docs/RELEASES.md#L78-L79](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/docs/RELEASES.md#L78-L79)).
That documentation agrees with the generic libavb control flow above. It is
not OnePlus SM8250 runtime evidence.

### 3.2 instantnoodlep: postmarketOS, Nura and Lineage

- [V] The current postmarketOS device package has no
  `deviceinfo_flash_fastboot_partition_vbmeta` entry. Its complete
  fastboot configuration names `super` for the rootfs and `dtbo` for DTBO,
  but no vbmeta write
  ([PM/deviceinfo#L17-33](https://gitlab.postmarketos.org/postmarketOS/pmaports/-/blob/ce3ebdba08cdd09a6fb9a01da7d750f05638a25e/device/testing/device-oneplus-instantnoodlep/deviceinfo#L17-33)).
- [V] The current Nura install writes `dtbo_a`, `boot_a` and `super`, with
  no `vbmeta` step. Its source-build sequence likewise runs only
  `flash_dtbo`, `flash_rootfs` and `flash_kernel`, not `flash_vbmeta`
  ([NU/README.md#L39-L54](https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial/blob/65b22ce9f236d6249102b9791d469a0b69b0f08a/README.md#L39-L54),
  [NU/README.md#L232-L249](https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial/blob/65b22ce9f236d6249102b9791d469a0b69b0f08a/README.md#L232-L249)).
  The same README reports the port working on one IN2023
  ([NU/README.md#L10-L28](https://github.com/naorunaoru/oneplus-instantnoodlep-nura-unofficial/blob/65b22ce9f236d6249102b9791d469a0b69b0f08a/README.md#L10-L28)).
- [I] Nura is the closest positive evidence that an unlocked IN2023 can boot
  custom `boot` content without a user-side vbmeta write. It is not a clean
  stock-`vbmeta_b` experiment: it uses slot A, replaces `super`, and records
  no stock vbmeta flags or descriptors. Do not copy its writes; only its
  no-vbmeta-write result is relevant.
- [V] Lineage takes the opposite route. Its SM8250 common configuration
  adds both `--set_hashtree_disabled_flag` and
  `--set_verification_disabled_flag` to generated vbmeta
  ([BoardConfigCommon.mk#L139-L147](https://github.com/LineageOS/android_device_oneplus_sm8250-common/blob/d772af0971b01a6b4f9b0d265a9476df494ef280/BoardConfigCommon.mk#L139-L147)).
  Its instantnoodlep metadata and install template flash both `dtbo.img` and
  `vbmeta.img` before recovery
  ([lineage_wiki instantnoodlep.yml#L1-L5](https://github.com/LineageOS/lineage_wiki/blob/f7633a607b32bf5bc636737db1a84ad1b7bff1df/_data/devices/instantnoodlep.yml#L1-L5),
  [before_recovery_install_boot_stack.md#L19-L27](https://github.com/LineageOS/lineage_wiki/blob/f7633a607b32bf5bc636737db1a84ad1b7bff1df/_includes/templates/device_specific/before_recovery_install_boot_stack.md#L19-L27)).
- [I] Lineage shows that a disabled-vbmeta installation exists and works as
  a supported recipe. It does not show that disabled vbmeta is necessary for
  every unsigned `boot`. Its Android userspace also has different dm-verity
  requirements from our native Arch root.
- [V] Lineage's vbmeta write is forbidden here by upstream's never-flash
  policy ([UP/CONTRIBUTING.md#L58-L60](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/CONTRIBUTING.md#L58-L60)).

## 4. Options without writing vbmeta

### 4.1 Option A: no footer; rely on unlocked allow-errors

**Use when R4 shows a direct `boot` hash descriptor, or top-level
verification already disabled. [I]**

Pros:

- [V] Generic Q tolerates a direct hash mismatch in unlocked mode and then
  boots orange (§2.1). Upstream explicitly says direct hash descriptors and
  disabled verification never read a boot footer
  ([UP/docs/RELEASES.md#L78-L79](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/docs/RELEASES.md#L78-L79)).
- [I] This is the smallest image change. It avoids full-partition padding,
  test-key handling, rollback metadata and another possible cause of ABL
  layout failures.
- [V] The no-vbmeta-write Nura route is a positive device precedent, subject
  to the limits in §3.2.

Cons:

- [V] It cannot fix the chained-no-footer invalid-metadata case (§2.2).
- [I] If OnePlus rejects a direct mismatch despite being unlocked, a footer
  would not repair the stock direct descriptor either. The remaining route
  would be to keep M1a RAM-only and return the decision to the maintainer;
  writing vbmeta is not the fallback.

### 4.2 Option B: test-key-signed AVB hash footer on `boot_b`

**Use only when R4 shows a chain descriptor for `boot`. [I]**

Pros:

- [V] It supplies the structure libavb needs for a chained partition. A
  correct hash descriptor covers the actual custom payload. The remaining
  test-key rejection is recoverable in generic unlocked AVB (§2.2).
- [V] Upstream already has the exact protocol: `AVB_FOOTERS` calls
  `avbtool add_hash_footer` with AOSP's public RSA4096 test key, a
  deterministic salt, the stock rollback index and stock OS/security-patch
  properties ([UP/bin/omamobile#L1098-L1120](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/bin/omamobile#L1098-L1120)).
  The descriptor requires those last two stock values
  ([UP/docs/RELEASES.md#L78-L79](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/docs/RELEASES.md#L78-L79)).
- [I] This needs no secret owner key and no vbmeta write. It is reproducible
  and reviewable offline.

Cons and required limits:

- [V] It adds no verified-boot security. It is a bootloader-compatibility
  structure signed by a public test key, not a trusted OnePlus signature.
- [V] It is normally padded so the 64-byte `AVBf` footer is at the end of the
  real boot partition ([AVB/avbtool.py#L4000-L4026](https://android.googlesource.com/platform/external/avb/+/3328b7b60ae384e1a92f44d7e6f3ac021c2b05be/avbtool.py#4000-L4026)).
  [I] Full-partition size and changed image layout are extra ABL risks; do
  not spend them on the direct-hash case where libavb never reads the footer.
- [V] Rollback index and security patch must come from stock. Never raise
  the rollback index above stock; upstream warns that doing so can lock stock
  images out ([UP/docs/RELEASES.md#L78-L79](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/docs/RELEASES.md#L78-L79)).
- [V] Do not put top-level disable flags in chained vbmeta; nonzero chained
  flags are invalid metadata (§2.3).
- [I] OnePlus could still impose a check not present in generic Q. Upstream's
  implementation is evidence for the protocol, not a device result.

### 4.3 Option C: unsigned `--algorithm NONE` footer

**Keep as a secondary experiment only for a chain descriptor. [I]**

- [V] AOSP returns `OK_NOT_SIGNED` for algorithm `NONE`; libavb maps that to
  `ERROR_VERIFICATION`, which unlocked mode may tolerate
  ([AVB/libavb/avb_vbmeta_image.c#L220-L224](https://android.googlesource.com/platform/external/avb/+/3328b7b60ae384e1a92f44d7e6f3ac021c2b05be/libavb/avb_vbmeta_image.c#220-L224),
  [Q/libavb/avb_slot_verify.c#L557-L579](https://github.com/QRD-Development/abl/blob/6922a8a066a6c75b4cbdfda73fc10e11d84e8763/QcomModulePkg/Library/avb/libavb/avb_slot_verify.c#L557-L579)).
- [V] Coral proves that this form can be built and booted after verification
  was disabled. It does not prove the stock-vbmeta case (§3.1).
- [I] It avoids key handling, but it has weaker upstream tooling and
  device-precedent support than option B. There is no present reason to
  prefer it over the existing test-key implementation.

### 4.4 Option D: remain RAM-only

**Fallback, not an M1b implementation. [I]**

- [V] Generic Q omits the RAM `boot` hash check (§1), and upstream enchilada,
  flame and dipper all have RAM-first precedents (§3.1).
- [I] This avoids every persistent vbmeta question and every persistent boot
  write. It costs a laptop-assisted boot every time and does not settle the
  persistent install. DTBO and the conditional GPT write remain separate M1a
  gates (`device/instantnoodlep/BRINGUP-M1-PLAN.md:196-247`).

## 5. What stage 0 already captures, and the best offline check

[V] Restore-assets R4 extracts `boot`, `dtbo`, `vbmeta` and, when present,
`vbmeta_system` from the owner-matched OTA. It runs:

- `unpack_bootimg.py` on stock `boot.img`, for header and geometry;
- `avbtool.py info_image --image images/vbmeta.img`, for top-level flags and
  descriptors;
- `mkdtboimg.py dump` on stock `dtbo.img`.

Source: `docs/runbooks/RESTORE-ASSETS.md:135-178`. R4 also says the vbmeta
output is the main input for this ticket and is not device-unique
(`docs/runbooks/RESTORE-ASSETS.md:170-179`). Stage-0 question 8 asks the same
thing (`docs/STAGE-0.md:57-63`).

**The single highest-value offline check is that R4
`avbtool info_image` on the exact stock `vbmeta.img`. [I]** Preserve its full
output and the avbtool version with the extracted-image hashes. Read it as:

| R4 result | Meaning from the checked AVB flow | Candidate design [I] |
| --- | --- | --- |
| `Hash Descriptor` for partition `boot` | [V] Replacing boot causes a recoverable verification error in generic unlocked AVB. The top-level direct descriptor is used, not a footer on our image. | [I] Option A: no footer. |
| `Chain Descriptor` for partition `boot` | [V] libavb follows it into `boot_b`; no valid footer is invalid metadata and fatal even unlocked. | [I] Option B first; C only as a secondary experiment. |
| Top-level `Flags` includes bit 1 (`VERIFICATION_DISABLED`; numeric bit value 2) | [V] Descriptors are not processed. | [I] No footer for hash verification. Keep the no-vbmeta-write boundary. |
| Top-level `Flags` has only bit 0 (`HASHTREE_DISABLED`; numeric bit value 1) | [V] Runtime hashtree behaviour changes, but the boot hash/chain question remains. | [I] Decide from the `boot` descriptor, not from this flag. |

[V] `avbtool info_image` is also the offline tool for stock `boot.img` when
the chain case is found. It exposes an existing footer and its metadata.
Upstream requires the stock rollback index and security patch for generated
footers ([UP/docs/RELEASES.md#L78-L79](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/docs/RELEASES.md#L78-L79)).
[I] That second inspection is conditional preparation for option B, not a
replacement for the first check. The direct-versus-chain answer still
settles the most.

[I] No offline inspection can prove every branch of the closed OnePlus ABL.
It can select the correct image shape and eliminate an unnecessary vbmeta
write. Actual RAM acceptance and persistent orange-state behaviour remain
runtime facts for their separate, owner-run gates.

## Decision inputs for ticket #10

1. **Descriptor correction [V]:** remove `vbmeta` from `BOOT_IMAGES` and
   `vbmeta_b` from `UFS_RW`. Do not add a disabled-vbmeta build or install
   step. The never-flash rule controls every slot
   (`device/instantnoodlep/device.conf:64-69`;
   [UP/CONTRIBUTING.md#L58-L60](https://github.com/derekross/omarchy-mobile/blob/6c11752ae4c3bc59f0c7a7fd3cacc12e65d3c0c4/CONTRIBUTING.md#L58-L60)).
2. **M1a [I]:** start with no AVB footer and no vbmeta write. Generic Q skips
   the downloaded boot image's hash check but still runs other AVB work.
   OnePlus RAM behaviour remains open until stage-0 D3 and the M1a probe.
3. **M1b, direct hash [I]:** start with no footer. Generic unlocked Q should
   warn orange and boot despite the stale stock digest. Do not infer a green
   boot, and do not treat hard metadata or I/O errors as recoverable.
4. **M1b, chain [I]:** use upstream's test-key-signed hash-footer protocol if
   R4 proves a chain descriptor. Take partition size, rollback index and
   security patch from stock. Leave footer flags zero. An unsigned footer is
   only a secondary experiment; coral is not stock-vbmeta evidence.
5. **Conditional, not decided [I]:** R4 chooses between inputs 3 and 4. If
   OnePlus refuses the direct-hash mismatch in unlocked mode, stay RAM-only
   and escalate the design. Do not solve that failure by writing vbmeta.
6. **Evidence still needed [I]:** exact stock `vbmeta_b` flags and descriptor
   types; any stock boot-footer metadata in the chain case; OnePlus's actual
   RAM-path behaviour; and its persistent behaviour for a direct mismatch or
   missing chain footer. Nura and all upstream precedents leave at least one
   of those facts unproven.
