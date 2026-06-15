import { Link } from "react-router-dom";
import { SplitFlap } from "./SplitFlap";
import { formatBoardDate, formatClock } from "../lib/format";
import { TONE_VAR, waitTone } from "../lib/wait";

export interface GlobalHottest {
  id: string;
  name: string;
  parkSlug: string;
  parkShortName: string;
  waitMinutes: number;
}

export function BoardHeader({ now }: { now: Date }) {
  return (
    <header className="flex items-end justify-between gap-4 border-b border-board-line pb-5">
      <Link to="/" className="block">
        <div className="text-[11px] uppercase tracking-[0.2em] text-muted">QueueBuddy</div>
        <h1 className="font-mono text-2xl font-bold tracking-tight text-flap-fg sm:text-3xl">
          Park&nbsp;Waits
        </h1>
      </Link>
      <div className="text-right">
        <div className="tnum font-mono text-2xl text-flap-fg sm:text-3xl">
          {formatClock(now)}
        </div>
        <div className="mt-0.5 text-[11px] uppercase tracking-wide text-muted">
          {formatBoardDate(now)} · Park time
        </div>
      </div>
    </header>
  );
}

export function HottestHero({ hottest }: { hottest: GlobalHottest | null }) {
  if (!hottest) return null;
  const tone = waitTone(hottest.waitMinutes);
  const to =
    `/attraction/${encodeURIComponent(hottest.id)}` +
    `?park=${encodeURIComponent(hottest.parkSlug)}&name=${encodeURIComponent(hottest.name)}`;

  return (
    <Link
      to={to}
      className="flex items-center justify-between gap-4 rounded-2xl border border-board-line bg-board-surface p-5 transition-colors hover:border-white/20 sm:p-6"
    >
      <div className="min-w-0">
        <div className="text-[11px] uppercase tracking-[0.18em] text-wait-high">
          Hottest right now
        </div>
        <div className="mt-1.5 truncate text-xl font-semibold text-flap-fg sm:text-2xl">
          {hottest.name}
        </div>
        <div className="text-sm text-muted">{hottest.parkShortName}</div>
      </div>
      <div className="flex shrink-0 items-center gap-2">
        <SplitFlap
          value={String(hottest.waitMinutes)}
          width={3}
          color={TONE_VAR[tone]}
          className="text-4xl sm:text-5xl"
        />
        <span className="text-xs uppercase tracking-wide text-muted">min</span>
      </div>
    </Link>
  );
}
