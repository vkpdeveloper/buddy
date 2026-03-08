import type { Context } from 'hono';
import type { ContentfulStatusCode } from 'hono/utils/http-status';

export type ApiSuccess<T> = { success: true; data: T };
export type ApiError = { success: false; error: string; code?: string };
export type ApiResponse<T> = ApiSuccess<T> | ApiError;

export function ok<T>(c: Context, data: T, status: ContentfulStatusCode = 200) {
    return c.json<ApiSuccess<T>>({ success: true, data }, status);
}

export function fail(c: Context, message: string, status: ContentfulStatusCode = 400, code?: string) {
    return c.json<ApiError>(
        { success: false, error: message, ...(code && { code }) },
        status,
    );
}
