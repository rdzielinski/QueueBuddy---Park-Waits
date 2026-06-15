import { parkBySlug, fetchParkLive, json, errorJson, type Env } from "../../_shared";

/** GET /api/parks/:parkId/live — live attractions for one park. */
export const onRequestGet: PagesFunction<Env> = async ({ params }) => {
  const slug = String(params.parkId);
  const park = parkBySlug(slug);
  if (!park) return errorJson(404, `unknown park: ${slug}`);

  try {
    const attractions = await fetchParkLive(park.uuid, park.slug);
    return json(attractions, { maxAge: 30 });
  } catch (e) {
    return errorJson(502, `live fetch failed: ${(e as Error).message}`);
  }
};
