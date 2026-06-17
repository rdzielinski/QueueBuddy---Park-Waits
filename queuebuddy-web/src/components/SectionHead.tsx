/** "/ WALT DISNEY WORLD" … "31 OPEN" — the board's section header voice. */
export function SectionHead({ label, right }: { label: string; right?: string }) {
  return (
    <div className="flex items-center justify-between px-1">
      <span className="font-mono text-xs font-medium uppercase tracking-[0.18em] text-muted">
        {label}
      </span>
      {right && (
        <span className="font-mono text-[11px] tracking-wider text-dim">{right}</span>
      )}
    </div>
  );
}
