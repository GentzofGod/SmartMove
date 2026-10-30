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
    const META_API_KEY =
      Deno.env.get("MODEL_API_KEY") ||
      Deno.env.get("META_API_KEY") ||
      Deno.env.get("META_AI_API_KEY") ||
      (META_APP_ID && META_CLIENT_TOKEN ? `${META_APP_ID}|${META_CLIENT_TOKEN}` : "");

    if (!META_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Server missing Meta API credentials" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 1. Muse Voice Transcribe Gateway (dev.meta.ai/docs asr transcribe)
    if (action === "transcribe") {
      const { audioBase64, language = "en", mode = "PUSH_TO_TALK", prompt } = payload || {};
      const metaResponse = await fetch("https://api.meta.ai/v1/asr/transcribe", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model: "muse-voice-transcribe-1.0",
          audio: audioBase64,
          language,
          mode,
          task: "transcribe",
          prompt:
            prompt ||
            "West African commodity trade: garri, rice, eggs, oil, yam, tomatoes, Bodija market",
        }),
      });

      const result = await metaResponse.json();
      return new Response(JSON.stringify(result), {
        status: metaResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 2. Multimodal Vision Paper Note Gateway
    if (action === "parse_image" || action === "vision") {
      const { imageBase64, prompt } = payload || {};
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
                "You are Meta Muse Spark Vision. Transcribe handwritten shopping lists into JSON with fields: shoppingItems (array of {productName, quantity, unit, estimatedUnitPrice}), budget (number), notes (string).",
            },
            {
              role: "user",
              content: [
                {
                  type: "text",
                  text: prompt || "Transcribe this paper shopping note into structured items.",
                },
                {
                  type: "image_url",
                  image_url: { url: `data:image/jpeg;base64,${imageBase64}` },
                },
              ],
            },
          ],
          temperature: 0.1,
        }),
      });

      const result = await metaResponse.json();
      return new Response(JSON.stringify(result), {
        status: metaResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 3. Muse Spark Reasoning Gateway (Chat Completions & Price Intelligence)
    if (
      action === "parse_request" ||
      action === "explain_plan" ||
      action === "chat_completions" ||
      action === "research_price"
    ) {
      const { prompt, contextRecords, messages, model = "muse-spark-1.3", temperature = 0.1 } =
        payload || {};

      const chatMessages =
        messages || [
          {
            role: "system",
            content:
              "You are Meta Muse Spark for SmartMove. Extract shopping items (name, quantity, unit, estimated_unit_price, brand_or_grade), quantities, budget, and deadline errands into strict JSON. When users provide concise, bundle, or category requests (e.g., 'i need to buy a set of stationaries', 'toiletries', 'soup ingredients', 'breakfast pack'), intelligently decompose the request into essential constituent items with realistic default quantities, units, and Nigerian market benchmark prices in Naira. Infer a realistic budget if none is specified. Output only valid JSON with keys: budget, shopping_items, deadline_errand.",
          },
          {
            role: "user",
            content:
              typeof prompt === "string"
                ? prompt
                : JSON.stringify({ prompt, contextRecords }),
          },
        ];

      const metaResponse = await fetch("https://api.meta.ai/v1/chat/completions", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          messages: chatMessages,
          temperature,
        }),
      });

      const result = await metaResponse.json();
      return new Response(JSON.stringify(result), {
        status: metaResponse.status,
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

