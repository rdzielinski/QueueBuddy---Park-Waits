import { parkBySlug } from "../lib/parks";

/** Park glyph in an accent-tinted rounded badge — the web stand-in for the
 *  iOS app's per-park silhouette (DB.glyph / ParkGlyph). */
export function ParkGlyph({ slug, size = 40 }: { slug: string; size?: number }) {
  const park = parkBySlug(slug);
  const accent = park?.accent ?? "#FFB547";
  return (
    <span
      className="grid shrink-0 place-items-center rounded-xl"
      style={{
        width: size,
        height: size,
        backgroundColor: `${accent}1f`,
        boxShadow: `inset 0 0 0 1px ${accent}55`,
      }}
      aria-hidden="true"
    >
      <span style={{ fontSize: Math.round(size * 0.5) }}>{park?.glyph ?? "🎡"}</span>
    </span>
  );
}
