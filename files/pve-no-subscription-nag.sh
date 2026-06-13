#!/usr/bin/env bash
#
# Suppress the Proxmox VE "No valid subscription" login dialog in the web UI.
#
# Deployed and managed by the Ansible role nerdygriffin.proxmox_repositories.
# Designed to be safe to run repeatedly (idempotent) and to be called from an
# APT DPkg::Post-Invoke hook so the patch survives proxmox-widget-toolkit
# upgrades, which restore the stock proxmoxlib.js.
#
# Behaviour / exit contract (the Ansible task keys changed_when off "CHANGED"):
#   * prints "CHANGED ..."   and patches            -> a modification was made
#   * prints "UNCHANGED ..." and exits 0            -> nothing to do / safe no-op
#
# Reverting: restore "${JS}.orig" and
#   apt-get install --reinstall proxmox-widget-toolkit
#
set -euo pipefail

JS="/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js"
MARKER="nerdygriffin-nag-removed"

# Nothing to patch if the toolkit isn't installed (e.g. PBS, or a stripped host).
if [ ! -f "$JS" ]; then
  echo "UNCHANGED (proxmoxlib.js not present)"
  exit 0
fi

# Already patched — no-op (keeps the APT hook cheap and idempotent).
if grep -q "$MARKER" "$JS"; then
  echo "UNCHANGED (already patched)"
  exit 0
fi

# Version-safe guard: only proceed if the subscription dialog is actually here.
if ! grep -q "No valid subscription" "$JS"; then
  echo "UNCHANGED (subscription dialog not found; UI version may differ)"
  exit 0
fi

# Keep a one-time pristine backup.
[ -f "${JS}.orig" ] || cp -a "$JS" "${JS}.orig"

# The nag is opened by the Ext.Msg.show({ ... }) whose object literal has
# `title: gettext('No valid subscription'),` on the following line. Turning that
# call into void({ ... }) evaluates and discards the object, so no dialog opens.
# Anchoring on the unique title avoids touching the other Ext.Msg.show() calls.
perl -0777 -pi -e \
  "s/Ext\.Msg\.show\(\{(\s*\n\s*title: gettext\('No valid subscription'\),)/void({ \/*${MARKER}*\/\$1/g" \
  "$JS"

if grep -q "$MARKER" "$JS"; then
  echo "CHANGED (nag dialog suppressed)"
  exit 0
fi

echo "UNCHANGED (anchor not matched; left file intact)"
exit 0
