import { Link } from "react-router-dom";
import { SplitFlap } from "./SplitFlap";
import { StatusDot } from "./StatusDot";
import { AttractionIcon } from "./AttractionIcon";
import { attractionTone, statusLabel, waitGlyph, TONE_VAR } from "../lib/wait";
import { catalogEntry } from "../lib/catalog";
import type { Attraction } from "../lib/types";

export function WaitRow({ a }: { a: Attraction }) {
  const tone = attractionTone(a);
  const operating = a.status === "OPERATING";
  // The live feed returns the parent entity, so single-rider availability comes
  // from the static catalog (a separate "X Single Rider" row would too).
  const singleRider = catalogEntry(a.id)?.singleRider ?? a.singleRider;
  const displayName = a.name.replace(/\s*single rider$/i, "");
  const to =
    `/attraction/${encodeURIComponent(a.id)}` +
    `?park=${encodeURIComponent(a.parkId)}&name=${encodeURIComponent(a.name)}`;

  return (
    <Link
      to={to}
      state={{ attraction: a }}
      className="group flex items-center gap-3 rounded-lg px-3 py-2 transition-colors hover:bg-white/[0.04]"
    >
      <StatusDot tone={tone} title={statusLabel(a.status)} />
      <AttractionIcon id={a.id} />

      <span className="flex min-w-0 flex-1 items-center gap-2">
        <span className="truncate text-[15px] text-flap-fg/85 group-hover:text-flap-fg">
          {displayName}
        </span>
        {singleRider && (
          <span className="shrink-0 rounded bg-white/10 px-1.5 py-0.5 font-mono text-[10px] font-semibold tracking-wider text-flap-fg/70">
            SOLO
          </span>
        )}
      </span>

      {operating ? (
        <span className="flex items-center gap-1.5">
          <SplitFlap
            value={waitGlyph(a)}
            width={3}
            color={TONE_VAR[tone]}
            className="text-xl"
          />
          <span className="w-7 text-[10px] uppercase tracking-wide text-muted">min</span>
        </span>
      ) : (
        <span className="text-xs font-medium uppercase tracking-wide text-status-down">
          {statusLabel(a.status)}
        </span>
      )}
    </Link>
  );
}
