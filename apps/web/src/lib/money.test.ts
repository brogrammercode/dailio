import { describe, expect, it } from "vitest";
import { formatMinorInput, parseMinorInput } from "./money";

describe("minor-unit payment input", () => {
  it("parses exact amounts without floating-point arithmetic", () => {
    expect(parseMinorInput("1200.05")).toBe(120005);
    expect(parseMinorInput("1.2")).toBe(120);
    expect(formatMinorInput(120005)).toBe("1200.05");
  });
  it("rejects zero, extra decimals and unsafe amounts", () => {
    expect(parseMinorInput("0")).toBeNull();
    expect(parseMinorInput("12.345")).toBeNull();
    expect(parseMinorInput("99999999999999999")).toBeNull();
    expect(parseMinorInput("21474836.48")).toBeNull();
  });
});
