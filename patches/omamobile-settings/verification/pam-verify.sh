#!/bin/bash
# Offline PAM verification of the omamobile-settings security patch.
# Runs as root in a throwaway archlinux container. Throwaway accounts and
# throwaway secrets only. Prints a TAP-ish log; exits non-zero on any failure.
set -u
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "ok $PASS - $*"; }
fail() { FAIL=$((FAIL+1)); echo "not ok - $*"; }
try() { printf '%s\n' "$3" | pamtester "$1" "$2" authenticate >/dev/null 2>&1; }
expect_ok()   { if try "$1" "$2" "$3"; then pass "$4"; else fail "$4"; fi; }
expect_fail() { if try "$1" "$2" "$3"; then fail "$4"; else pass "$4"; fi; }
helper() { printf '%s' "$3" | PKEXEC_UID="$1" /usr/lib/omamobile-settings/credentials-helper "$2"; }
helper_ok() {
  local out; out=$(helper "$1" "$2" "$3")
  if [ "$out" = '{"ok":true}' ]; then pass "$4"; else fail "$4 (helper said: $out)"; fi
}
helper_err() {
  local out; out=$(helper "$1" "$2" "$3")
  if printf '%s' "$out" | grep -q '"ok": *false'; then pass "$4"; else fail "$4 (helper said: $out)"; fi
}

# Throwaway test secrets (container is destroyed afterwards).
PW='Throwaway-Pass-9f3aQ'
NEWPW='Throwaway-NewPass-7c1e'
PIN='1357'
PIN2='2468'
WRONG='0000'
PLAINPW='Plain-User-Pass-55'
LOCKPW='Lock-User-Pass-88'

# --- PAM fixture: the services an Omarchy system provides ---
cat >/etc/pam.d/system-auth <<'EOF'
#%PAM-1.0
auth required pam_unix.so
account required pam_unix.so
password required pam_unix.so sha512
EOF
cat >/etc/pam.d/system-local-login <<'EOF'
#%PAM-1.0
auth include system-auth
account include system-auth
EOF
cat >/etc/pam.d/omarchy-lock-password <<'EOF'
#%PAM-1.0
auth required pam_unix.so try_first_pass
account required pam_unix.so
EOF
# /etc/pam.d/sudo and /usr/lib/pam.d/polkit-1 (PAM's factory fallback dir) come from the distro packages.
install -d -m 0755 /var/run/faillock
LOCK=/etc/pam.d/omarchy-lock-password
ORIG_SHA=$(sha256sum "$LOCK" | cut -d' ' -f1)
echo "== distro sudo/polkit PAM services in use =="
sed 's/^/    /' /etc/pam.d/sudo
echo "    ---"
sed 's/^/    /' /usr/lib/pam.d/polkit-1

useradd -m pinuser
useradd -m plainuser
useradd -m lockuser
printf 'pinuser:%s\nplainuser:%s\nlockuser:%s\n' "$PW" "$PLAINPW" "$LOCKPW" | chpasswd
PINUID=$(id -u pinuser); LOCKUID=$(id -u lockuser)
echo "== fixture: pinuser uid=$PINUID primary group $(id -gn pinuser) (private: $([ "$(id -gn pinuser)" = pinuser ] && echo yes)) =="

echo "== option OFF (default): nothing changes =="
expect_ok   omarchy-lock-password pinuser "$PW"    "off: account password authenticates the lock-screen service"
expect_fail omarchy-lock-password pinuser "$PIN"   "off: a separate PIN does NOT unlock the lock-screen service"
expect_ok   sudo  pinuser "$PW"   "off: sudo accepts the account password"
expect_fail sudo  pinuser "$PIN"  "off: sudo rejects the PIN"
expect_ok   polkit-1 pinuser "$PW"   "off: polkit accepts the account password"
expect_fail polkit-1 pinuser "$PIN"  "off: polkit rejects the PIN"
helper_ok "$PINUID" set-keypad '{"enabled":true}'  "off: keypad toggle on (no PAM change)"
[ -f /home/pinuser/.local/state/omarchy/toggles/lock-keypad ] && pass "off: keypad toggle file created" || fail "off: keypad toggle file created"
helper_ok "$PINUID" set-keypad '{"enabled":false}' "off: keypad toggle off"
[ "$(sha256sum "$LOCK" | cut -d' ' -f1)" = "$ORIG_SHA" ] && pass "off: lock PAM file untouched by keypad toggle" || fail "off: lock PAM file changed by keypad toggle"
[ ! -e /etc/omamobile/lock-pin-users ] && pass "off: no lock-pin roster created" || fail "off: lock-pin roster exists"

