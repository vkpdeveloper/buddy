import { createGoogleGenerativeAI } from '@ai-sdk/google';
import { generateObject } from 'ai';
import { z } from 'zod';
import { GetObjectCommand } from '@aws-sdk/client-s3';
import { env } from './env';
import { r2Client } from './r2';

const google = createGoogleGenerativeAI({ apiKey: env.GEMINI_API_KEY });

const MealAnalysisSchema = z.object({
    ingredients: z.array(z.object({
        name: z.string().describe('Specific food name'),
        quantity: z.string().describe("Weight in grams or volume, e.g. '150g', '1 cup', '2 pieces'"),
    })),
    macros: z.object({
        calories: z.number().describe('Total kcal, integer'),
        proteinG: z.number().describe('Total protein in grams, one decimal'),
        carbsG: z.number().describe('Total carbs in grams, one decimal'),
        fatG: z.number().describe('Total fat in grams, one decimal'),
    }),
    confidence: z.number().describe('0.0 to 1.0, where 1.0 = very clear photo with identifiable portions'),
});

const MEAL_ANALYSIS_PROMPT = `You are a professional nutrition analyst with expertise in food recognition and macro estimation, similar to systems used by CalAI or Cronometer.

Analyze the meal photo carefully and identify ALL visible food items. For each item, estimate the portion size based on visual cues (plate size, utensils, standard serving sizes, density).

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

  const { object } = await generateObject({
    model: google('gemini-1.5-flash'),
    schema: MealAnalysisSchema,
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

  return {
    ingredients: object.ingredients,
    macros: {
      calories: Math.round(object.macros.calories),
      proteinG: Math.round(object.macros.proteinG * 10) / 10,
      carbsG: Math.round(object.macros.carbsG * 10) / 10,
      fatG: Math.round(object.macros.fatG * 10) / 10,
    },
    confidence: Math.min(1, Math.max(0, object.confidence)),
  };
}
