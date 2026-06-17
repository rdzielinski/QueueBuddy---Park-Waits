import { lazy, Suspense } from "react";
import { Link, Route, Routes } from "react-router-dom";
import { BoardMessage, LoadingFlaps } from "./components/States";

// Route-level code splitting: the board loads lean, and the chart library
// (Recharts) only ships with the attraction detail page.
const BoardPage = lazy(() =>
  import("./pages/BoardPage").then((m) => ({ default: m.BoardPage })),
);
const ParkPage = lazy(() =>
  import("./pages/ParkPage").then((m) => ({ default: m.ParkPage })),
);
const AttractionPage = lazy(() =>
  import("./pages/AttractionPage").then((m) => ({ default: m.AttractionPage })),
);

function NotFound() {
  return (
    <BoardMessage title="Off the map.">
      That page isn't on the board. <Link className="underline" to="/">Back to all parks</Link>.
    </BoardMessage>
  );
}

export default function App() {
  return (
    <div className="flex min-h-dvh flex-col">
      <main className="mx-auto w-full max-w-6xl flex-1 px-4 py-6 sm:px-6 sm:py-8">
        <Suspense fallback={<LoadingFlaps />}>
          <Routes>
            <Route path="/" element={<BoardPage />} />
            <Route path="/park/:parkId" element={<ParkPage />} />
            <Route path="/attraction/:attractionId" element={<AttractionPage />} />
            <Route path="*" element={<NotFound />} />
          </Routes>
        </Suspense>
      </main>
      <footer className="mx-auto w-full max-w-6xl px-4 pb-8 pt-4 text-center text-[11px] text-muted sm:px-6">
        Live data from{" "}
        <a
          className="underline transition-colors hover:text-flap-fg"
          href="https://themeparks.wiki"
          target="_blank"
          rel="noreferrer"
        >
          ThemeParks.wiki
        </a>{" "}
        · Not affiliated with Disney or Universal
      </footer>
    </div>
  );
}
