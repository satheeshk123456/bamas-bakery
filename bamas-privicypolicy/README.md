# bamas-privicypolicy

A tiny React + Vite single-page site that serves the Privacy Policy page for
the Bamas Burger Box app. Needed only because Google Play requires a public
privacy policy URL — the app itself has no web frontend.

The policy is shown at `/privicypolicy` (and also at `/privacypolicy` and
`/privacy-policy`, plus the root `/`, which all redirect to the same page).

## 1. Edit the content

Open `src/PrivacyPolicy.jsx` and update the contact email
(`support@bamasburgerbox.com`) to your real support email before deploying.

## 2. Install dependencies

```
npm install
```

## 3. Build

```
npm run build
```

This creates a `dist/` folder with the production build.

## 4. Deploy to Firebase Hosting (free)

If you haven't already:

```
npm install -g firebase-tools
firebase login
```

From inside this folder:

```
firebase init hosting
```

- "Use an existing project" → pick your Firebase project (you can reuse the
  same Firebase project as the Bamas app, or create a new one just for this).
- "What do you want to use as your public directory?" → type `dist`
- "Configure as a single-page app (rewrite all urls to /index.html)?" → `Yes`
- "Set up automatic builds and deploys with GitHub?" → `No` (unless you want it)
- If it asks to overwrite `dist/index.html`, say `No`.

Then deploy:

```
firebase deploy --only hosting
```

Firebase will print a live URL like:

```
https://YOUR-PROJECT-ID.web.app
```

Your privacy policy will be live at:

```
https://YOUR-PROJECT-ID.web.app/privicypolicy
```

Paste that URL into Play Console → Policy → App content → Privacy policy.

## Updating later

Whenever you change `src/PrivacyPolicy.jsx`, just run:

```
npm run build
firebase deploy --only hosting
```
