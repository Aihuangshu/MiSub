/**
 * MiSub Worker runtime adapter.
 *
 * Upstream MiSub business code remains untouched. This adapter exposes the
 * Pages Functions handler as a standard Cloudflare Worker mounted at /misub.
 */

import { onRequest as handlePagesRequest } from '../functions/[[path]].js';

const BASE_PATH = '/misub';
const BASE_PATH_PREFIX = BASE_PATH + '/';

function toInternalUrl(requestUrl) {
    const url = new URL(requestUrl);

    if (url.pathname === BASE_PATH) {
        url.pathname = '/';
        return url;
    }

    if (url.pathname.startsWith(BASE_PATH_PREFIX)) {
        url.pathname = url.pathname.slice(BASE_PATH.length) || '/';
        return url;
    }

    return null;
}

function rewriteCookiePath(cookie) {
    return String(cookie).replace(
        /;\s*Path=\/(?=\s*(?:;|$))/i,
        '; Path=' + BASE_PATH + '/'
    );
}

function rewriteResponse(response, externalUrl) {
    if (!response || !(response instanceof Response)) return response;

    const headers = new Headers(response.headers);
    const location = headers.get('Location');

    if (location) {
        try {
            const external = new URL(externalUrl);
            const target = new URL(location, external);

            if (
                target.origin === external.origin &&
                target.pathname !== BASE_PATH &&
                !target.pathname.startsWith(BASE_PATH_PREFIX)
            ) {
                target.pathname = (BASE_PATH + target.pathname).replace(/\/{2,}/g, '/');
                headers.set('Location', target.toString());
            }
        } catch {
            // Preserve malformed/external redirects.
        }
    }

    const cookies =
        typeof headers.getSetCookie === 'function' ? headers.getSetCookie() : [];

    if (cookies.length) {
        headers.delete('Set-Cookie');
        for (const cookie of cookies) {
            headers.append('Set-Cookie', rewriteCookiePath(cookie));
        }
    } else {
        const cookie = headers.get('Set-Cookie');
        if (cookie) headers.set('Set-Cookie', rewriteCookiePath(cookie));
    }

    return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers,
    });
}

function buildContext(internalRequest, env, ctx) {
    return {
        request: internalRequest,
        env,
        params: {
            path: new URL(internalRequest.url).pathname.split('/').filter(Boolean),
        },
        waitUntil: (promise) => ctx.waitUntil(promise),
        next: () => env.ASSETS.fetch(internalRequest.clone()),
    };
}

export default {
    async fetch(request, env, ctx) {
        const internalUrl = toInternalUrl(request.url);

        if (!internalUrl) {
            return new Response('Not Found', {
                status: 404,
                headers: { 'Content-Type': 'text/plain; charset=UTF-8' },
            });
        }

        const internalRequest = new Request(internalUrl, request);

        try {
            const response = await handlePagesRequest(
                buildContext(internalRequest, env, ctx)
            );
            return rewriteResponse(response, request.url);
        } catch (error) {
            console.error('[MiSub Worker Adapter]', error);
            return new Response('Internal Server Error', { status: 500 });
        }
    },

    async scheduled(controller) {
        console.info('[MiSub Worker] Scheduled trigger:', controller.cron);
    },
};
