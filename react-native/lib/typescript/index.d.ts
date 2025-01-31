export interface AttributionConfig {
    publisherId: string;
    appId: string;
    baseUrl: string;
    apiKey: string;
    enableDebugLogs?: boolean;
    connectionTimeoutSeconds?: number;
    readTimeoutSeconds?: number;
    retryCount?: number;
}
declare const Attribution: {
    initialize: (config: AttributionConfig) => Promise<void>;
    trackEvent: (eventType: "installation" | "subscription" | "activation", eventData: any) => Promise<void>;
};
export default Attribution;
//# sourceMappingURL=index.d.ts.map