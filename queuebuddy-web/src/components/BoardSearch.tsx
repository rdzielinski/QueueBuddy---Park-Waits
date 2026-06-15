import { Link } from "react-router-dom";
import { ParkCard } from "./ParkCard";
import { AttractionIcon } from "./AttractionIcon";
import { SectionHead } from "./SectionHead";
import { BoardMessage } from "./States";
import { parkBySlug } from "../lib/parks";
import { searchAttractions, type CatalogEntry } from "../lib/catalog";
import type { Park } from "../lib/types";

export function SearchBar({
  query,
  onChange,
}: {
  query: string;
  onChange: (v: string) => void;
}) {
  return (
    <div className="flex items-center gap-2.5 rounded-2xl border border-white/[0.06] bg-board-surface px-3.5 py-3">
      <span className="font-mono text-sm font-bold text-wait-med" aria-hidden="true">
        &gt;
      </span>
      <input
        type="search"
        value={query}
        onChange={(e) => onChange(e.target.value)}
        placeholder="search attractions…"
        spellCheck={false}
        autoCorrect="off"
        aria-label="Search attractions and parks"
        className="min-w-0 flex-1 bg-transparent font-mono text-sm text-flap-fg caret-wait-med placeholder:text-muted focus:outline-none"
      />
      {query && (
        <button
          type="button"
          onClick={() => onChange("")}
          aria-label="Clear search"
          className="text-muted transition-colors hover:text-flap-fg"
        >
          ✕
        </button>
      )}
    </div>
  );
}

function SearchRow({ entry }: { entry: CatalogEntry }) {
  const park = parkBySlug(entry.parkSlug ?? undefined);
  const accent = park?.accent ?? "#FFB547";
  const to =
    `/attraction/${encodeURIComponent(entry.uuid)}` +
    `?park=${encodeURIComponent(entry.parkSlug ?? "")}&name=${encodeURIComponent(entry.name)}`;

  return (
    <Link to={to} className="group flex items-center gap-3 px-3 py-2.5 transition-colors hover:bg-white/[0.04]">
      <span
        className="my-0.5 w-[3px] shrink-0 self-stretch rounded-full"
        style={{ backgroundColor: accent }}
      />
      <AttractionIcon id={entry.uuid} />
      <div className="min-w-0 flex-1">
        <div className="truncate text-[15px] text-flap-fg/90 group-hover:text-flap-fg">
          {entry.name.replace(/\s*single rider$/i, "")}
        </div>
        <div className="truncate font-mono text-[10px] tracking-wider text-muted">
          {park?.shortName.toUpperCase()}
          {entry.land ? ` · ${entry.land.toUpperCase()}` : ""}
        </div>
      </div>
      <span className="text-dim transition-colors group-hover:text-muted">→</span>
    </Link>
  );
}

export function SearchResults({ query, parks }: { query: string; parks: Park[] }) {
  const q = query.trim().toLowerCase();
  const matchParks = parks.filter(
    (p) => p.name.toLowerCase().includes(q) || p.shortName.toLowerCase().includes(q),
  );
  const matchAttractions = searchAttractions(query);

  if (matchParks.length === 0 && matchAttractions.length === 0) {
    return (
      <BoardMessage title="NO MATCHES">Nothing found for “{query.trim()}”.</BoardMessage>
    );
  }

  return (
    <div className="flex flex-col gap-6">
      {matchParks.length > 0 && (
        <section className="flex flex-col gap-2.5">
          <SectionHead label="/ PARKS" right={String(matchParks.length)} />
          <div className="flex flex-col gap-2.5">
            {matchParks.map((p) => (
              <ParkCard key={p.id} park={p} />
            ))}
          </div>
        </section>
      )}

      {matchAttractions.length > 0 && (
        <section className="flex flex-col gap-2.5">
          <SectionHead label="/ ATTRACTIONS" right={String(matchAttractions.length)} />
          <div className="divide-y divide-board-line/60 overflow-hidden rounded-2xl border border-white/5 bg-board-surface">
            {matchAttractions.map((e) => (
              <SearchRow key={e.uuid} entry={e} />
            ))}
          </div>
        </section>
      )}
    </div>
  );
}
