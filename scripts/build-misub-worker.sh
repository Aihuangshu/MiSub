#!/usr/bin/env bash
set -euo pipefail

restore() {
  git checkout -- \
    src/router/index.js \
    src/lib/http.js \
    src/lib/api.js \
    src/composables/useProfiles.js \
    src/views/PublicProfilesView.vue \
    src/components/modals/CopyLinkModal.vue \
    index.html
}
trap restore EXIT

python3 - <<'PY'
from pathlib import Path

def replace_once(path, old, new):
    p = Path(path)
    text = p.read_text()
    if old not in text:
        raise SystemExit("patch anchor not found: " + path)
    p.write_text(text.replace(old, new, 1))

def replace_line(path, prefix, new_line):
    p = Path(path)
    lines = p.read_text().splitlines()
    for i, line in enumerate(lines):
        if line.strip().startswith(prefix):
            lines[i] = new_line
            p.write_text("\n".join(lines) + "\n")
            return i
    raise SystemExit("line anchor not found: " + path)

def replace_line_after(path, start_index, contains, new_line):
    p = Path(path)
    lines = p.read_text().splitlines()
    for i in range(start_index + 1, len(lines)):
        if lines[i].strip().startswith("const link = ") and contains in lines[i]:
            lines[i] = new_line
            p.write_text("\n".join(lines) + "\n")
            return
    raise SystemExit("secondary line anchor not found: " + path)

replace_once(
    "src/router/index.js",
    "history: createWebHistory(),",
    "history: createWebHistory(import.meta.env.BASE_URL),",
)

replace_once(
    "src/lib/http.js",
    "let unauthorizedHandler = null;\n",
    """const APP_BASE_PATH = '/misub';

export function withAppBasePath(pathname) {
    if (typeof pathname !== 'string' || !pathname.startsWith('/')) return pathname;
    if (pathname === APP_BASE_PATH || pathname.startsWith(APP_BASE_PATH + '/')) return pathname;
    return APP_BASE_PATH + pathname;
}

export function stripAppBasePath(pathname) {
    if (typeof pathname !== 'string' || !pathname) return '/';
    if (pathname === APP_BASE_PATH) return '/';
    if (pathname.startsWith(APP_BASE_PATH + '/')) return pathname.slice(APP_BASE_PATH.length) || '/';
    return pathname;
}

const resolveRequestUrl = (url) =>
    typeof url === 'string' && url.startsWith('/') ? withAppBasePath(url) : url;

let unauthorizedHandler = null;
""",
)

replace_once(
    "src/lib/http.js",
    "    const response = await fetch(url, {",
    "    const requestUrl = resolveRequestUrl(url);\n    const response = await fetch(requestUrl, {",
)

replace_once(
    "src/lib/api.js",
    "import { api, APIError } from './http.js';",
    "import { api, APIError, stripAppBasePath } from './http.js';",
)

replace_once(
    "src/lib/api.js",
    "? { 'X-MiSub-Path': window.location.pathname }\n                : undefined;",
    "? { 'X-MiSub-Path': stripAppBasePath(window.location.pathname) }\n                : undefined;",
)

replace_once(
    "src/composables/useProfiles.js",
    "import { t } from '../i18n/index.js';",
    "import { t } from '../i18n/index.js';\nimport { withAppBasePath } from '../lib/http.js';",
)

first_profile_link = replace_line(
    "src/composables/useProfiles.js",
    "const link = " + chr(96),
    "        const link = window.location.origin + withAppBasePath('/' + token + '/' + identifier);",
)

replace_line_after(
    "src/composables/useProfiles.js",
    first_profile_link,
    "?target=clash&builtin=1",
    "        const link = window.location.origin + withAppBasePath('/' + token + '/' + identifier + '?target=clash&builtin=1');",
)

first_public_profile_link = replace_line(
    "src/views/PublicProfilesView.vue",
    "const link = " + chr(96),
    "            const link = window.location.origin + withAppBasePath('/' + token + '/' + identifier);",
)

replace_line_after(
    "src/views/PublicProfilesView.vue",
    first_public_profile_link,
    "/" + "token" + "/" + "identifier",
    "            const link = window.location.origin + withAppBasePath('/' + token + '/' + identifier);",
)

replace_once(
    "src/views/PublicProfilesView.vue",
    "    import { api } from '../lib/http.js';",
    "    import { api, withAppBasePath } from '../lib/http.js';",
)

replace_once(
    "src/components/modals/CopyLinkModal.vue",
    "    import { useToastStore } from '@/stores/toast';",
    "    import { useToastStore } from '@/stores/toast';\n    import { withAppBasePath } from '../../lib/http.js';",
)

replace_line(
    "src/components/modals/CopyLinkModal.vue",
    "return " + chr(96),
    "        return window.location.origin + withAppBasePath('/' + props.token + '/' + identifier.value);",
)

replace_once(
    "index.html",
    '  <link rel="icon" type="image/png" href="/logo.png" />',
    '  <base href="%BASE_URL%" />\n  <link rel="icon" type="image/png" href="%BASE_URL%logo.png" />',
)
PY

rm -rf dist
npx vite build --base=/misub/

echo "MiSub Worker overlay build completed."
