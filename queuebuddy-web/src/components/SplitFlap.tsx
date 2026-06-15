import { useEffect, useRef, useState, type CSSProperties } from "react";
import "./SplitFlap.css";

function FlapCell({ char, delay }: { char: string; delay: number }) {
  const [shown, setShown] = useState(char);
  const [prev, setPrev] = useState(char);
  const [flipping, setFlipping] = useState(false);
  const timer = useRef<number | undefined>(undefined);

  useEffect(() => {
    if (char === shown) return;
    const reduce = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduce) {
      setShown(char);
      return;
    }
    setPrev(shown);
    setShown(char);
    setFlipping(false);
    // stagger so the board "ripples" left-to-right
    timer.current = window.setTimeout(() => {
      setFlipping(true);
      window.setTimeout(() => setFlipping(false), 320);
    }, delay);
    return () => window.clearTimeout(timer.current);
  }, [char, shown, delay]);

  return (
    <span className="flap">
      {/* static halves show the new value */}
      <span className="flap__half flap__top">{shown}</span>
      <span className="flap__half flap__bottom">{shown}</span>
      {flipping && (
        <>
          {/* old top folds down */}
          <span className="flap__half flap__top flap__fold-down">{prev}</span>
          {/* new bottom folds in */}
          <span className="flap__half flap__bottom flap__fold-in">{shown}</span>
        </>
      )}
      <span className="flap__hinge" />
    </span>
  );
}

export interface SplitFlapProps {
  value: string;
  /** Pad/clip to this many cells so the board stays aligned. */
  width?: number;
  /** Per-cell stagger in ms. */
  stagger?: number;
  /** Color the digits (e.g. a wait tone); defaults to warm white. */
  color?: string;
  /** Extra classes for sizing (font-size controls the cell size). */
  className?: string;
  style?: CSSProperties;
}

export function SplitFlap({
  value,
  width,
  stagger = 45,
  color,
  className,
  style,
}: SplitFlapProps) {
  const text = width ? value.padStart(width, " ").slice(-width) : value;
  return (
    <span
      className={`splitflap${className ? ` ${className}` : ""}`}
      role="text"
      aria-label={value.trim() || "no value"}
      style={color ? { color, ...style } : style}
    >
      {[...text].map((c, i) => (
        <FlapCell key={i} char={c} delay={i * stagger} />
      ))}
    </span>
  );
}
