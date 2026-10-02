export function isSecureBrowserContext() {
  return (
    window.isSecureContext ||
    window.location.hostname === "localhost" ||
    window.location.hostname === "127.0.0.1"
  );
}

export async function readBrowserLocation() {
  if (!navigator.geolocation)
    throw new Error("This browser does not provide location access.");
  return new Promise<{ latitude: number; longitude: number; accuracy: number }>(
    (resolve, reject) => {
      navigator.geolocation.getCurrentPosition(
        (position) =>
          resolve({
            latitude: position.coords.latitude,
            longitude: position.coords.longitude,
            accuracy: position.coords.accuracy,
          }),
        () =>
          reject(
            new Error(
              "Location permission is required for this attendance policy.",
            ),
          ),
        { enableHighAccuracy: true, maximumAge: 15_000, timeout: 15_000 },
      );
    },
  );
}
