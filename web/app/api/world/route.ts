import { getWorldSnapshotData } from "@/lib/world-data";

export async function GET() {
  const world = await getWorldSnapshotData();

  return Response.json(world, {
    headers: {
      "Cache-Control": "no-store",
    },
  });
}
