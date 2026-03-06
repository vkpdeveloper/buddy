import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateText } from 'ai';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { env } from './env';
import { r2Client } from './r2';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const MEAL_ANALYSIS_PROMPT = `You are a professional nutrition analyst with expertise in food recognition and macro estimation, similar to systems used by CalAI or Cronometer.

Analyze the meal photo carefully and identify ALL visible food items. For each item, estimate the portion size based on visual cues (plate size, utensils, standard serving sizes, density).

Return ONLY a valid JSON object with no markdown, no explanation, no code fences — just raw JSON:

{
  "ingredients": [
    {"name": "string (specific food name)", "quantity": "string (weight in grams or volume, e.g. '150g', '1 cup', '2 pieces')"}
  ],
  "macros": {
    "calories": number (total kcal, integer),
    "proteinG": number (total protein in grams, one decimal),
    "carbsG": number (total carbs in grams, one decimal),
    "fatG": number (total fat in grams, one decimal)
  },
  "confidence": number (0.0 to 1.0, where 1.0 = very clear photo with identifiable portions)
}

Guidelines:
- Be conservative: if unsure about quantity, estimate lower
- Use standard nutrition databases (USDA, Indian food composition tables for Indian foods)
- Identify cooking method (fried vs baked vs raw) and adjust fat accordingly
- If photo is blurry, partially visible, or not food, set confidence below 0.4
- Always return all four macro fields even if estimated as 0
- Do NOT include sauces or garnishes unless clearly visible in significant quantity`;

export interface MealAnalysisResult {
  ingredients: { name: string; quantity: string }[];
  macros: { calories: number; proteinG: number; carbsG: number; fatG: number };
  confidence: number;
}

async function fetchImageFromR2(objectKey: string): Promise<Uint8Array> {
  const response = await r2Client.send(
    new GetObjectCommand({
      Bucket: env.R2_BUCKET_NAME,
      Key: objectKey,
    }),
  );

  if (!response.Body) throw new Error('Empty response body from R2');
  return response.Body.transformToByteArray();
}

export async function analyzeMealImage(
  objectKey: string,
  _mimeType: string,
): Promise<MealAnalysisResult> {
  const imageBytes = await fetchImageFromR2(objectKey);

  const result = await generateText({
    model: google('gemini-1.5-flash'),
    messages: [
      {
        role: 'user',
        content: [
          {
            type: 'image',
            image: imageBytes,
          },
          { type: 'text', text: MEAL_ANALYSIS_PROMPT },
        ],
      },
    ],
  });

  const raw = result.text.trim();

  // Extract JSON from response (handle cases where model wraps in markdown)
  const jsonMatch = raw.match(/\{[\s\S]*\}/);
  if (!jsonMatch) throw new Error('No JSON found in AI response');

  const parsed = JSON.parse(jsonMatch[0]) as Record<string, unknown>;

  // Validate required fields
  if (!parsed.ingredients || !parsed.macros || parsed.confidence === undefined) {
    throw new Error('AI response missing required fields');
  }

  const macros = parsed.macros as Record<string, unknown>;

  return {
    ingredients: (parsed.ingredients as { name: string; quantity: string }[]),
    macros: {
      calories: Math.round(Number(macros.calories) || 0),
      proteinG: Math.round((Number(macros.proteinG) || 0) * 10) / 10,
      carbsG: Math.round((Number(macros.carbsG) || 0) * 10) / 10,
      fatG: Math.round((Number(macros.fatG) || 0) * 10) / 10,
    },
    confidence: Math.min(1, Math.max(0, Number(parsed.confidence) || 0)),
  };
}