echo "== default single-secret mode: set-pin changes the account password =="
helper_ok "$PINUID" set-pin '{"secret":"9876","confirm":"9876"}' "default: set-pin accepted"
expect_ok   omarchy-lock-password pinuser 9876  "default: new PIN (= account password) unlocks the lock service"
expect_ok   sudo pinuser 9876                    "default: the same PIN works for sudo (single secret)"
expect_fail omarchy-lock-password pinuser "$PW"  "default: old password rejected on the lock service"
helper_ok "$PINUID" set-account-password "{\"secret\":\"$PW\",\"confirm\":\"$PW\"}" "default: account password restored"
expect_ok sudo pinuser "$PW" "default: sudo accepts the restored password"

echo "== option ON: separate lock-screen PIN =="
helper_ok "$PINUID" set-separate-pin "{\"secret\":\"$PIN\",\"confirm\":\"$PIN\"}" "on: set-separate-pin accepted"
STAT=$(stat -c '%u:%g:%a' "/var/lib/omamobile/lock-pin/$PINUID")
[ "$STAT" = "0:$(id -g pinuser):640" ] && pass "on: PIN hash root-owned, private primary group, mode 0640 ($STAT)" || fail "on: PIN hash perms ($STAT)"
grep -qx "$PINUID" /etc/omamobile/lock-pin-users && pass "on: uid added to /etc/omamobile/lock-pin-users" || fail "on: roster missing uid"
[ -f /etc/pam.d/.omarchy-lock-password.omamobile-backup ] && pass "on: stock lock PAM saved as backup" || fail "on: backup missing"
echo "== rendered lock PAM service =="
sed 's/^/    /' "$LOCK"
expect_ok   omarchy-lock-password pinuser "$PIN"   "on: PIN unlocks the lock-screen PAM service"
expect_fail omarchy-lock-password pinuser "$PW"    "on: account password does NOT fall through on the lock service (two-secret)"
expect_fail sudo  pinuser "$PIN"  "on: sudo rejects the PIN"
expect_ok   sudo  pinuser "$PW"   "on: sudo accepts the account password"
expect_fail polkit-1 pinuser "$PIN" "on: polkit rejects the PIN"
expect_ok   polkit-1 pinuser "$PW"  "on: polkit accepts the account password"
expect_ok   omarchy-lock-password plainuser "$PLAINPW" "on: non-opted-in account keeps password auth on the lock service"
expect_fail omarchy-lock-password plainuser "$PIN"    "on: non-opted-in account rejects the PIN"

echo "== account password change while separate PIN is on =="
helper_ok "$PINUID" set-account-password "{\"secret\":\"$NEWPW\",\"confirm\":\"$NEWPW\"}" "on: account password change accepted"
expect_ok   sudo pinuser "$NEWPW" "on: sudo accepts the new account password"
expect_fail sudo pinuser "$PW"   "on: sudo rejects the old account password"
expect_ok   omarchy-lock-password pinuser "$PIN"   "on: lock PIN still works after password change"
expect_fail omarchy-lock-password pinuser "$NEWPW" "on: new account password does not unlock the lock service"

echo "== ten wrong tries lock out (lockuser) =="
helper_ok "$LOCKUID" set-separate-pin "{\"secret\":\"$PIN2\",\"confirm\":\"$PIN2\"}" "lockout user: separate PIN set"
expect_ok omarchy-lock-password lockuser "$PIN2" "lockout user: correct PIN works before any failure"
for i in $(seq 1 10); do try omarchy-lock-password lockuser "$WRONG"; done
pass "lockout user: 10 wrong PIN attempts all rejected"
expect_fail omarchy-lock-password lockuser "$PIN2" "after 10 wrong tries the correct PIN is locked out (deny=10)"
[ -f /var/run/faillock/lockuser ] && pass "faillock tally recorded for lockout user" || fail "faillock tally missing"

