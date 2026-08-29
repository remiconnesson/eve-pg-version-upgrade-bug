import { defineAgent } from "eve";

export default defineAgent({
  model: "anthropic/claude-sonnet-5",
  // On Vercel, let eve default to Vercel Workflow (the managed world).
  // Locally / self-hosted, reproduce ADEO's setup: PostgreSQL workflow world.
  ...(process.env.VERCEL
    ? {}
    : {
        experimental: {
          workflow: {
            world: "@workflow/world-postgres",
          },
        },
      }),
});
