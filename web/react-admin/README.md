# ShopMini web (React), UNTESTED starter

Only `src/App.jsx` and the proxy snippet are committed. Generate the project on a machine with Node:
    cd web
    npm create vite@latest react-admin-tmp -- --template react
    # copy the generated package.json, index.html, vite.config.js, src/main.jsx into react-admin/
    # (keep our src/App.jsx), merge vite.config.snippet.js into vite.config.js, then:
    cd react-admin && npm install && npm run dev
React escapes rendered text, so product names cannot inject HTML. Never use dangerouslySetInnerHTML here.

Honest scope: catalogue has no write API and there are no admin roles, so this page lists products and
shows only the logged-in user's own orders. Adding products needs a protected POST endpoint first.
