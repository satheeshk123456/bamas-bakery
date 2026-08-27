/// DEMO MODE
///
/// true  -> the app runs against built-in fake orders, no backend needed.
///          Good for checking every screen before the FastAPI backend and
///          Firebase are wired up.
/// false -> the app talks to the real bamas-admin-backend FastAPI server.
///
/// Set to false: the backend is deployed and reachable at kApiBaseUrl
/// below, and Firebase is configured (firebase_options.dart has real
/// keys) — so there's no reason to stay on fake data anymore.
const bool kDemoMode = false;

/// Base URL of the bamas-admin-backend FastAPI server — deployed on
/// Vercel.
const String kApiBaseUrl = 'https://bamas-admin-backend.vercel.app';
