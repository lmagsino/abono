const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:3000";

type ApiHealth =
  | { ok: true; status: number }
  | { ok: false; status: number | null; error: string };

async function checkApi(): Promise<ApiHealth> {
  try {
    const response = await fetch(`${API_URL}/up`, { cache: "no-store" });

    return response.ok
      ? { ok: true, status: response.status }
      : { ok: false, status: response.status, error: response.statusText };
  } catch (error) {
    // The API being unreachable is a normal, expected outcome for a health
    // page, so it is reported rather than thrown.
    return {
      ok: false,
      status: null,
      error: error instanceof Error ? error.message : String(error),
    };
  }
}

export default async function HealthPage() {
  const api = await checkApi();

  return (
    <main className="mx-auto max-w-md p-8 font-sans">
      <h1 className="text-2xl font-semibold">Abono health</h1>

      <dl className="mt-6 space-y-4">
        <div className="flex items-baseline justify-between gap-4">
          <dt className="text-sm text-gray-500">Web</dt>
          <dd className="font-medium text-green-600">up</dd>
        </div>

        <div className="flex items-baseline justify-between gap-4">
          <dt className="text-sm text-gray-500">API</dt>
          <dd
            className={`font-medium ${api.ok ? "text-green-600" : "text-red-600"}`}
          >
            {api.ok ? `up (${api.status})` : "down"}
          </dd>
        </div>
      </dl>

      {!api.ok && (
        <p className="mt-6 text-sm text-red-600">
          {API_URL}/up — {api.error}
        </p>
      )}

      <p className="mt-8 text-xs text-gray-400">Checked against {API_URL}</p>
    </main>
  );
}
