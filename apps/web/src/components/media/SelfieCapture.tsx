import { useEffect, useRef, useState } from "react";
import { StateCard } from "../feedback/StateCard";

export function SelfieCapture({
  onCapture,
}: {
  onCapture: (file: File) => void;
}) {
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [ready, setReady] = useState(false);
  useEffect(
    () => () => streamRef.current?.getTracks().forEach((track) => track.stop()),
    [],
  );
  async function start() {
    try {
      if (
        !window.isSecureContext &&
        !["localhost", "127.0.0.1"].includes(window.location.hostname)
      )
        throw new Error("Camera capture requires a secure HTTPS connection.");
      const stream = await navigator.mediaDevices.getUserMedia({
        video: {
          facingMode: "user",
          width: { ideal: 720 },
          height: { ideal: 720 },
        },
        audio: false,
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        await videoRef.current.play();
      }
      setReady(true);
    } catch (cause) {
      setError(
        cause instanceof Error
          ? cause.message
          : "Camera permission is required.",
      );
    }
  }
  function capture() {
    const video = videoRef.current;
    if (!video) return;
    const canvas = document.createElement("canvas");
    canvas.width = video.videoWidth || 720;
    canvas.height = video.videoHeight || 720;
    canvas
      .getContext("2d")
      ?.drawImage(video, 0, 0, canvas.width, canvas.height);
    canvas.toBlob(
      (blob) => {
        if (blob)
          onCapture(
            new File([blob], `attendance-${Date.now()}.jpg`, {
              type: "image/jpeg",
            }),
          );
      },
      "image/jpeg",
      0.86,
    );
  }
  if (error)
    return (
      <StateCard
        title="Camera unavailable"
        message={error}
        tone="error"
        action={
          <button
            className="secondary-button w-full"
            onClick={() => {
              setError(null);
              void start();
            }}
          >
            Try camera again
          </button>
        }
      />
    );
  return (
    <div className="space-y-3">
      <div className="overflow-hidden rounded-xl bg-slate-900">
        <video
          ref={videoRef}
          className={`aspect-square w-full object-cover ${ready ? "" : "hidden"}`}
          muted
          playsInline
        />
        <div
          className={`${ready ? "hidden" : "flex"} aspect-square items-center justify-center px-8 text-center text-sm text-white/70`}
        >
          Your live selfie stays private and is submitted only for this
          attendance action.
        </div>
      </div>
      {!ready ? (
        <button className="primary-button w-full" onClick={() => void start()}>
          Enable live camera
        </button>
      ) : (
        <button className="primary-button w-full" onClick={capture}>
          Capture selfie
        </button>
      )}
    </div>
  );
}
