const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Content-Type': 'application/json',
};

const jsonResponse = (body: Record<string, unknown>, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: corsHeaders });

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return jsonResponse({ error: 'Use POST for cloud photo guesses.' }, 405);
  }

  const apiKey = Deno.env.get('GEMINI_API_KEY');
  if (!apiKey) {
    return jsonResponse({ error: 'The cloud guessing service is not configured.' }, 500);
  }

  try {
    const body = await request.json();
    const imageBase64 = body?.imageBase64;
    const mimeType = body?.mimeType;
    if (typeof imageBase64 !== 'string' || typeof mimeType !== 'string') {
      return jsonResponse({ error: 'Provide imageBase64 and mimeType.' }, 400);
    }
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(mimeType)) {
      return jsonResponse({ error: 'Use a JPEG, PNG, or WebP image.' }, 400);
    }
    // Keep requests within the app's existing 5 MB photo limit.
    const estimatedBytes = Math.floor(imageBase64.length * 3 / 4);
    if (!imageBase64 || estimatedBytes > 5_000_000 ||
      !/^[A-Za-z0-9+/]*={0,2}$/.test(imageBase64)) {
      return jsonResponse({ error: 'The image is empty, invalid, or over 5 MB.' }, 400);
    }

    const geminiResponse = await fetch(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:generateContent',
      {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': apiKey,
        },
        body: JSON.stringify({
          contents: [{
            parts: [
              {
                inline_data: { mime_type: mimeType, data: imageBase64 },
              },
              {
                text: 'Look at the cloud in this image and make a playful, imaginative shape guess. Return only JSON with keys "description" (one short sentence) and "alternatives" (an array of 2 or 3 short guesses). Do not claim certainty. If no cloud is visible, say so kindly and still offer imaginative guesses based on the visible shapes.',
              },
            ],
          }],
          generationConfig: {
            responseMimeType: 'application/json',
            responseSchema: {
              type: 'OBJECT',
              properties: {
                description: { type: 'STRING' },
                alternatives: {
                  type: 'ARRAY',
                  minItems: 2,
                  maxItems: 3,
                  items: { type: 'STRING' },
                },
              },
              required: ['description', 'alternatives'],
            },
          },
        }),
      },
    );

    if (!geminiResponse.ok) {
      // Record only status and provider error category; never log the key or
      // raw upstream response body.
      const providerError = await geminiResponse.json().catch(() => null);
      const status = providerError?.error?.status;
      console.error('Gemini request failed', {
        httpStatus: geminiResponse.status,
        errorStatus: typeof status === 'string' ? status : 'unknown',
      });
      const message = geminiResponse.status === 401 ||
          geminiResponse.status === 403
        ? 'Gemini rejected the server key or this project does not have access to the model.'
        : geminiResponse.status === 429
        ? 'Gemini usage limit reached. Please wait and try again.'
        : 'Could not get a cloud guess right now.';
      return jsonResponse({ error: message }, 502);
    }

    const result = await geminiResponse.json();
    const text = result?.candidates?.[0]?.content?.parts
      ?.map((part: { text?: string }) => part.text ?? '')
      .join('')
      .trim();
    if (typeof text !== 'string' || !text) {
      return jsonResponse({ error: 'Gemini returned no cloud guess.' }, 502);
    }
    const guess = JSON.parse(text);
    if (typeof guess.description !== 'string' ||
      !Array.isArray(guess.alternatives) ||
      guess.alternatives.length < 2 || guess.alternatives.length > 3 ||
      !guess.alternatives.every((item: unknown) => typeof item === 'string')) {
      return jsonResponse({ error: 'Gemini returned an unexpected response.' }, 502);
    }
    return jsonResponse({
      description: guess.description,
      alternatives: guess.alternatives,
    });
  } catch {
    return jsonResponse({ error: 'The request was invalid or could not be processed.' }, 400);
  }
});
