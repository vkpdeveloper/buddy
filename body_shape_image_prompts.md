# Body Shape Image Prompts

Use these prompts to generate the 6 body-shape reference images for the onboarding flow.

**Requirements for all images:**
- Same fictional character — identical face, hair, skin tone, and height across all 6 images
- Pure solid black background (#0A0A0A) — no gradient, no radiance, no glow, no vignette, no texture
- Consistent lighting (soft studio light, front-facing)
- Minimal clothing: fitted athletic shorts for male, fitted athletic shorts + sports bra for female
- Strictly front-facing, looking directly into the camera — no rotation, no angle, no pose
- Realistic human proportions — NOT cartoon, NOT anime, NOT 3D render
- Square crop, 1:1 ratio

---

## Male — 3 images

### 1. Male — Skinny
> Same South Asian male character, skinny physique. Estimated 14–22% body fat but very low muscle mass — the body of someone who has never trained. Thin arms with no visible muscle definition, narrow shoulders, slim but soft torso with no ab definition, slightly bony frame. Not athletic. Not a runner's build. Just thin and untrained, like a typical college student who has never lifted weights. Athletic shorts. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

### 2. Male — Lean
> Same South Asian male character, lean/athletic physique. Estimated 8–15% body fat. Visible muscle tone with low body fat — defined abs, developed chest, broad shoulders, visible arm separation. Athletic and fit — the kind of body a dedicated gym-goer achieves after 1–3 years of consistent training. Athletic shorts. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

### 3. Male — Fat
> Same South Asian male character, higher body fat physique. Estimated 22–32% body fat. Rounded belly, softer jawline, fuller face, less muscle definition visible. Not exaggerated or mocking — a realistic, everyday body type that many people start from. Athletic shorts. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

---

## Female — 3 images

### 4. Female — Skinny
> Same South Asian female character, skinny physique. Estimated 22–28% body fat but very low muscle mass — the body of someone who has never trained. Thin arms with no visible muscle tone, narrow shoulders, slim but soft torso with no core definition. Not athletic. Not a dancer's build. Just thin and untrained, like a typical young woman who has never lifted weights. Fitted athletic shorts and sports bra. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

### 5. Female — Lean
> Same South Asian female character, lean/athletic physique. Estimated 14–22% body fat. Toned arms and shoulders, defined core, athletic legs with visible muscle tone. Fit and healthy — the kind of physique a woman achieves after consistent training and clean eating. Fitted athletic shorts and sports bra. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

### 6. Female — Fat
> Same South Asian female character, higher body fat physique. Estimated 30–40% body fat. Fuller figure with rounded abdomen, softer arms and legs, fuller face. Realistic and respectful — a common starting body type. Not exaggerated. Fitted athletic shorts and sports bra. Pure solid black background, no gradient or glow. Realistic, photographic style. Strictly front-facing, looking directly into the camera, no rotation or angle.

---

## Asset placement (once generated)

Save images as:
```
assets/images/body_shapes/
  male_skinny.png
  male_lean.png
  male_fat.png
  female_skinny.png
  female_lean.png
  female_fat.png
```

In `_buildBodyShapeGrid`, replace `_buildBodySilhouette(...)` with:
```dart
Image.asset(
  'assets/images/body_shapes/${_userSex}_${s.$1}.png',
  height: 60,
  fit: BoxFit.contain,
)
```

And register in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/images/body_shapes/
```
