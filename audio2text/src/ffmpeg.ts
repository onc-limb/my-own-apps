import { spawn } from "node:child_process";
import ffmpegStatic from "ffmpeg-static";

const FFMPEG_PATH: string =
  ((ffmpegStatic as unknown as { default?: string }).default ??
    (ffmpegStatic as unknown as string));

if (!FFMPEG_PATH) {
  throw new Error(
    "ffmpeg-static binary not found. Try `npm install` in the project root.",
  );
}

export function getFfmpegPath(): string {
  return FFMPEG_PATH;
}

export function runFfmpeg(args: string[]): Promise<string> {
  return new Promise((resolve, reject) => {
    const proc = spawn(FFMPEG_PATH, args, { stdio: ["ignore", "pipe", "pipe"] });
    let stdout = "";
    let stderr = "";
    proc.stdout.on("data", (chunk) => {
      stdout += chunk.toString();
    });
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0) {
        resolve(stdout || stderr);
      } else {
        reject(new Error(`ffmpeg exited with code ${code}:\n${stderr}`));
      }
    });
  });
}
