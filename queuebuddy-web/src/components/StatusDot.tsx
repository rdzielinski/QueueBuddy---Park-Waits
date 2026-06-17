import { TONE_VAR, type WaitTone } from "../lib/wait";

export function StatusDot({ tone, title }: { tone: WaitTone; title?: string }) {
  return (
    <span
      className="inline-block h-2.5 w-2.5 shrink-0 rounded-full"
      style={{ backgroundColor: TONE_VAR[tone], boxShadow: `0 0 8px ${TONE_VAR[tone]}66` }}
      title={title}
      aria-hidden="true"
    />
  );
}
