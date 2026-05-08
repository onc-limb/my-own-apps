import { extname, join } from "node:path";
import { runFfmpeg } from "./ffmpeg.js";
import type { PreprocessStep } from "./types.js";

/**
 * 各前処理ステップに対応する ffmpeg audio filter 表現。
 * 指定された順番にチェーンされる。
 */
const STEP_FILTERS: Record<PreprocessStep, string> = {
  // 無音区間の除去（先頭末尾＋連続無音）。閾値 -50dB / 連続 1 秒以上を対象。
  "silence-trim":
    "silenceremove=start_periods=1:start_duration=0.5:start_threshold=-50dB:detection=peak,silenceremove=stop_periods=-1:stop_duration=1:stop_threshold=-50dB:detection=peak",
  // EBU R128 ベースのラウドネス正規化。話声向けの一般的な値。
  normalize: "loudnorm=I=-16:TP=-1.5:LRA=11",
  // FFT ベースのノイズ除去。室内ノイズや空調音に有効。
  denoise: "afftdn=nf=-25",
  // 人声帯域 (80Hz-8kHz) を残す帯域フィルタ。低周波ノイズと不要な高域を削減。
  "voice-band": "highpass=f=80,lowpass=f=8000",
};

export function describeSteps(steps: PreprocessStep[]): string {
  return steps.map((s) => `${s} (${STEP_FILTERS[s]})`).join("; ");
}

/**
 * 指定された前処理ステップを順次適用し、結果の wav パスを返す。
 * 結果は 16kHz mono の WAV (whisper.cpp が要求する形式)。
 */
export async function applyPreprocess(
  inputPath: string,
  workDir: string,
  steps: PreprocessStep[],
): Promise<string> {
  if (steps.length === 0) {
    return inputPath;
  }

  // 重複ステップは1回に削減（同じフィルタを2回かける意味は薄い）
  const dedup: PreprocessStep[] = [];
  for (const step of steps) {
    if (!dedup.includes(step)) dedup.push(step);
  }

  const filterChain = dedup.map((s) => STEP_FILTERS[s]).join(",");
  const stem = inputPath.replace(extname(inputPath), "");
  const outputPath = `${stem}.preprocessed.wav`;

  await runFfmpeg([
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-i",
    inputPath,
    "-vn",
    "-ac",
    "1",
    "-ar",
    "16000",
    "-af",
    filterChain,
    outputPath,
  ]);

  // workDir の場所を尊重して返す
  return outputPath.startsWith(workDir) ? outputPath : join(workDir, outputPath);
}
