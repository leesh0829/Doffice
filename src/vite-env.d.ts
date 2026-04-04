/// <reference types="vite/client" />

import type { DofficeBridge } from "./types";

declare global {
  interface Window {
    doffice: DofficeBridge;
  }
}

export {};
