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
      const {
        audioBase64,
        language = "en",
        mode = "PUSH_TO_TALK",
        prompt,
        keywords,
        audioFormat = "audio/wav",
        sampleRate = 24000,
        channels = 1,
      } = payload || {};

      // Normalize audioEncoding: Meta Voyager ASR expects "WAV"
      const rawEncoding = (
        payload?.audioEncoding ||
        payload?.audio_encoding ||
        payload?.encoding ||
        "WAV"
      ).toString().toUpperCase();

      const effectiveAudioEncoding =
        rawEncoding === "PCM_16BIT" || rawEncoding === "PCM" || rawEncoding === "WAV"
          ? "WAV"
          : rawEncoding;

      // Convert base64 audio to binary Blob for multipart/form-data
      let audioBlob: Blob;
      if (audioBase64 && typeof audioBase64 === "string") {
        const binaryStr = atob(audioBase64);
        const bytes = new Uint8Array(binaryStr.length);
        for (let i = 0; i < binaryStr.length; i++) {
          bytes[i] = binaryStr.charCodeAt(i);
        }
        audioBlob = new Blob([bytes], { type: audioFormat });
      } else {
        audioBlob = new Blob([], { type: audioFormat });
      }

      if (audioBlob.size <= 44) {
        return new Response(
          JSON.stringify({
            error: {
              code: "empty_audio",
              type: "invalid_request_error",
              message:
                "The recorded audio is empty or too short. Please hold the record button and speak clearly.",
            },
          }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const defaultKeywords = [
        "garri",
        "rice",
        "eggs",
        "oil",
        "yam",
        "tomatoes",
        "Bodija market",
        "Abeokuta",
        "Lagos",
        "Ibadan",
      ];

      const formData = new FormData();
      formData.append(
        "request",
        new Blob(
          [
            JSON.stringify({
              model: "muse-voice-transcribe-1.0",
              audioEncoding: effectiveAudioEncoding,
              mode,
              language,
              keywords:
                Array.isArray(keywords) && keywords.length > 0 ? keywords : defaultKeywords,
              prompt:
                prompt ||
                "West African commodity trade: garri, rice, eggs, oil, yam, tomatoes, Bodija market",
            }),
          ],
          { type: "application/json" }
        )
      );

      // Meta Voyager ASR strictly expects only 'request' and 'audio' multipart fields.
      // Standalone fields like audioEncoding cause HTTP 400 Malformed request.
      formData.append("audio", audioBlob, "recording.wav");

      const metaResponse = await fetch("https://api.meta.ai/v1/asr/transcribe", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Accept": "application/json",
        },
        body: formData,
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

    // 3. Muse Spark Reasoning Gateway (Chat Completions & Price Intelligence & Product Description)
    if (
      action === "parse_request" ||
      action === "explain_plan" ||
      action === "chat_completions" ||
      action === "research_price" ||
      action === "generate_description" ||
      action === "llm_generate"
    ) {
      const { prompt, contextRecords, messages, model = "muse-spark-1.3", temperature = 0.2 } =
        payload || {};

      const isDescriptionGeneration =
        action === "generate_description" || action === "llm_generate";

      const chatMessages =
        messages || [
          {
            role: "system",
            content: isDescriptionGeneration
              ? "You are an expert Nigerian commerce assistant helping registered market traders create concise, accurate, appealing 1-2 sentence product descriptions for their stall listings. Focus on authenticity, quality, weight/packaging, and freshness. Do not output conversational filler or preamble—output only the description."
              : "You are Meta Muse Spark for SmartMove. Extract shopping items (name, quantity, unit, estimated_unit_price, brand_or_grade), quantities, budget, and deadline errands into strict JSON. When users provide concise, bundle, or category requests (e.g., 'i need to buy a set of stationaries', 'toiletries', 'soup ingredients', 'breakfast pack'), intelligently decompose the request into essential constituent items with realistic default quantities, units, and Nigerian market benchmark prices in Naira. Infer a realistic budget if none is specified. Output only valid JSON with keys: budget, shopping_items, deadline_errand.",
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
          model: model === "meta/llama-3-70b-instruct" ? "muse-spark-1.3" : model,
          messages: chatMessages,
          temperature,
        }),
      });

      const result = await metaResponse.json();
      
      // Enrich response with top-level 'text' for easy direct consumption
      if (metaResponse.ok && result?.choices?.[0]?.message?.content) {
        result.text = result.choices[0].message.content.trim();
      }

      return new Response(JSON.stringify(result), {
        status: metaResponse.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    // 4. Meta Responses API with Native Search Grounding (dev.meta.ai/docs/search-grounding)
    if (
      action === "search_grounding" ||
      action === "responses" ||
      action === "search_products"
    ) {
      const {
        input,
        prompt,
        model = "muse-spark-1.3",
        include = ["web_search_call.results"],
        tools = [{ type: "web_search" }],
      } = payload || {};

      const searchInput =
        input ||
        prompt ||
        "Search online store products and current market prices in Nigeria on Jumia, Konga, and local markets";

      const metaResponse = await fetch("https://api.meta.ai/v1/responses", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${META_API_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          model,
          input: searchInput,
          tools,
          include,
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

