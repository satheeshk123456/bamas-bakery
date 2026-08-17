/// DEMO MODE
///
/// true  -> the app runs against built-in fake orders, no backend needed.
///          Good for checking every screen before the FastAPI backend and
///          Firebase are wired up.
/// false -> the app talks to the real bamas-admin-backend FastAPI server.
const bool kDemoMode = true;

/// Base URL of the bamas-admin-backend FastAPI server. See
/// bamas-admin-backend/README.md for how to run it and which URL to use:
///  - Android emulator talking to a server on your own PC -> http://10.0.2.2:8000
///  - Real phone on the same Wi-Fi as your PC              -> http://<your-pc-lan-ip>:8000
///  - A deployed backend (Render/Railway/etc.)              -> https://your-app.onrender.com
const String kApiBaseUrl = 'http://10.0.2.2:8000';
