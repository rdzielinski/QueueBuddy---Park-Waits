import { Link } from "react-router-dom";
import { SplitFlap } from "./SplitFlap";
import { boardEyebrow } from "../lib/format";
import { TONE_VAR, waitTone } from "../lib/wait";

export interface GlobalHottest {
  id: string;
  name: string;
  parkSlug: string;
  parkShortName: string;
  waitMinutes: number;
}

export function BoardHeader({ live = true }: { live?: boolean }) {
  return (
    <header className="flex flex-col gap-1.5">
      <div className="font-mono text-[11px] tracking-[0.18em] text-muted">
        {boardEyebrow(new Date())} · {live ? "ALL SYSTEMS LIVE" : "SYNCING…"}
      </div>
      <h1 className="text-[2.4rem] font-bold leading-none tracking-tight text-flap-fg sm:text-[2.75rem]">
        Parks<span className="text-wait-med">.</span>
      </h1>
    </header>
  );
}

export function HottestHero({ hottest }: { hottest: GlobalHottest | null }) {
  return (
    <div
      className="relative overflow-hidden rounded-3xl border border-wait-med/25 p-5 sm:p-6"
      style={{
        backgroundImage:
          "linear-gradient(135deg, var(--color-card2), var(--color-board-surface))",
      }}
    >
      {/* warm radial glow, top-right */}
      <div
        className="pointer-events-none absolute -right-12 -top-12 h-56 w-56 rounded-full"
        style={{ background: "radial-gradient(circle, rgba(255,181,71,0.12), transparent 70%)" }}
        aria-hidden="true"
      />
      <div className="relative">
        <div className="font-mono text-[11px] tracking-[0.2em] text-wait-med">
          ▲ HOTTEST RIGHT NOW
        </div>

        {hottest ? (
          <>
            <h2 className="mt-2 line-clamp-2 text-xl font-semibold tracking-tight text-flap-fg sm:text-2xl">
              {hottest.name}
            </h2>
            <div className="mt-0.5 font-mono text-[11px] tracking-wider text-muted">
              {hottest.parkShortName.toUpperCase()}
            </div>

            <div className="mt-5 flex items-end justify-between gap-4">
              <div className="flex items-center gap-2">
                <SplitFlap
                  value={String(hottest.waitMinutes)}
                  width={2}
                  pad="0"
                  color={TONE_VAR[waitTone(hottest.waitMinutes)]}
                  className="text-5xl"
                />
                <span className="text-xs uppercase tracking-wide text-muted">min</span>
              </div>
              <Link
                to={
                  `/attraction/${encodeURIComponent(hottest.id)}` +
                  `?park=${encodeURIComponent(hottest.parkSlug)}&name=${encodeURIComponent(hottest.name)}`
                }
                className="rounded-full border border-white/10 bg-white/[0.06] px-4 py-2 font-mono text-[11px] font-semibold tracking-wider text-flap-fg transition-colors hover:bg-white/10"
              >
                VIEW →
              </Link>
            </div>
          </>
        ) : (
          <>
            <h2 className="mt-2 text-xl font-semibold text-flap-fg">Waits aren't in yet</h2>
            <div className="mt-1 font-mono text-[11px] tracking-wider text-muted">SYNCING…</div>
          </>
        )}
      </div>
    </div>
  );
}
