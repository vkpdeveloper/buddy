export class AppError extends Error {
    constructor(
        message: string,
        public readonly statusCode: number = 400,
        public readonly code?: string,
    ) {
        super(message);
        this.name = 'AppError';
    }
}

export const notFound = (msg: string) => new AppError(msg, 404, 'NOT_FOUND');
export const badRequest = (msg: string) => new AppError(msg, 400, 'BAD_REQUEST');
export const unauthorized = (msg: string) => new AppError(msg, 401, 'UNAUTHORIZED');
