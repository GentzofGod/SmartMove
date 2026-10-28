// Supabase Edge Function: Meta AI Proxy (Safeguard Implementation)
// Ensures Meta API secrets and model keys stay strictly on the server,
// never embedded within the Flutter client application.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { action, payload } = await req.json();

    // Securely retrieve Meta App credentials from Server Environment Secrets
    const META_APP_ID = Deno.env.get("META_APP_ID");
    const META_CLIENT_TOKEN = Deno.env.get("META_CLIENT_TOKEN");
    const META_API_KEY = Deno.env.get("META_API_KEY") || `${META_APP_ID}|${META_CLIENT_TOKEN}`;

    if (!META_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Server missing Meta API credentials" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Muse Voice Transcribe Gateway
    if (action === "transcribe") {
      const { audioBase64 } = payload;
      // Forward to Meta Muse Voice Transcribe endpoint (muse-voice-transcribe-1.0)
      const metaResponse = await fetch("https://api.meta.ai/v1/audio/transcriptions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "muse-voice-transcribe-1.0",
          audio: audioBase64,
          language: "en",
        }),
      });

      const result = await metaResponse.json();
      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Muse Spark Reasoning Gateway
    if (action === "parse_request" || action === "explain_plan") {
      const { prompt, contextRecords } = payload;

      const metaResponse = await fetch("https://api.meta.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "muse-spark-1.3",
          messages: [
            {
              role: "system",
              content:
                "You are Meta Muse Spark for SmartMove. Extract shopping items, quantities, budget, and deadline errands into strict JSON. Refer only to provided context records; never invent prices or travel facts.",
            },
            {
              role: "user",
              content: JSON.stringify({ prompt, contextRecords }),
            },
          ],
          temperature: 0.1,
        }),
      });

      const result = await metaResponse.json();
      return new Response(JSON.stringify(result), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(
      JSON.stringify({ error: `Unknown action: ${action}` }),
      { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message || "Internal server error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

