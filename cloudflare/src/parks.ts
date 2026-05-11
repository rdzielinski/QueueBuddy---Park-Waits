/**
 * Mirror of `StaticData.parkUUIDByInternalId` on the iOS side. Both
 * files must list the same parks — when adding a new park, update both
 * (the iOS app keys off the int ID for storage/UI; the worker keys off
 * the UUID for the API). Drift here means we either miss parks during
 * history sampling or push to attractions the iOS catalog can't render.
 */
export interface KnownPark {
  internalId: number;
  uuid: string;
  shortName: string;
}

export const KNOWN_PARKS: KnownPark[] = [
  { internalId: 5,   uuid: "47f90d2c-e191-4239-a466-5892ef59a88b", shortName: "EPCOT" },
  { internalId: 6,   uuid: "75ea578a-adc8-4116-a54d-dccb60765ef9", shortName: "MK" },
  { internalId: 7,   uuid: "288747d1-8b4f-4a64-867e-ea7c9b27bad8", shortName: "HS" },
  { internalId: 8,   uuid: "1c84a229-8862-4648-9c71-378ddd2c7693", shortName: "AK" },
  { internalId: 64,  uuid: "267615cc-8943-4c2a-ae2c-5da728ca591f", shortName: "IOA" },
  { internalId: 65,  uuid: "eb3f4560-2383-4a36-9152-6b3e5ed6bc57", shortName: "USF" },
  { internalId: 334, uuid: "12dbb85b-265f-44e6-bccf-f1faa17211fc", shortName: "EU" },
];
