import { apiRequest, apiUpload } from "../../lib/api-client";
import { newIdempotencyKey } from "../../lib/idempotency";
import type { FeeCard, PaymentRequest } from "../../types/domain";

export async function listFees(branchId: string, status?: string) {
  const query = new URLSearchParams({ period: "this_month" });
  if (status) query.set("status", status);
  const body = await apiRequest<{ data: FeeCard[]; meta?: unknown }>(
    `/branches/${branchId}/fees?${query.toString()}`,
  );
  return body.data;
}

export async function createEvidenceUploadSignature(
  branchId: string,
  filename: string,
  contentType: string,
) {
  const body = await apiRequest<{
    data: Record<string, string | number | null>;
  }>(`/branches/${branchId}/payment-evidence/upload-signature`, {
    method: "POST",
    body: JSON.stringify({ filename, content_type: contentType }),
  });
  return body.data;
}

export async function uploadToCloudinary(
  signature: Record<string, string | number | null>,
  file: File,
) {
  const cloudName = String(signature.cloud_name ?? "");
  const form = new FormData();
  form.append("file", file);
  form.append("api_key", String(signature.api_key ?? ""));
  form.append("timestamp", String(signature.timestamp ?? ""));
  form.append("signature", String(signature.signature ?? ""));
  form.append("folder", String(signature.folder ?? ""));
  if (signature.public_id)
    form.append("public_id", String(signature.public_id));
  if (signature.type) form.append("type", String(signature.type));
  return apiUpload<{
    secure_url?: string;
    public_id?: string;
    resource_type?: string;
  }>(`https://api.cloudinary.com/v1_1/${cloudName}/auto/upload`, form);
}

export async function createPaymentRequest(
  branchId: string,
  input: {
    subscription_id: string;
    amount_minor_unit: number;
    currency: string;
    method: string;
    reference?: string;
    note?: string;
    evidence?: Array<{
      storage_key: string;
      content_type: string;
      size_bytes?: number;
      reference?: string;
      note?: string;
    }>;
  },
) {
  const body = await apiRequest<{ data: PaymentRequest }>(
    `/branches/${branchId}/payment-requests`,
    {
      method: "POST",
      headers: { "Idempotency-Key": newIdempotencyKey("web-payment-request") },
      body: JSON.stringify(input),
    },
  );
  return body.data;
}

export async function listPaymentRequests(branchId: string) {
  const body = await apiRequest<{ data: PaymentRequest[] }>(
    `/branches/${branchId}/payment-requests`,
  );
  return body.data;
}
