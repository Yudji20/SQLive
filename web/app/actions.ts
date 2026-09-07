"use server";

import { revalidatePath } from "next/cache";

export async function createAdminAction(formData: FormData) {
  const actionType = String(formData.get("action_type") ?? "");
  const x = Number(formData.get("x") ?? 10);
  const y = Number(formData.get("y") ?? 10);
  const entityId = Number(formData.get("entity_id") ?? 0);

  const payload =
    actionType === "spawn_entity"
      ? {
          species_key: String(formData.get("species_key") ?? "sqlife"),
          faction_key: String(formData.get("faction_key") ?? "wild"),
          x,
          y,
          energy: 40,
          health: 80,
        }
      : actionType === "bless_entity"
        ? {
            entity_id: entityId,
            energy: 20,
            health: 10,
          }
        : actionType === "storm"
          ? {
              x,
              y,
              radius: Number(formData.get("radius") ?? 3),
              energy_damage: 8,
              health_damage: 4,
            }
          : {
              x,
              y,
              note: "Admin observation from the site.",
            };

  const baseUrl = process.env.NEXT_PUBLIC_SITE_URL ?? "http://127.0.0.1:3000";

  await fetch(`${baseUrl}/api/admin-actions`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      action_type: actionType,
      payload,
    }),
    cache: "no-store",
  });

  revalidatePath("/");
}
