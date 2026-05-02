/**
 * Client fetch — base API configurable (VOIX_PUBLIC_API_BASE_URL en prod).
 */
const base =
  window.__VOIX_API_BASE__ ||
  `${window.location.protocol}//${window.location.hostname}:8080`;

document.getElementById("api-base").textContent = base;
