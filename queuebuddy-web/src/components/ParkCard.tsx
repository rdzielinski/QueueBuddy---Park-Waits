import { Link } from "react-router-dom";
import { SplitFlap } from "./SplitFlap";
import { TONE_VAR, waitTone } from "../lib/wait";
import type { Park } from "../lib/types";

export function ParkCard({ park }: { park: Park }) {
  const tone = waitTone(park.avgWait);
  const avg = park.avgWait != null ? String(park.avgWait) : "—";

  return (
    <Link
      to={`/park/${park.id}`}
      className="group flex flex-col gap-4 rounded-xl border border-board-line bg-board-surface p-4 transition-colors hover:border-white/20 focus-visible:border-white/30"
    >
      <div className="flex items-start justify-between gap-2">
        <h3 className="text-base font-semibold leading-tight text-flap-fg">
          {park.shortName}
        </h3>
        {park.hours && (
          <span className="shrink-0 pt-0.5 text-right text-[11px] leading-tight text-muted">
            {park.hours.open}
            <br />
            {park.hours.close}
          </span>
        )}
      </div>

      <div className="flex items-end justify-between">
        <div>
          <div className="text-[10px] uppercase tracking-[0.12em] text-muted">Open</div>
          <div className="tnum mt-0.5 font-mono text-lg text-flap-fg">
            {park.stale ? "—" : `${park.openCount} / ${park.totalCount}`}
          </div>
        </div>
        <div className="text-right">
          <div className="text-[10px] uppercase tracking-[0.12em] text-muted">Avg wait</div>
          <div className="mt-1 flex items-center justify-end gap-1.5">
            <SplitFlap value={avg} width={3} color={TONE_VAR[tone]} className="text-2xl" />
            <span className="text-[10px] uppercase tracking-wide text-muted">min</span>
          </div>
        </div>
      </div>

      {park.stale ? (
        <div className="text-xs text-status-down">No live data</div>
      ) : park.hottest ? (
        <div className="truncate border-t border-board-line pt-2 text-xs text-muted">
          <span className="text-flap-fg/70">Longest:</span> {park.hottest.name}{" "}
          <span className="tnum font-mono text-flap-fg/90">{park.hottest.waitMinutes}m</span>
        </div>
      ) : (
        <div className="border-t border-board-line pt-2 text-xs text-muted">
          Quiet right now
        </div>
      )}
    </Link>
  );
}
