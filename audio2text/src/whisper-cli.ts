import { spawn } from "node:child_process";
import { existsSync } from "node:fs";
import { createRequire } from "node:module";
import path, { basename, extname } from "node:path";
import { runFfmpeg } from "./ffmpeg.js";

// nodejs-whisper は CJS パッケージなので createRequire で内部モジュールにアクセスする。
const require = createRequire(import.meta.url);

interface NodejsWhisperConstants {
  WHISPER_CPP_PATH: string;
  MODEL_OBJECT: Record<string, string>;
  MODELS_LIST: string[];
}

const { WHISPER_CPP_PATH, MODEL_OBJECT } = require(
  "nodejs-whisper/dist/constants",
) as NodejsWhisperConstants;

type AutoDownloadModelFn = (
  logger: { debug: (...a: unknown[]) => void; error: (...a: unknown[]) => void },
  modelName: string,
  withCuda: boolean,
  modelRootPath: string,
) => Promise<string>;

const autoDownloadModelMod = require(
  "nodejs-whisper/dist/autoDownloadModel",
) as { default: AutoDownloadModelFn };

const autoDownloadModel = autoDownloadModelMod.default;

const SILENT_LOGGER = {
  debug: () => {},
  error: console.error,
  log: () => {},
};

export interface WhisperCliOptions {
  inputPath: string;
  modelName: string;
  modelRootPath: string;
  workDir: string;
  language?: string;
  segmentLength?: number;
  wordTimestamps?: boolean;
  prompt?: string;
  vad?: boolean;
  vadThreshold?: number;
}

const VAD_MODEL_FILENAME = "ggml-silero-v5.1.2.bin";
const VAD_MODEL_URL = `https://huggingface.co/ggml-org/whisper-vad/resolve/main/${VAD_MODEL_FILENAME}`;

function resolveBinaryPath(): string {
  const execName =
    process.platform === "win32" ? "whisper-cli.exe" : "whisper-cli";
  const candidates = [
    path.join(WHISPER_CPP_PATH, "build", "bin", execName),
    path.join(WHISPER_CPP_PATH, "build", "bin", "Release", execName),
    path.join(WHISPER_CPP_PATH, "build", "bin", "Debug", execName),
    path.join(WHISPER_CPP_PATH, "build", execName),
    path.join(WHISPER_CPP_PATH, execName),
  ];
  for (const p of candidates) {
    if (existsSync(p)) return p;
  }
  throw new Error(
    `whisper-cli binary not found under ${WHISPER_CPP_PATH}. Try \`npm install\` to rebuild whisper.cpp.`,
  );
}

async function ensureModelDownloaded(
  modelName: string,
  modelRootPath: string,
): Promise<string> {
  const modelFile = MODEL_OBJECT[modelName];
  if (!modelFile) {
    throw new Error(`Unknown model: ${modelName}`);
  }
  const modelPath = path.join(modelRootPath, modelFile);
  if (existsSync(modelPath)) return modelPath;

  // モデルが無い場合は nodejs-whisper の autoDownloadModel を流用してDL
  await autoDownloadModel(SILENT_LOGGER, modelName, false, modelRootPath);
  if (!existsSync(modelPath)) {
    throw new Error(`Model file still missing after download: ${modelPath}`);
  }
  return modelPath;
}

async function ensureVadModelDownloaded(modelRootPath: string): Promise<string> {
  const vadPath = path.join(modelRootPath, VAD_MODEL_FILENAME);
  if (existsSync(vadPath)) return vadPath;

  // HuggingFace から直接ダウンロード（curl にフォールバック）
  await new Promise<void>((resolve, reject) => {
    const proc = spawn(
      "curl",
      ["-L", "--fail", "--silent", "--show-error", "-o", vadPath, VAD_MODEL_URL],
      { stdio: ["ignore", "pipe", "pipe"] },
    );
    let stderr = "";
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0) resolve();
      else reject(new Error(`Failed to download VAD model (exit ${code}): ${stderr}`));
    });
  });

  if (!existsSync(vadPath)) {
    throw new Error(`VAD model still missing after download: ${vadPath}`);
  }
  return vadPath;
}

/**
 * whisper-cli を直接 spawn して文字起こしを実行する。
 * nodejs-whisper の WhisperOptions に公開されていない `--prompt` などのフラグを使うために用意した低レベル経路。
 *
 * 出力は workDir/<input-stem>.json に書き出される (whisper.cpp の `-oj -of` フラグ)。
 */
async function ensureWav(
  inputPath: string,
  workDir: string,
): Promise<string> {
  // whisper-cli は 16kHz mono の WAV しか受け付けない。
  // 入力フォーマットによらず必ず ffmpeg で変換する。
  const ext = extname(inputPath);
  const stem = basename(inputPath, ext);
  const wavPath = path.join(workDir, `${stem}.for-cli.wav`);
  if (existsSync(wavPath)) return wavPath;
  await runFfmpeg([
    "-hide_banner",
    "-loglevel",
    "error",
    "-y",
    "-i",
    inputPath,
    "-ac",
    "1",
    "-ar",
    "16000",
    "-vn",
    wavPath,
  ]);
  return wavPath;
}

export async function runWhisperCli(opts: WhisperCliOptions): Promise<string> {
  const binPath = resolveBinaryPath();
  const modelPath = await ensureModelDownloaded(
    opts.modelName,
    opts.modelRootPath,
  );

  const wavPath = await ensureWav(opts.inputPath, opts.workDir);
  const stem = basename(wavPath, extname(wavPath));
  const outputPrefix = path.join(opts.workDir, stem);

  const args: string[] = [
    "-m",
    modelPath,
    "-f",
    wavPath,
    "-oj", // output JSON
    "-of",
    outputPrefix,
    "-sow",
    "true",
    "-l",
    opts.language ?? "auto",
  ];

  // wordTimestamps は -ml 1、それ以外は segmentLength を渡す
  if (opts.wordTimestamps) {
    args.push("-ml", "1");
  } else if (opts.segmentLength && opts.segmentLength > 0) {
    args.push("-ml", String(opts.segmentLength));
  }

  if (opts.prompt && opts.prompt.length > 0) {
    args.push("--prompt", opts.prompt);
  }

  if (opts.vad) {
    const vadModelPath = await ensureVadModelDownloaded(opts.modelRootPath);
    args.push("--vad", "--vad-model", vadModelPath);
    if (typeof opts.vadThreshold === "number" && opts.vadThreshold > 0) {
      args.push("--vad-threshold", String(opts.vadThreshold));
    }
  }

  await new Promise<void>((resolve, reject) => {
    const proc = spawn(binPath, args, {
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stderr = "";
    proc.stderr.on("data", (chunk) => {
      stderr += chunk.toString();
    });
    proc.on("error", reject);
    proc.on("close", (code) => {
      if (code === 0) {
        resolve();
      } else {
        reject(
          new Error(
            `whisper-cli exited with code ${code}.\n${stderr.slice(-2000)}`,
          ),
        );
      }
    });
  });

  return `${outputPrefix}.json`;
}
