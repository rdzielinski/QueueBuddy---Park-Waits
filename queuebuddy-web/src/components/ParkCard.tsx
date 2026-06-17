import { Link } from "react-router-dom";
import { SplitFlap } from "./SplitFlap";
import { ParkGlyph } from "./ParkGlyph";
import { parkBySlug } from "../lib/parks";
import { parkHoursLine } from "../lib/format";
import type { Park } from "../lib/types";

export function ParkCard({ park }: { park: Park }) {
  const meta = parkBySlug(park.id);
  const accent = meta?.accent ?? "#FFB547";
  const avg = park.avgWait;
  const hoursLine = meta ? parkHoursLine(meta.openHour, meta.closeHour) : null;

  return (
    <Link
      to={`/park/${park.id}`}
      className="group flex items-stretch gap-3.5 rounded-[20px] border border-white/5 bg-board-surface p-4 transition-colors hover:border-white/15"
    >
      {/* route stripe */}
      <span
        className="my-1 w-[3px] shrink-0 rounded-full"
        style={{ backgroundColor: accent, boxShadow: `0 0 8px ${accent}99` }}
      />

      <ParkGlyph slug={park.id} size={40} />

      <div className="flex min-w-0 flex-1 flex-col justify-center gap-1">
        <h3 className="truncate text-[17px] font-semibold tracking-tight text-flap-fg">
          {park.shortName}
        </h3>

        {park.stale ? (
          <div className="flex items-center gap-1.5 font-mono text-[11px] tracking-wider text-muted">
            <span className="h-1.5 w-1.5 rounded-full bg-muted" />
            NO LIVE DATA
          </div>
        ) : (
          <div className="flex items-center gap-2.5 font-mono text-[11px] tracking-wider">
            <span className="flex items-center gap-1.5 text-wait-low">
              <span
                className="h-1.5 w-1.5 rounded-full bg-wait-low"
                style={{ boxShadow: "0 0 6px var(--color-wait-low)" }}
              />
              {park.openCount} OPEN
            </span>
            <span className="text-dim">·</span>
            <span className="text-muted">AVG {avg != null ? `${avg}M` : "--"}</span>
          </div>
        )}

        {hoursLine && !park.stale && (
          <div className="font-mono text-[10px] tracking-wider text-dim">{hoursLine}</div>
        )}
      </div>

      <div className="flex shrink-0 items-center gap-1.5 self-center">
        <SplitFlap
          value={!park.stale && avg != null ? String(avg) : "—"}
          width={2}
          pad="0"
          color={accent}
          className="text-2xl"
        />
        <span className="text-[9px] uppercase tracking-[0.12em] text-muted">avg</span>
      </div>
    </Link>
  );
}
