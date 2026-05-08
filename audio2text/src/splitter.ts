import { runFfmpeg } from "./ffmpeg.js";

/**
 * 入力音声の長さ(秒)を ffmpeg の Duration 出力から取得。
 */
export async function probeDurationSec(inputPath: string): Promise<number> {
  const args = ["-hide_banner", "-i", inputPath, "-f", "null", "-"];
  let output = "";
  try {
    output = await runFfmpeg(args);
  } catch (err) {
    output = (err as Error).message;
  }

  const match = output.match(/Duration:\s*(\d+):(\d+):(\d+(?:\.\d+)?)/);
  if (!match) {
    throw new Error(`Failed to determine duration of ${inputPath}`);
  }
  const [, hh, mm, ss] = match;
  return Number(hh) * 3600 + Number(mm) * 60 + Number(ss);
}
