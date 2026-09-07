import { executeWorldTick } from "@/lib/world-data";

export async function POST(request: Request) {
  const body = await request.json().catch(() => ({}));
  const ticks = Number(body.ticks ?? 1);
  const result = await executeWorldTick(ticks);

  return Response.json(result);
}
