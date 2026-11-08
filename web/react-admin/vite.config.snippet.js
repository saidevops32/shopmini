// Merge this `server` block into the vite.config.js that Vite generates.
// Local development against `kubectl port-forward` (see docs/STATUS.md). With path-based ingress
// (Phase 6) the browser talks to ONE origin, so no proxy and no CORS configuration is needed.
export default {
  server: {
    proxy: {
      '/api/auth': 'http://localhost:8081',
      '/api/catalogue': 'http://localhost:8082',
      '/api/checkout': 'http://localhost:8083',
    },
  },
}
