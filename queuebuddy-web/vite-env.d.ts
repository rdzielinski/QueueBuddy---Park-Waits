/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Base URL for the API. Defaults to same-origin "/api" (Pages Functions). */
  readonly VITE_API_BASE?: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
