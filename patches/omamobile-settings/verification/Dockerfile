# Throwaway archlinux container for the offline PAM verification of the
# omamobile-settings security patch. Build context layout (see README.md):
#   <stage>/Dockerfile            (this file)
#   <stage>/pam-verify.sh         (this directory's script)
#   <stage>/omamobile-settings/   (packages/omamobile-settings with the patch applied)
FROM archlinux:latest
RUN pacman -Syu --noconfirm --needed \
      base-devel git python openssl pam sudo polkit shadow ca-certificates shellcheck \
    && rm -rf /var/cache/pacman/pkg/*
# pamtester is not in the official repos; build it from the AUR.
RUN useradd -m builder
USER builder
WORKDIR /home/builder
RUN git clone --depth 1 https://aur.archlinux.org/pamtester.git \
    && cd pamtester && makepkg --noconfirm -s
USER root
RUN pacman -U --noconfirm /home/builder/pamtester/pamtester-*.pkg.tar.zst \
    && rm -rf /home/builder/pamtester /var/cache/pacman/pkg/*
COPY omamobile-settings /work/omamobile-settings
COPY pam-verify.sh /root/pam-verify.sh
# Install the helper and polkit policy exactly like the package `install` script.
RUN chmod 0755 /root/pam-verify.sh \
    && install -Dm755 /work/omamobile-settings/bin/credentials-helper /usr/lib/omamobile-settings/credentials-helper \
    && install -Dm755 /work/omamobile-settings/bin/verify-lock-pin /usr/lib/omamobile-settings/verify-lock-pin \
    && install -Dm644 /work/omamobile-settings/polkit/org.omamobile.settings.credentials.policy \
         /usr/share/polkit-1/actions/org.omamobile.settings.credentials.policy
CMD ["/bin/bash", "/root/pam-verify.sh"]
