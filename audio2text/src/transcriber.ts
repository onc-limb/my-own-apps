import { copyFile, mkdir, readFile, readdir } from "node:fs/promises";
import { homedir } from "node:os";
import { basename, extname, join } from "node:path";
import { nodewhisper } from "nodejs-whisper";
import { applyPreprocess } from "./preprocessor.js";
import { applyPostprocess } from "./postprocessor.js";
import { runWhisperCli } from "./whisper-cli.js";
import { probeDurationSec } from "./splitter.js";
import type {
  PostprocessStep,
  PreprocessStep,
  ProviderContext,
  Segment,
  TranscriptionResult,
} from "./types.js";

/**
 * nodejs-whisper@0.3.0 がサポートするモデル ID。
 * 詳細・メリデメは README 参照。
 */
export const SUPPORTED_MODELS = [
  "tiny",
  "tiny.en",
  "base",
  "base.en",
  "small",
  "small.en",
  "medium",
  "medium.en",
  "large-v1",
  "large",
  "large-v3-turbo",
] as const;

export type ModelName = (typeof SUPPORTED_MODELS)[number];

const SUPPORTED_MODEL_SET = new Set<string>(SUPPORTED_MODELS);

export interface TranscribeLocalOptions {
  model: string;
  language?: string;
  modelRootPath?: string;
  segmentLength?: number;
  wordTimestamps?: boolean;
  preprocess?: PreprocessStep[];
  prompt?: string;
  postprocess?: PostprocessStep[];
  paragraphGapSec?: number;
  vad?: boolean;
  vadThreshold?: number;
}

interface WhisperJsonSegment {
  timestamps?: { from?: string; to?: string };
  offsets?: { from?: number; to?: number };
  text?: string;
}

interface WhisperJsonOutput {
  result?: { language?: string };
  transcription?: WhisperJsonSegment[];
}

function parseTimestamp(ts: string): number {
  const m = ts.match(/(\d+):(\d+):(\d+)[.,](\d+)/);
  if (!m) return 0;
  const [, hh, mm, ss, ms] = m;
  return Number(hh) * 3600 + Number(mm) * 60 + Number(ss) + Number(ms) / 1000;
}

function defaultModelRoot(): string {
  return join(homedir(), ".audio2text", "models");
}

export async function transcribe(
  inputPath: string,
  opts: TranscribeLocalOptions,
  ctx: ProviderContext,
): Promise<TranscriptionResult> {
  if (!SUPPORTED_MODEL_SET.has(opts.model)) {
    throw new Error(
      `Unsupported model: ${opts.model}\nSupported models: ${SUPPORTED_MODELS.join(", ")}`,
    );
  }

  const modelRootPath = opts.modelRootPath ?? defaultModelRoot();
  await mkdir(modelRootPath, { recursive: true });

  const workDir = join(ctx.tmpDir, "whisper");
  await mkdir(workDir, { recursive: true });
  const ext = extname(inputPath) || ".audio";
  const stem =
    basename(inputPath, ext).replace(/[^A-Za-z0-9_.-]+/g, "_") || "input";
  const stagedInput = join(workDir, `${stem}${ext}`);
  await copyFile(inputPath, stagedInput);

  // Step 1: 前処理（指定があれば）
  let preparedInput = stagedInput;
  if (opts.preprocess && opts.preprocess.length > 0) {
    ctx.onProgress?.(
      `Preprocessing audio (${opts.preprocess.join(" → ")})...`,
    );
    preparedInput = await applyPreprocess(stagedInput, workDir, opts.preprocess);
  }

  ctx.onProgress?.(`Loading whisper.cpp (model: ${opts.model})...`);

  // Step 2: prompt または VAD が指定されている場合は whisper-cli を直接呼ぶ。
  // nodejs-whisper@0.3.0 の WhisperOptions では prompt / VAD が公開されていないため。
  const usePrompt = Boolean(opts.prompt && opts.prompt.length > 0);
  if (usePrompt || opts.vad) {
    await runWhisperCli({
      inputPath: preparedInput,
      modelName: opts.model,
      modelRootPath,
      workDir,
      language: opts.language,
      segmentLength: opts.segmentLength,
      wordTimestamps: opts.wordTimestamps,
      prompt: opts.prompt,
      vad: opts.vad,
      vadThreshold: opts.vadThreshold,
    });
  } else {
    // prompt 不要なら nodejs-whisper の API を使う（モデル自動DLが楽）
    await nodewhisper(preparedInput, {
      modelName: opts.model,
      autoDownloadModelName: opts.model,
      modelRootPath,
      removeWavFileAfterTranscription: false,
      withCuda: false,
      logger: { log: () => {}, error: console.error, warn: () => {}, info: () => {}, debug: () => {} } as Console,
      whisperOptions: {
        outputInJson: true,
        outputInSrt: false,
        outputInVtt: false,
        outputInText: false,
        outputInWords: false,
        outputInLrc: false,
        outputInCsv: false,
        outputInJsonFull: false,
        translateToEnglish: false,
        wordTimestamps: opts.wordTimestamps ?? false,
        timestamps_length: opts.segmentLength ?? 20,
        splitOnWord: true,
        noGpu: false,
        ...(opts.language ? { language: opts.language } : {}),
      },
    });
  }

  const entries = await readdir(workDir);
  const jsonName = entries.find((f) => f.endsWith(".json"));
  if (!jsonName) {
    throw new Error(
      `Whisper did not produce a JSON output in ${workDir}. Files: ${entries.join(", ") || "(empty)"}`,
    );
  }
  const jsonPath = join(workDir, jsonName);
  const raw = await readFile(jsonPath, "utf-8");
  const parsed = JSON.parse(raw) as WhisperJsonOutput;

  const segments: Segment[] = [];
  const textParts: string[] = [];
  let lastEnd = 0;

  for (const [idx, seg] of (parsed.transcription ?? []).entries()) {
    const text = (seg.text ?? "").trim();
    if (!text) continue;

    const start =
      typeof seg.offsets?.from === "number"
        ? seg.offsets.from / 1000
        : parseTimestamp(seg.timestamps?.from ?? "00:00:00,000");
    const end =
      typeof seg.offsets?.to === "number"
        ? seg.offsets.to / 1000
        : parseTimestamp(seg.timestamps?.to ?? "00:00:00,000");

    segments.push({ id: idx, start, end, text });
    textParts.push(text);
    if (end > lastEnd) lastEnd = end;
  }

  let duration = lastEnd;
  if (duration === 0) {
    try {
      duration = await probeDurationSec(preparedInput);
    } catch {
      duration = 0;
    }
  }

  const baseResult: TranscriptionResult = {
    language: parsed.result?.language ?? opts.language ?? "auto",
    duration,
    text: textParts.join("\n"),
    segments,
  };

  // Postprocess: dedupe / fillers / paragraphs
  if (opts.postprocess && opts.postprocess.length > 0) {
    ctx.onProgress?.(
      `Postprocessing transcript (${opts.postprocess.join(" → ")})...`,
    );
    return applyPostprocess(baseResult, {
      steps: opts.postprocess,
      language: opts.language ?? baseResult.language,
      paragraphGapSec: opts.paragraphGapSec,
    });
  }

  return baseResult;
}
