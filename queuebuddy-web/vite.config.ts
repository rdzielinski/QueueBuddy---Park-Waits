import { defineConfig, loadEnv } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";

// https://vite.dev/config/
export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");

  // `npm run dev` serves the Vite app only — the same-origin `/api/*` Pages
  // Functions don't run under Vite. Two ways to get live data in dev:
  //   1. Run the full stack with Functions:  npm run pages:dev
  //   2. Point the Vite dev server at a deployed API by setting VITE_API_PROXY
  //      (e.g. your Pages preview URL) — requests to /api/* get proxied there.
  const apiProxy = env.VITE_API_PROXY;

  return {
    plugins: [react(), tailwindcss()],
    server: apiProxy
      ? {
          proxy: {
            "/api": {
              target: apiProxy,
              changeOrigin: true,
              secure: true,
            },
          },
        }
      : undefined,
  };
});
