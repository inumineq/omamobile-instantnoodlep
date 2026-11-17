<!-- SPDX-License-Identifier: MIT -->
# Kona root-identity design

obsidian, `kona-root-design`, research an upstream-safe response to the SM8250 stock-DTBO root-compatible rewrite.

Scope: plan only in `device/instantnoodlep/KONA-ROOT-DESIGN.md`; no kernel
code or phone access. The stock DTBO is restored after ABL rejected both
neutral-DTBO experiments. Avoid treating the local `qcom,kona` test patch as
upstreamable without evidence that the alias is accepted by maintainers.
