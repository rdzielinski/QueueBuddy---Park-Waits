import { useMemo } from "react";
import { Link, useLocation, useParams, useSearchParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import {
  Area,
  AreaChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
  type TooltipProps,
} from "recharts";
import { api } from "../lib/api";
import { catalogEntry } from "../lib/catalog";
import { iconForType } from "../lib/attractionIcon";
import { parkBySlug } from "../lib/parks";
import { SplitFlap } from "../components/SplitFlap";
import { BoardMessage, LoadingFlaps } from "../components/States";
import { attractionTone, statusLabel, TONE_VAR } from "../lib/wait";
import { relativeTime } from "../lib/format";
import type { Attraction, HistoryRange } from "../lib/types";

const RANGES: HistoryRange[] = ["24h", "7d", "30d"];
const PARK_TZ = "America/New_York";

function tickFormatter(range: HistoryRange) {
  const opts: Intl.DateTimeFormatOptions =
    range === "24h"
      ? { timeZone: PARK_TZ, hour: "numeric" }
      : { timeZone: PARK_TZ, month: "numeric", day: "numeric" };
  const fmt = new Intl.DateTimeFormat("en-US", opts);
  return (ts: number) => fmt.format(new Date(ts));
}

const fullStamp = new Intl.DateTimeFormat("en-US", {
  timeZone: PARK_TZ,
  month: "short",
  day: "numeric",
  hour: "numeric",
  minute: "2-digit",
});

function ChartTooltip({ active, payload }: TooltipProps<number, string>) {
  if (!active || !payload || payload.length === 0) return null;
  const row = payload[0]?.payload as { ts: number; wait: number | null } | undefined;
  if (!row) return null;
  return (
    <div className="rounded-lg border border-board-line bg-board-bg px-3 py-2 text-xs shadow-lg">
      <div className="text-muted">{fullStamp.format(new Date(row.ts))}</div>
      <div className="tnum mt-0.5 font-mono text-sm text-flap-fg">
        {row.wait == null ? "Closed" : `${row.wait} min`}
      </div>
    </div>
  );
}

export function AttractionPage() {
  const { attractionId } = useParams<{ attractionId: string }>();
  const location = useLocation();
  const [searchParams, setSearchParams] = useSearchParams();

  const stateAttraction = (location.state as { attraction?: Attraction } | null)?.attraction;
  const parkSlug = searchParams.get("park") ?? stateAttraction?.parkId ?? undefined;
  const range = (searchParams.get("range") as HistoryRange) || "7d";
  const validRange = RANGES.includes(range) ? range : "7d";

  const park = parkBySlug(parkSlug);
  const meta = attractionId ? catalogEntry(attractionId) : undefined;

  // Refresh current status from the park's live feed (shares cache with ParkPage).
  const live = useQuery({
    queryKey: ["park-live", parkSlug],
    queryFn: ({ signal }) => api.getParkLive(parkSlug!, signal),
    enabled: Boolean(parkSlug),
    refetchInterval: 30_000,
  });

  const current: Attraction | null =
    live.data?.find((a) => a.id === attractionId) ?? stateAttraction ?? null;
  const name = searchParams.get("name") ?? current?.name ?? meta?.name ?? "";

  const history = useQuery({
    queryKey: ["history", name, validRange],
    queryFn: ({ signal }) => api.getHistory(name, validRange, signal),
    enabled: Boolean(name),
    staleTime: 60_000,
  });

  const chartData = useMemo(
    () =>
      (history.data ?? [])
        .map((p) => ({ ts: Date.parse(p.t), wait: p.wait }))
        .filter((p) => !Number.isNaN(p.ts)),
    [history.data],
  );

  const peak = useMemo(() => {
    let max = -1;
    for (const p of chartData) if (typeof p.wait === "number" && p.wait > max) max = p.wait;
    return max >= 0 ? max : null;
  }, [chartData]);

  const tone = current ? attractionTone(current) : "down";
  const operating = current?.status === "OPERATING";

  if (!name && !current) {
    return (
      <BoardMessage title="Pick a ride from the board.">
        Open an attraction from a park's board to see its wait history.{" "}
        <Link className="underline" to="/">Back to all parks</Link>.
      </BoardMessage>
    );
  }

  const setRange = (r: HistoryRange) => {
    const next = new URLSearchParams(searchParams);
    next.set("range", r);
    setSearchParams(next, { replace: true });
  };

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-4 border-b border-board-line pb-5">
        <Link
          to={park ? `/park/${park.slug}` : "/"}
          className="w-fit text-sm text-muted transition-colors hover:text-flap-fg"
        >
          ← {park ? park.shortName : "All parks"}
        </Link>
        <div className="flex items-end justify-between gap-4">
          <div className="min-w-0">
            <h1 className="font-mono text-2xl font-bold leading-tight tracking-tight text-flap-fg sm:text-3xl">
              <span className="mr-2" aria-hidden="true">{iconForType(meta?.type)}</span>
              {name || "Attraction"}
            </h1>
            <p className="mt-1 text-sm text-muted">
              {[meta?.land, park?.name].filter(Boolean).join(" · ")}
            </p>
          </div>
          <div className="shrink-0 text-right">
            <div className="text-[10px] uppercase tracking-[0.12em] text-muted">Now</div>
            <div className="mt-1 flex items-center justify-end gap-1.5">
              {operating && current ? (
                <>
                  <SplitFlap
                    value={current.waitMinutes != null ? String(current.waitMinutes) : "—"}
                    width={3}
                    color={TONE_VAR[tone]}
                    className="text-4xl"
                  />
                  <span className="text-[10px] uppercase tracking-wide text-muted">min</span>
                </>
              ) : (
                <span className="text-lg font-medium uppercase tracking-wide text-status-down">
                  {current ? statusLabel(current.status) : "—"}
                </span>
              )}
            </div>
            {current?.lastUpdated && (
              <div className="mt-1 text-[11px] text-muted">{relativeTime(current.lastUpdated)}</div>
            )}
          </div>
        </div>
      </header>

      <section className="flex flex-col gap-4 rounded-xl border border-board-line bg-board-surface p-4 sm:p-5">
        <div className="flex items-center justify-between gap-3">
          <div>
            <h2 className="text-sm font-semibold text-flap-fg">Wait history</h2>
            {peak != null && (
              <p className="tnum mt-0.5 font-mono text-xs text-muted">
                Peak this window · {peak} min
              </p>
            )}
          </div>
          <div className="flex gap-1 rounded-lg border border-board-line p-0.5">
            {RANGES.map((r) => (
              <button
                key={r}
                type="button"
                onClick={() => setRange(r)}
                className={`rounded-md px-2.5 py-1 font-mono text-xs transition-colors ${
                  r === validRange
                    ? "bg-white/10 text-flap-fg"
                    : "text-muted hover:text-flap-fg"
                }`}
                aria-pressed={r === validRange}
              >
                {r}
              </button>
            ))}
          </div>
        </div>

        <div className="h-[260px] w-full">
          {history.isPending ? (
            <LoadingFlaps width={5} label="Pulling history…" />
          ) : history.isError ? (
            <BoardMessage title="History's offline." onRetry={() => history.refetch()}>
              Couldn't load past waits for this attraction.
            </BoardMessage>
          ) : chartData.length === 0 ? (
            <BoardMessage title="No history yet.">
              The board hasn't logged enough samples for this window.
            </BoardMessage>
          ) : (
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={chartData} margin={{ top: 8, right: 8, bottom: 0, left: -16 }}>
                <defs>
                  <linearGradient id="waitFill" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="0%" stopColor="var(--color-wait-med)" stopOpacity={0.35} />
                    <stop offset="100%" stopColor="var(--color-wait-med)" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid stroke="var(--color-board-line)" vertical={false} />
                <XAxis
                  dataKey="ts"
                  type="number"
                  scale="time"
                  domain={["dataMin", "dataMax"]}
                  tickFormatter={tickFormatter(validRange)}
                  stroke="var(--color-muted)"
                  fontSize={11}
                  minTickGap={32}
                  tickLine={false}
                />
                <YAxis
                  stroke="var(--color-muted)"
                  fontSize={11}
                  width={40}
                  allowDecimals={false}
                  tickLine={false}
                  axisLine={false}
                />
                <Tooltip content={<ChartTooltip />} />
                <Area
                  type="monotone"
                  dataKey="wait"
                  stroke="var(--color-wait-med)"
                  strokeWidth={2}
                  fill="url(#waitFill)"
                  connectNulls={false}
                  dot={false}
                  isAnimationActive={false}
                />
              </AreaChart>
            </ResponsiveContainer>
          )}
        </div>
      </section>
    </div>
  );
}
