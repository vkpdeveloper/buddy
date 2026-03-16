export function poundsToKg(value: number) {
    return Math.round((value * 0.45359237) * 100) / 100;
}

export function inchesToCm(value: number) {
    return Math.round((value * 2.54) * 10) / 10;
}
