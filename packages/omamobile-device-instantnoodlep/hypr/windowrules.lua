-- SPDX-License-Identifier: MIT
-- [I] Check modal, polkit, and portal window behavior in the morning survey.
-- Load after upstream's phone.lua so dialogs use the full usable workspace,
-- including its reduced height while the on-screen keyboard is visible.
hl.window_rule({ match = { modal = true }, float = false, maximize = true })
hl.window_rule({ match = { class = "^org\\.gnome\\.Nautilus$" }, float = false, maximize = true })
-- [I] Common polkit agent classes; retain modal matching for other agents.
hl.window_rule({ match = { class = "^(polkit-gnome-authentication-agent-1|org\\.kde\\.polkit-kde-authentication-agent-1)$" }, float = false, maximize = true })
