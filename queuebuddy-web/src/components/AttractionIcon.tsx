import { useState } from "react";
import { catalogEntry, imageFor } from "../lib/catalog";
import { iconForType } from "../lib/attractionIcon";

/** An attraction's thumbnail (from the iOS asset catalog), with a type-based
 *  emoji fallback for the ~10% of rides without a generated image. */
export function AttractionIcon({
  id,
  className = "h-7 w-11",
  rounded = "rounded-md",
}: {
  id: string;
  className?: string;
  rounded?: string;
}) {
  const [failed, setFailed] = useState(false);
  const src = imageFor(id);

  if (src && !failed) {
    return (
      <img
        src={src}
        alt=""
        aria-hidden="true"
        loading="lazy"
        decoding="async"
        onError={() => setFailed(true)}
        className={`${className} ${rounded} shrink-0 bg-flap-bg object-cover`}
      />
    );
  }

  return (
    <span
      className={`${className} ${rounded} grid shrink-0 place-items-center bg-flap-bg text-base leading-none`}
      aria-hidden="true"
    >
      {iconForType(catalogEntry(id)?.type)}
    </span>
  );
}
