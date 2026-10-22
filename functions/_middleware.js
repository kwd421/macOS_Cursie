// Sends visitors on the old pages.dev address to the same path on the custom
// domain. The Sparkle feed and release notes never reach this function (see
// docs/_routes.json): installed apps poll cursie.pages.dev/appcast.xml directly.
const OLD_HOST = 'cursie.pages.dev';
const NEW_HOST = 'cursie.90wish.com';

// Search Console HTML-file verification for the old property must stay reachable.
const KEEP_ON_OLD_HOST = /^\/google[0-9a-f]+\.html$/;

export async function onRequest(context) {
  const url = new URL(context.request.url);
  // Normalize so "cursie.pages.dev." (fully qualified) and mixed case also redirect.
  const host = url.hostname.replace(/\.$/, '').toLowerCase();
  if (host === OLD_HOST && !KEEP_ON_OLD_HOST.test(url.pathname)) {
    url.hostname = NEW_HOST;
    url.protocol = 'https:';
    return Response.redirect(url.toString(), 301);
  }
  return context.next();
}
