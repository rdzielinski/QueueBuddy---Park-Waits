import { useMemo, useState } from "react";
import { useQuery } from "@tanstack/react-query";
import { api } from "../lib/api";
import { RESORT_LABELS, RESORT_ORDER } from "../lib/parks";
import { BoardHeader, HottestHero, type GlobalHottest } from "../components/BoardHeader";
import { ParkCard } from "../components/ParkCard";
import { SectionHead } from "../components/SectionHead";
import { SearchBar, SearchResults } from "../components/BoardSearch";
import { BoardMessage, LoadingFlaps } from "../components/States";

export function BoardPage() {
  const [query, setQuery] = useState("");
  const searching = query.trim().length > 0;

  const { data, isPending, isError, refetch, isFetching } = useQuery({
    queryKey: ["parks"],
    queryFn: ({ signal }) => api.getParks(signal),
    refetchInterval: 60_000,
  });
  const parks = data ?? [];

  const hottest = useMemo<GlobalHottest | null>(() => {
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
      <BoardHeader live={!isError} />

      {isPending ? (
        <LoadingFlaps label="Reading the board…" />
      ) : isError ? (
        <BoardMessage title="The board's dark right now." onRetry={() => refetch()}>
          Couldn't reach the wait-times feed. Give it a moment and try again.
        </BoardMessage>
      ) : (
        <>
          {!searching && <HottestHero hottest={hottest} />}

          <SearchBar query={query} onChange={setQuery} />

          {searching ? (
            <SearchResults query={query} parks={parks} />
          ) : (
            <>
              {RESORT_ORDER.map((resort) => {
                const group = parks.filter((p) => p.resort === resort);
                if (group.length === 0) return null;
                const open = group.reduce((sum, p) => sum + (p.openCount ?? 0), 0);
                return (
                  <section key={resort} className="flex flex-col gap-2.5">
                    <SectionHead
                      label={`/ ${RESORT_LABELS[resort].toUpperCase()}`}
                      right={`${open} OPEN`}
                    />
                    <div className="flex flex-col gap-2.5">
                      {group.map((p) => (
                        <ParkCard key={p.id} park={p} />
                      ))}
                    </div>
                  </section>
                );
              })}

              <p className="pt-1 text-center text-xs text-muted">
                {isFetching ? "Refreshing…" : "Live waits refresh every 60s · park-local time"}
              </p>
            </>
          )}
        </>
      )}
    </div>
  );
}