echo "== opt-out of one user while another stays opted in =="
helper_ok "$PINUID" use-account-password '{"enabled":true}' "pinuser opt-out accepted"
[ ! -e "/var/lib/omamobile/lock-pin/$PINUID" ] && pass "pinuser opt-out: PIN hash removed" || fail "pinuser opt-out: PIN hash left behind"
expect_ok   omarchy-lock-password pinuser "$NEWPW" "pinuser opt-out: account password works on the lock service again"
expect_fail omarchy-lock-password pinuser "$PIN"  "pinuser opt-out: the separate PIN no longer unlocks the lock service"
expect_ok   sudo pinuser "$NEWPW" "pinuser opt-out: sudo still uses the account password"
grep -qx "$LOCKUID" /etc/omamobile/lock-pin-users && pass "lockuser still in roster (multi-user)" || fail "lockuser missing from roster"
[ -f /etc/pam.d/.omarchy-lock-password.omamobile-backup ] && pass "backup kept while lockuser is opted in" || fail "backup removed too early"
[ "$(sha256sum "$LOCK" | cut -d' ' -f1)" != "$ORIG_SHA" ] && pass "lock PAM still rendered for the remaining user" || fail "lock PAM wrongly restored while lockuser opted in"
rm -f /var/run/faillock/lockuser
expect_ok omarchy-lock-password lockuser "$PIN2" "lockuser (still opted in) keeps PIN auth after pinuser's opt-out"

echo "== opt-out of the last user: full rollback to stock =="
helper_ok "$LOCKUID" use-account-password '{"enabled":true}' "lockuser opt-out accepted"
[ "$(sha256sum "$LOCK" | cut -d' ' -f1)" = "$ORIG_SHA" ] && pass "after last opt-out: lock PAM service byte-identical to stock" || fail "after last opt-out: lock PAM not restored"
[ ! -e /etc/pam.d/.omarchy-lock-password.omamobile-backup ] && pass "after last opt-out: backup removed" || fail "after last opt-out: backup left behind"
[ ! -e /etc/omamobile/lock-pin-users ] && pass "after last opt-out: roster removed" || fail "after last opt-out: roster left behind"
[ ! -e "/var/lib/omamobile/lock-pin/$LOCKUID" ] && pass "after last opt-out: lockuser PIN hash removed" || fail "lockuser PIN hash left behind"
expect_ok   omarchy-lock-password lockuser "$LOCKPW" "after last opt-out: account password works on the lock service again"
expect_fail omarchy-lock-password lockuser "$PIN2"  "after last opt-out: the separate PIN no longer unlocks the lock service"

echo "== helper validation (throwaway input only) =="
helper_err "$PINUID" set-separate-pin '{"secret":"12","confirm":"12"}' "3-digit PIN rejected"
helper_err "$PINUID" set-pin '{"secret":"1234","confirm":"9999"}' "mismatched confirm rejected"
out=$(printf '{"enabled":true}' | setpriv --reuid="$PINUID" --regid="$(id -g pinuser)" --clear-groups /usr/lib/omamobile-settings/credentials-helper set-keypad 2>/dev/null); rc=$?
[ "$rc" -ne 0 ] && pass "helper refuses to run unprivileged (pkexec required)" || fail "helper ran as non-root (rc=$rc, out=$out)"
helper_err 0 set-keypad '{"enabled":true}' "PKEXEC_UID=0 (root account) refused"

echo "== static checks inside the container =="
if shellcheck /work/omamobile-settings/omamobile-settings.install \
      /work/omamobile-settings/test/security-auth-container.sh \
      /work/omamobile-settings/test/security-static.sh; then
  pass "shellcheck clean on added shell scripts"
else
  fail "shellcheck findings"
fi
if python3 -m py_compile /work/omamobile-settings/bin/credentials-helper /work/omamobile-settings/bin/verify-lock-pin; then
  pass "py_compile clean on helper scripts"
else
  fail "py_compile failed"
fi
rm -rf /work/omamobile-settings/bin/__pycache__

echo
echo "RESULT: pass=$PASS fail=$FAIL"
[ "$FAIL" -eq 0 ]
