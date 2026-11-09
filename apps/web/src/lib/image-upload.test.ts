// @vitest-environment jsdom
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { prepareImageUpload } from "./image-upload";

const context = { fillStyle: "", fillRect: vi.fn(), drawImage: vi.fn() };
const revoke = vi.fn();
beforeEach(() => {
  vi.stubGlobal("URL", {
    createObjectURL: vi.fn(() => "blob:test"),
    revokeObjectURL: revoke,
  });
  vi.stubGlobal(
    "Image",
    class {
      naturalWidth = 1200;
      naturalHeight = 800;
      onload?: () => void;
      set src(_: string) {
        this.onload?.();
      }
    },
  );
  vi.spyOn(HTMLCanvasElement.prototype, "getContext").mockReturnValue(
    context as unknown as CanvasRenderingContext2D,
  );
  vi.spyOn(HTMLCanvasElement.prototype, "toBlob").mockImplementation(
    (callback) => callback(new Blob(["compressed"], { type: "image/jpeg" })),
  );
});
afterEach(() => {
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
  vi.clearAllMocks();
});

it("encodes image evidence at 60% and returns matching upload filename/type", async () => {
  const result = await prepareImageUpload(
    new File(["original"], "receipt.png", { type: "image/png" }),
  );
  expect(HTMLCanvasElement.prototype.toBlob).toHaveBeenCalledWith(
    expect.any(Function),
    "image/jpeg",
    0.6,
  );
  expect(result.name).toBe("receipt.jpg");
  expect(result.type).toBe("image/jpeg");
  expect(result.size).toBe(new Blob(["compressed"]).size);
  expect(context.drawImage).toHaveBeenCalled();
  expect(revoke).toHaveBeenCalledWith("blob:test");
});
it("preserves PDF evidence without attempting image conversion", async () => {
  const original = new File(["pdf"], "receipt.pdf", {
    type: "application/pdf",
  });
  expect(await prepareImageUpload(original)).toBe(original);
  expect(HTMLCanvasElement.prototype.toBlob).not.toHaveBeenCalled();
});
it("rejects encoding failures rather than uploading mismatched evidence metadata", async () => {
  vi.mocked(HTMLCanvasElement.prototype.toBlob).mockImplementation((callback) =>
    callback(null),
  );
  await expect(
    prepareImageUpload(
      new File(["image"], "receipt.png", { type: "image/png" }),
    ),
  ).rejects.toThrow("Could not compress");
  expect(revoke).toHaveBeenCalledWith("blob:test");
});
