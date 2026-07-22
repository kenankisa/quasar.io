// AdMob rewarded SSV callback → marks match_reward_claims attested.
// Deploy: supabase functions deploy admob-ssv --no-verify-jwt
// AdMob console SSV URL:
//   https://<project-ref>.supabase.co/functions/v1/admob-ssv
//
// custom_data from the app must be the prepare session UUID.
// user_id from SSV options should be the Supabase auth user id.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.49.1";

const KEYS_URL = "https://www.gstatic.com/admob/reward/verifier-keys.json";

type VerifierKey = { keyId: number; pem?: string; base64?: string };

function b64UrlToBytes(input: string): Uint8Array {
  const pad = "=".repeat((4 - (input.length % 4)) % 4);
  const b64 = (input + pad).replace(/-/g, "+").replace(/_/g, "/");
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function pemToSpki(pem: string): Uint8Array {
  const body = pem
    .replace(/-----BEGIN PUBLIC KEY-----/g, "")
    .replace(/-----END PUBLIC KEY-----/g, "")
    .replace(/\s+/g, "");
  const bin = atob(body);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

/** Convert ECDSA ASN.1 DER signature to raw r||s (64 bytes) for WebCrypto. */
function derToRawP256(der: Uint8Array): Uint8Array {
  let offset = 0;
  if (der[offset++] !== 0x30) throw new Error("bad_der");
  const seqLen = der[offset++];
  if (seqLen & 0x80) {
    const n = seqLen & 0x7f;
    offset += n;
  }
  if (der[offset++] !== 0x02) throw new Error("bad_der_r");
  let rLen = der[offset++];
  let r = der.subarray(offset, offset + rLen);
  offset += rLen;
  if (der[offset++] !== 0x02) throw new Error("bad_der_s");
  let sLen = der[offset++];
  let s = der.subarray(offset, offset + sLen);

  // Strip leading zeros / left-pad to 32 bytes.
  while (r.length > 32 && r[0] === 0) r = r.subarray(1);
  while (s.length > 32 && s[0] === 0) s = s.subarray(1);
  if (r.length > 32 || s.length > 32) throw new Error("bad_der_len");

  const raw = new Uint8Array(64);
  raw.set(r, 32 - r.length);
  raw.set(s, 64 - s.length);
  return raw;
}

async function loadKeys(): Promise<Map<number, CryptoKey>> {
  const res = await fetch(KEYS_URL);
  if (!res.ok) throw new Error(`keys_http_${res.status}`);
  const json = await res.json();
  const keys: VerifierKey[] = json.keys ?? [];
  const map = new Map<number, CryptoKey>();

  for (const k of keys) {
    const spki = k.pem
      ? pemToSpki(k.pem)
      : k.base64
      ? Uint8Array.from(atob(k.base64), (c) => c.charCodeAt(0))
      : null;
    if (!spki) continue;
    const cryptoKey = await crypto.subtle.importKey(
      "spki",
      spki,
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["verify"],
    );
    map.set(k.keyId, cryptoKey);
  }
  return map;
}

async function verifyAdMobSsv(url: URL): Promise<boolean> {
  const query = url.search.startsWith("?") ? url.search.slice(1) : url.search;
  const sigIdx = query.indexOf("&signature=");
  if (sigIdx < 0) return false;
  const content = query.slice(0, sigIdx);
  const signature = url.searchParams.get("signature");
  const keyIdRaw = url.searchParams.get("key_id");
  if (!signature || !keyIdRaw) return false;
  const keyId = Number(keyIdRaw);
  if (!Number.isFinite(keyId)) return false;

  const keys = await loadKeys();
  let key = keys.get(keyId);
  if (!key) {
    // Key rotation: refresh once.
    const refreshed = await loadKeys();
    key = refreshed.get(keyId);
  }
  if (!key) return false;

  const der = b64UrlToBytes(signature);
  const raw = derToRawP256(der);
  const data = new TextEncoder().encode(content);
  return await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" },
    key,
    raw,
    data,
  );
}

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "GET" && req.method !== "POST") {
      return json(405, { error: "method_not_allowed" });
    }

    const url = new URL(req.url);
    const ok = await verifyAdMobSsv(url);
    if (!ok) return json(401, { error: "invalid_signature" });

    const userId = url.searchParams.get("user_id")?.trim() ?? "";
    const customData = url.searchParams.get("custom_data")?.trim() ?? "";
    const transactionId = url.searchParams.get("transaction_id")?.trim() ?? "";

    if (!userId || !customData || !transactionId) {
      return json(400, { error: "missing_params" });
    }

    // custom_data = prepare session UUID (optionally "sessionId" JSON).
    let sessionId = customData;
    if (customData.startsWith("{")) {
      try {
        const parsed = JSON.parse(customData) as { session_id?: string; sessionId?: string };
        sessionId = parsed.session_id ?? parsed.sessionId ?? customData;
      } catch {
        // keep raw
      }
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceKey) {
      return json(500, { error: "missing_env" });
    }

    const admin = createClient(supabaseUrl, serviceKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { error } = await admin.rpc("ssv_attest_rewarded_match_double", {
      p_user_id: userId,
      p_session_id: sessionId,
      p_transaction_id: transactionId,
    });

    if (error) {
      console.error("ssv_attest failed", error.message);
      return json(400, { error: error.message });
    }

    return json(200, { ok: true });
  } catch (e) {
    console.error("admob-ssv error", e);
    return json(500, { error: "internal" });
  }
});
