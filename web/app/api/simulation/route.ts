import { resetWorld } from "@/lib/world-data";

export async function POST(request: Request) {
  const body = await request.json().catch(() => ({}));
  const result = await resetWorld(body);

  return Response.json(result);
}
