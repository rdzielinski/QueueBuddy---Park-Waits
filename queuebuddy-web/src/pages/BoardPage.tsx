import { useMemo } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { useNow } from "../lib/hooks";
import { RESORT_LABELS, RESORT_ORDER } from "../lib/parks";
import { BoardHeader, HottestHero, type GlobalHottest } from "../components/BoardHeader";
import { ParkCard } from "../components/ParkCard";
import { BoardMessage, LoadingFlaps } from "../components/States";

export function BoardPage() {
  const now = useNow();
  const { data: parks, isPending, isError, refetch, isFetching } = useQuery({
    queryKey: ["parks"],
    queryFn: ({ signal }) => api.getParks(signal),
    refetchInterval: 60_000,
  });

  const hottest = useMemo<GlobalHottest | null>(() => {
    if (!parks) return null;
    let best: GlobalHottest | null = null;
    for (const p of parks) {
      if (p.hottest && (!best || p.hottest.waitMinutes > best.waitMinutes)) {
        best = {
          id: p.hottest.id,
          name: p.hottest.name,
          parkSlug: p.id,
          parkShortName: p.shortName,
          waitMinutes: p.hottest.waitMinutes,
        };
      }
    }
    return best;
  }, [parks]);

  return (
    <div className="flex flex-col gap-6">
      <BoardHeader now={now} />

      {isPending ? (
        <LoadingFlaps label="Reading the board…" />
      ) : isError ? (
        <BoardMessage title="The board's dark right now." onRetry={() => refetch()}>
          Couldn't reach the wait-times feed. Give it a moment and try again.
        </BoardMessage>
      ) : (
        <>
          <HottestHero hottest={hottest} />

          {RESORT_ORDER.map((resort) => {
            const group = parks.filter((p) => p.resort === resort);
            if (group.length === 0) return null;
            return (
              <section key={resort} className="flex flex-col gap-3">
                <h2 className="text-[11px] font-semibold uppercase tracking-[0.18em] text-muted">
                  {RESORT_LABELS[resort]}
                </h2>
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 lg:grid-cols-4">
                  {group.map((p) => (
                    <ParkCard key={p.id} park={p} />
                  ))}
                </div>
              </section>
            );
          })}

          <p className="pt-2 text-center text-xs text-muted">
            {isFetching ? "Refreshing…" : "Live waits refresh every 60s · times shown in park-local time"}
          </p>
        </>
      )}
    </div>
  );
}
