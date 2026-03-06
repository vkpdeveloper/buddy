import { db } from '../db';
import { exerciseCatalog } from '../db/schema';

const CATALOG: typeof exerciseCatalog.$inferInsert[] = [
    // ── Chest ──────────────────────────────────────────────────────────────────
    { name: 'Barbell Bench Press', description: 'Lie flat on a bench, grip barbell slightly wider than shoulder-width, lower to chest and press up. Primary chest compound.', muscleGroup: 'Chest', equipment: 'Barbell', category: 'compound' },
    { name: 'Incline Dumbbell Press', description: 'Bench set to 30-45 degrees, press dumbbells from chest height overhead. Targets upper chest.', muscleGroup: 'Chest', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Cable Fly', description: 'Stand between cables set at chest height, bring handles together in an arc. Full chest stretch and squeeze.', muscleGroup: 'Chest', equipment: 'Cable', category: 'isolation' },
    { name: 'Push-Up', description: 'Bodyweight press with hands shoulder-width apart, lower chest to floor and press back up.', muscleGroup: 'Chest', equipment: 'Bodyweight', category: 'compound' },
    { name: 'Dips', description: 'Suspend on parallel bars, lower body by bending elbows until shoulders dip below elbows, press back up.', muscleGroup: 'Chest', equipment: 'Bodyweight', category: 'compound' },
    { name: 'Dumbbell Floor Press', description: 'Lie on floor with dumbbells, press up from just above the floor. Safe for shoulder issues.', muscleGroup: 'Chest', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Incline Barbell Press', description: 'Incline bench at 30-45 degrees with barbell. Heavy upper chest movement.', muscleGroup: 'Chest', equipment: 'Barbell', category: 'compound' },
    { name: 'Pec Deck Machine', description: 'Seated chest fly using pec deck machine. Isolates chest with guided arc motion.', muscleGroup: 'Chest', equipment: 'Machine', category: 'isolation' },

    // ── Back ───────────────────────────────────────────────────────────────────
    { name: 'Pull-Up', description: 'Hang from bar with overhand grip, pull chin above bar by driving elbows down. Upper back and biceps.', muscleGroup: 'Back', equipment: 'Bodyweight', category: 'compound' },
    { name: 'Barbell Row', description: 'Hinge at hips, grip barbell with overhand grip, row bar to lower chest/upper abdomen. Thick back compound.', muscleGroup: 'Back', equipment: 'Barbell', category: 'compound' },
    { name: 'Seated Cable Row', description: 'Sit at cable station, pull handle to lower chest keeping elbows close to body. Mid back focus.', muscleGroup: 'Back', equipment: 'Cable', category: 'compound' },
    { name: 'Lat Pulldown', description: 'Kneel or sit under pulldown bar, pull wide bar to upper chest with overhand grip. Lat width.', muscleGroup: 'Back', equipment: 'Cable', category: 'compound' },
    { name: 'Face Pull', description: 'Cable set at head height with rope, pull rope to face with elbows high. Rear deltoid and upper back.', muscleGroup: 'Back', equipment: 'Cable', category: 'isolation' },
    { name: 'Chest-Supported Dumbbell Row', description: 'Lie chest-down on incline bench, row dumbbells toward hips. Removes lower back stress.', muscleGroup: 'Back', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Single-Arm Dumbbell Row', description: 'Brace on bench with one hand and knee, row dumbbell to hip with opposite arm.', muscleGroup: 'Back', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Deadlift', description: 'Stand over barbell, hinge and grip, drive hips forward to stand. Full posterior chain.', muscleGroup: 'Back', equipment: 'Barbell', category: 'compound' },

    // ── Legs ───────────────────────────────────────────────────────────────────
    { name: 'Barbell Squat', description: 'Bar across upper back, squat to parallel or below, drive through heels to stand. King of leg movements.', muscleGroup: 'Legs', equipment: 'Barbell', category: 'compound' },
    { name: 'Romanian Deadlift', description: 'Hold barbell at hips, hinge forward keeping back flat, feel hamstring stretch, return to standing.', muscleGroup: 'Legs', equipment: 'Barbell', category: 'compound' },
    { name: 'Leg Press', description: 'Seated on leg press machine, press platform away by extending knees. Quad dominant compound.', muscleGroup: 'Legs', equipment: 'Machine', category: 'compound' },
    { name: 'Leg Curl', description: 'Lie face down on leg curl machine, curl heels toward glutes. Hamstring isolation.', muscleGroup: 'Legs', equipment: 'Machine', category: 'isolation' },
    { name: 'Calf Raise', description: 'Stand with balls of feet on edge, raise heels as high as possible, lower slowly. Calf isolation.', muscleGroup: 'Legs', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Goblet Squat', description: 'Hold dumbbell or kettlebell at chest, squat deep keeping torso upright.', muscleGroup: 'Legs', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Bulgarian Split Squat', description: 'Rear foot elevated on bench, front foot forward, squat down on front leg. Unilateral quad focus.', muscleGroup: 'Legs', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Leg Extension', description: 'Sit on leg extension machine, extend legs to straight, control the lowering phase. Quad isolation.', muscleGroup: 'Legs', equipment: 'Machine', category: 'isolation' },
    { name: 'Hip Thrust', description: 'Shoulders on bench, barbell on lap, drive hips to ceiling squeezing glutes at top.', muscleGroup: 'Legs', equipment: 'Barbell', category: 'compound' },

    // ── Shoulders ─────────────────────────────────────────────────────────────
    { name: 'Overhead Press', description: 'Grip barbell at shoulder width, press overhead to lockout. Primary shoulder compound.', muscleGroup: 'Shoulders', equipment: 'Barbell', category: 'compound' },
    { name: 'Lateral Raise', description: 'Stand with dumbbells at sides, raise arms to shoulder height with slight elbow bend. Side delts.', muscleGroup: 'Shoulders', equipment: 'Dumbbell', category: 'isolation' },
    { name: 'Arnold Press', description: 'Start with dumbbells at chin, rotate palms outward as you press overhead. Full delt coverage.', muscleGroup: 'Shoulders', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Rear Delt Fly', description: 'Hinge forward, raise dumbbells out to sides with elbows slightly bent. Posterior delts.', muscleGroup: 'Shoulders', equipment: 'Dumbbell', category: 'isolation' },
    { name: 'Seated Dumbbell Press', description: 'Sit on upright bench, press dumbbells overhead from shoulder height.', muscleGroup: 'Shoulders', equipment: 'Dumbbell', category: 'compound' },
    { name: 'Cable Lateral Raise', description: 'Single cable at low position, raise arm to shoulder height. Consistent tension on side delt.', muscleGroup: 'Shoulders', equipment: 'Cable', category: 'isolation' },
    { name: 'Upright Row', description: 'Grip barbell narrow, pull bar vertically to chin with elbows leading. Traps and front delts.', muscleGroup: 'Shoulders', equipment: 'Barbell', category: 'compound' },

    // ── Arms ──────────────────────────────────────────────────────────────────
    { name: 'Barbell Curl', description: 'Grip barbell with underhand shoulder-width grip, curl bar to upper chest. Bicep mass builder.', muscleGroup: 'Arms', equipment: 'Barbell', category: 'isolation' },
    { name: 'Hammer Curl', description: 'Neutral grip with dumbbells, curl maintaining neutral wrist position. Brachialis and brachioradialis.', muscleGroup: 'Arms', equipment: 'Dumbbell', category: 'isolation' },
    { name: 'Tricep Pushdown', description: 'Cable at overhead position with bar or rope, push down extending arms. Tricep isolation.', muscleGroup: 'Arms', equipment: 'Cable', category: 'isolation' },
    { name: 'Skull Crusher', description: 'Lie on bench, lower barbell or EZ-bar toward forehead, extend back to top. Tricep mass.', muscleGroup: 'Arms', equipment: 'Barbell', category: 'isolation' },
    { name: 'Incline Dumbbell Curl', description: 'Sit on incline bench, curl dumbbells from full stretch. Excellent bicep stretch at bottom.', muscleGroup: 'Arms', equipment: 'Dumbbell', category: 'isolation' },
    { name: 'Overhead Tricep Extension', description: 'Hold dumbbell overhead with both hands, lower behind head, extend back up.', muscleGroup: 'Arms', equipment: 'Dumbbell', category: 'isolation' },
    { name: 'Cable Curl', description: 'Stand facing low cable, curl bar or rope to chin. Constant tension throughout.', muscleGroup: 'Arms', equipment: 'Cable', category: 'isolation' },
    { name: 'Diamond Push-Up', description: 'Hands in diamond shape close together, push up. Tricep dominant bodyweight movement.', muscleGroup: 'Arms', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Preacher Curl', description: 'Arm braced on preacher pad, curl barbell or dumbbells. Isolates bicep peak.', muscleGroup: 'Arms', equipment: 'Barbell', category: 'isolation' },

    // ── Core ──────────────────────────────────────────────────────────────────
    { name: 'Plank', description: 'Forearms and toes on floor, maintain rigid plank position. Anti-extension core stability.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Hanging Leg Raise', description: 'Hang from pull-up bar, raise straight legs to parallel or higher. Lower abs and hip flexors.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Cable Crunch', description: 'Kneel facing cable with rope at head, crunch torso toward knees. Weighted ab isolation.', muscleGroup: 'Core', equipment: 'Cable', category: 'isolation' },
    { name: 'Ab Wheel', description: 'Kneel with ab wheel, roll out to near-flat and roll back in. Anti-extension core challenge.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Russian Twist', description: 'Sit with feet raised, rotate torso side to side holding weight. Oblique focus.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Dead Bug', description: 'Lie on back with arms and legs raised, lower opposite arm and leg while keeping lower back pressed flat.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'Pallof Press', description: 'Stand perpendicular to cable, press handle straight out and back. Anti-rotation core strength.', muscleGroup: 'Core', equipment: 'Cable', category: 'isolation' },
    { name: 'Bicycle Crunch', description: 'Lie on back, alternate elbow-to-knee in cycling motion. Rectus and oblique combination.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
    { name: 'V-Up', description: 'Lie flat, simultaneously raise legs and torso meeting at the top to form a V shape.', muscleGroup: 'Core', equipment: 'Bodyweight', category: 'isolation' },
];

export async function seedCatalog(): Promise<void> {
    try {
        const existing = await db.select().from(exerciseCatalog).limit(1);
        if (existing.length > 0) return;
        await db.insert(exerciseCatalog).values(CATALOG);
        console.log(`[seedCatalog] Seeded ${CATALOG.length} exercises`);
    } catch (err) {
        console.error('[seedCatalog] Error:', err);
    }
}
