export type RefreshDomain =
    | 'body'
    | 'diet'
    | 'growth'
    | 'home'
    | 'progress'
    | 'targets'
    | 'workout';

export type BuddyImmediateWriteResult = {
    kind: 'immediate_write';
    message: string;
    refreshDomains: RefreshDomain[];
    data?: Record<string, unknown>;
};

export function immediateWriteResult(params: {
    message: string;
    refreshDomains: RefreshDomain[];
    data?: Record<string, unknown>;
}): BuddyImmediateWriteResult {
    return {
        kind: 'immediate_write',
        message: params.message,
        refreshDomains: params.refreshDomains,
        ...(params.data ? { data: params.data } : {}),
    };
}
