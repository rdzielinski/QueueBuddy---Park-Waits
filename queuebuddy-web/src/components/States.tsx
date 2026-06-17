import { useEffect, useState, type ReactNode } from "react";
import { SplitFlap } from "./SplitFlap";

const DIGITS = "0123456789";
function scramble(width: number): string {
  let s = "";
  for (let i = 0; i < width; i++) s += DIGITS[Math.floor(Math.random() * DIGITS.length)];
  return s;
}

/** Loading shimmer: a row of flaps cycling random digits, like a board
 *  resetting itself. Honors reduced-motion by cycling slowly. */
export function LoadingFlaps({ width = 6, label }: { width?: number; label?: string }) {
  const [value, setValue] = useState(() => scramble(width));
  useEffect(() => {
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    const id = window.setInterval(() => setValue(scramble(width)), reduce ? 600 : 140);
    return () => window.clearInterval(id);
  }, [width]);

  return (
    <div className="flex flex-col items-center gap-4 py-20" role="status" aria-live="polite">
      <SplitFlap value={value} className="text-3xl" stagger={30} />
      <p className="text-sm text-muted">{label ?? "Reading the board…"}</p>
    </div>
  );
}

/** Empty / error state, written in the board's own transit voice. */
export function BoardMessage({
  title,
  children,
  onRetry,
}: {
  title: string;
  children?: ReactNode;
  onRetry?: () => void;
}) {
  return (
    <div className="mx-auto max-w-md px-4 py-20 text-center">
      <p className="font-mono text-lg text-flap-fg">{title}</p>
      {children && <p className="mt-2 text-sm leading-relaxed text-muted">{children}</p>}
      {onRetry && (
        <button
          type="button"
          onClick={onRetry}
          className="mt-6 rounded-lg border border-board-line bg-board-surface px-4 py-2 text-sm font-medium text-flap-fg transition-colors hover:border-white/25"
        >
          Try again
        </button>
      )}
    </div>
  );
}
