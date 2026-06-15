import type {
  Park,
  Attraction,
  HistoryPoint,
  HistoryRange,
  ParkSchedule,
} from "./types";

// In prod, calls go to same-origin /api/* and the Pages Functions in
// functions/ proxy/normalize the upstreams. In dev, either run the full stack
// (`npm run pages:dev`) or set VITE_API_PROXY to a deployed API.
const API_BASE = import.meta.env.VITE_API_BASE ?? "/api";

const ENDPOINTS = {
  parks: () => `/parks`,
  parkLive: (parkId: string) => `/parks/${encodeURIComponent(parkId)}/live`,
  parkSchedule: (parkId: string) => `/parks/${encodeURIComponent(parkId)}/schedule`,
  history: (name: string, range: HistoryRange) =>
    `/history?name=${encodeURIComponent(name)}&range=${range}`,
};

export class ApiError extends Error {
  constructor(
    public status: number,
    public path: string,
  ) {
    super(`API ${status} on ${path}`);
    this.name = "ApiError";
  }
}

async function get<T>(path: string, signal?: AbortSignal): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { accept: "application/json" },
    signal,
  });
  if (!res.ok) throw new ApiError(res.status, path);
  return (await res.json()) as T;
}

export const api = {
  getParks: (signal?: AbortSignal) => get<Park[]>(ENDPOINTS.parks(), signal),
  getParkLive: (parkId: string, signal?: AbortSignal) =>
    get<Attraction[]>(ENDPOINTS.parkLive(parkId), signal),
  getParkSchedule: (parkId: string, signal?: AbortSignal) =>
    get<ParkSchedule>(ENDPOINTS.parkSchedule(parkId), signal),
  getHistory: (name: string, range: HistoryRange, signal?: AbortSignal) =>
    get<HistoryPoint[]>(ENDPOINTS.history(name, range), signal),
};
