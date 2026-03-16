import type { Context } from 'hono';

const DATE_FORMATTER_CACHE = new Map<string, Intl.DateTimeFormat>();
const WEEKDAY_FORMATTER_CACHE = new Map<string, Intl.DateTimeFormat>();

function getDateFormatter(timeZone: string) {
    const cached = DATE_FORMATTER_CACHE.get(timeZone);
    if (cached) return cached;
    const formatter = new Intl.DateTimeFormat('en-CA', {
        timeZone,
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
    });
    DATE_FORMATTER_CACHE.set(timeZone, formatter);
    return formatter;
}

function getWeekdayFormatter(timeZone: string) {
    const cached = WEEKDAY_FORMATTER_CACHE.get(timeZone);
    if (cached) return cached;
    const formatter = new Intl.DateTimeFormat('en-US', {
        timeZone,
        weekday: 'long',
    });
    WEEKDAY_FORMATTER_CACHE.set(timeZone, formatter);
    return formatter;
}

export function isValidIanaTimeZone(value: string | null | undefined): value is string {
    if (!value) return false;
    try {
        getDateFormatter(value).format(new Date());
        return true;
    } catch {
        return false;
    }
}

export function normalizeIanaTimeZone(value: string | null | undefined) {
    return isValidIanaTimeZone(value) ? value : 'UTC';
}

export function getLocalDateInTimeZone(timeZone: string, date = new Date()) {
    const parts = getDateFormatter(normalizeIanaTimeZone(timeZone)).formatToParts(date);
    const year = parts.find((part) => part.type === 'year')?.value ?? '1970';
    const month = parts.find((part) => part.type === 'month')?.value ?? '01';
    const day = parts.find((part) => part.type === 'day')?.value ?? '01';
    return `${year}-${month}-${day}`;
}

export function getLocalWeekdayInTimeZone(timeZone: string, date = new Date()) {
    return getWeekdayFormatter(normalizeIanaTimeZone(timeZone)).format(date);
}

export function getDayNumberFromDate(date: string) {
    const weekday = new Date(`${date}T12:00:00.000Z`).getUTCDay();
    return weekday === 0 ? 7 : weekday;
}

export function getRequestTimeZone(c: Context) {
    return normalizeIanaTimeZone(c.req.header('X-Timezone'));
}
