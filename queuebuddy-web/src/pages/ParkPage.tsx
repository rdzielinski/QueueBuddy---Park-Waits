import { useMemo } from "react";
import { Link, useParams } from "react-router-dom";
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { landFor } from "../lib/catalog";
import { parkBySlug } from "../lib/parks";
import { WaitRow } from "../components/WaitRow";
import { BoardMessage, LoadingFlaps } from "../components/States";
import { SplitFlap } from "../components/SplitFlap";
import { TONE_VAR, waitTone } from "../lib/wait";
import type { Attraction } from "../lib/types";

function groupByLand(attractions: Attraction[]): [string, Attraction[]][] {
  const groups = new Map<string, Attraction[]>();
  for (const a of attractions) {
    const land = landFor(a.id);
    const list = groups.get(land) ?? [];
    list.push(a);
    groups.set(land, list);
  }

  const rank = (a: Attraction) => (a.status === "OPERATING" ? 0 : 1);
  for (const list of groups.values()) {
    list.sort((x, y) => {
      if (rank(x) !== rank(y)) return rank(x) - rank(y);
      const wx = x.waitMinutes ?? -1;
      const wy = y.waitMinutes ?? -1;
      if (wx !== wy) return wy - wx;
      return x.name.localeCompare(y.name);
    });
  }

  return [...groups.entries()].sort(([a], [b]) => {
    if (a === "More") return 1;
    if (b === "More") return -1;
    return a.localeCompare(b);
  });
}

export function ParkPage() {
  const { parkId } = useParams<{ parkId: string }>();
  const park = parkBySlug(parkId);

  const live = useQuery({
    queryKey: ["park-live", parkId],
    queryFn: ({ signal }) => api.getParkLive(parkId!, signal),
    enabled: Boolean(parkId && park),
    refetchInterval: 30_000,
  });

  const schedule = useQuery({
    queryKey: ["park-schedule", parkId],
    queryFn: ({ signal }) => api.getParkSchedule(parkId!, signal),
    enabled: Boolean(parkId && park),
    staleTime: 10 * 60_000,
    refetchInterval: 10 * 60_000,
  });

  const attractions = live.data ?? [];
  const operating = attractions.filter((a) => a.status === "OPERATING");
  const withWaits = operating.filter((a) => typeof a.waitMinutes === "number");
  const avg = withWaits.length
    ? Math.round(withWaits.reduce((s, a) => s + (a.waitMinutes ?? 0), 0) / withWaits.length)
    : null;

  const lands = useMemo(() => groupByLand(attractions), [attractions]);

  const hours = schedule.data?.today ?? park?.hours ?? null;
  const lanes = schedule.data?.lightningLane ?? [];

  if (!park) {
    return (
      <BoardMessage title="No such park.">
        That park isn't on the board. <Link className="underline" to="/">Back to all parks</Link>.
      </BoardMessage>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      <header className="flex flex-col gap-4 border-b border-board-line pb-5">
        <Link to="/" className="w-fit text-sm text-muted transition-colors hover:text-flap-fg">
          ← All parks
        </Link>
        <div className="flex items-end justify-between gap-4">
          <div>
            <h1 className="font-mono text-2xl font-bold tracking-tight text-flap-fg sm:text-3xl">
              {park.name}
            </h1>
            {hours && (
              <p className="mt-1 text-sm text-muted">
                Today {hours.open} – {hours.close}
              </p>
            )}
          </div>
          {live.isSuccess && (
            <div className="text-right">
              <div className="text-[10px] uppercase tracking-[0.12em] text-muted">Avg wait</div>
              <div className="mt-1 flex items-center justify-end gap-1.5">
                <SplitFlap
                  value={avg != null ? String(avg) : "—"}
                  width={3}
                  color={TONE_VAR[waitTone(avg)]}
                  className="text-3xl"
                />
                <span className="text-[10px] uppercase tracking-wide text-muted">min</span>
              </div>
              <div className="tnum mt-1 font-mono text-xs text-muted">
                {operating.length} / {attractions.length} open
              </div>
            </div>
          )}
        </div>

        {lanes.length > 0 && (
          <div className="flex flex-wrap gap-2">
            {lanes.map((ll) => (
              <span
                key={ll.id}
                className={`rounded-full border px-2.5 py-1 text-xs ${
                  ll.available
                    ? "border-wait-low/40 text-wait-low"
                    : "border-board-line text-muted line-through"
                }`}
                title={ll.available ? "Available" : "Sold out"}
              >
                {ll.name}
                {ll.price ? ` · ${ll.price}` : ""}
              </span>
            ))}
          </div>
        )}
      </header>

      {live.isPending ? (
        <LoadingFlaps label={`Reading ${park.shortName}…`} />
      ) : live.isError ? (
        <BoardMessage title="No live data — the board's dark right now." onRetry={() => live.refetch()}>
          Couldn't reach the feed for {park.name}.
        </BoardMessage>
      ) : attractions.length === 0 ? (
        <BoardMessage title="Nothing posted yet.">
          No attractions are reporting for {park.name} right now.
        </BoardMessage>
      ) : (
        <div className="flex flex-col gap-7">
          {lands.map(([land, rides]) => (
            <section key={land} className="flex flex-col gap-1">
              <h2 className="px-3 text-[11px] font-semibold uppercase tracking-[0.16em] text-muted">
                {land}
              </h2>
              <div className="overflow-hidden rounded-xl border border-board-line bg-board-surface divide-y divide-board-line/60">
                {rides.map((a) => (
                  <WaitRow key={a.id} a={a} />
                ))}
              </div>
            </section>
          ))}
        </div>
      )}
    </div>
  );
}
