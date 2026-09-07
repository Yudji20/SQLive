"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { createSupabaseBrowserClient } from "@/lib/supabase-browser";

type RealtimeBridgeProps = {
  worldSlug: string;
};

export function RealtimeBridge({ worldSlug }: RealtimeBridgeProps) {
  const router = useRouter();

  useEffect(() => {
    const supabase = createSupabaseBrowserClient();

    if (!supabase) {
      return;
    }

    const channel = supabase
      .channel(`sqlive-world-${worldSlug}`)
      .on(
        "postgres_changes",
        {
          event: "INSERT",
          schema: "alife",
          table: "event_log",
        },
        () => {
          router.refresh();
        },
      )
      .on(
        "postgres_changes",
        {
          event: "*",
          schema: "alife",
          table: "world_metrics",
        },
        () => {
          router.refresh();
        },
      )
      .subscribe();

    return () => {
      void supabase.removeChannel(channel);
    };
  }, [router, worldSlug]);

  return null;
}

