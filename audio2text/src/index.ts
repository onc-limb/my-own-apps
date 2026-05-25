#!/usr/bin/env node
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { basename, dirname, extname, join, resolve } from "node:path";
import { Command } from "commander";
import ora from "ora";
import pc from "picocolors";
import { format as formatOutput, defaultExtension } from "./formatter.js";
import { MODEL_INFO, formatModelTable } from "./models.js";
import { SUPPORTED_MODELS, transcribe } from "./transcriber.js";
import type { ModelName } from "./transcriber.js";
import {
  POSTPROCESS_STEPS,
  PREPROCESS_STEPS,
  type OutputFormat,
  type PostprocessStep,
  type PreprocessStep,
  type TranscribeOptions,
  type TranscriptionResult,
} from "./types.js";

const SUPPORTED_FORMATS: OutputFormat[] = ["md", "txt", "srt", "vtt", "json"];

const DEFAULT_MODEL = "base";

function parseFormat(value: string): OutputFormat {
  const lower = value.toLowerCase() as OutputFormat;
  if (!SUPPORTED_FORMATS.includes(lower)) {
    throw new Error(
      `Unsupported format: ${value}. Choose from ${SUPPORTED_FORMATS.join(", ")}`,
    );
  }
  return lower;
}

function parsePreprocess(value: string | undefined): PreprocessStep[] {
  if (!value) return [];
  const items = value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  for (const item of items) {
    if (!PREPROCESS_STEPS.includes(item as PreprocessStep)) {
      throw new Error(
        `Unknown preprocess step: ${item}\nAvailable: ${PREPROCESS_STEPS.join(", ")}`,
      );
    }
  }
  return items as PreprocessStep[];
}

function parsePostprocess(value: string | undefined): PostprocessStep[] {
  if (!value) return [];
  const items = value
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  for (const item of items) {
    if (!POSTPROCESS_STEPS.includes(item as PostprocessStep)) {
      throw new Error(
        `Unknown postprocess step: ${item}\nAvailable: ${POSTPROCESS_STEPS.join(", ")}`,
      );
    }
  }
  return items as PostprocessStep[];
}

function inferOutputPath(inputPath: string, format: OutputFormat): string {
  const dir = dirname(inputPath);
  const stem = basename(inputPath, extname(inputPath));
  return join(dir, `${stem}.${defaultExtension(format)}`);
}

async function run(opts: TranscribeOptions): Promise<void> {
  const inputPath = resolve(opts.inputPath);
  const outputPath = resolve(
    opts.outputPath ?? inferOutputPath(inputPath, opts.format),
  );

  const info = MODEL_INFO[opts.model as ModelName];
  console.log(pc.dim(`Input :   ${inputPath}`));
  console.log(pc.dim(`Output:   ${outputPath}`));
  console.log(pc.dim(`Format:   ${opts.format}`));
  console.log(pc.dim(`Model :   ${opts.model}${info ? ` (${info.size}, ${info.tagline})` : ""}`));
  if (opts.language) console.log(pc.dim(`Language: ${opts.language}`));
  if (opts.preprocess && opts.preprocess.length > 0) {
    console.log(pc.dim(`Preproc:  ${opts.preprocess.join(" → ")}`));
  }
  if (opts.postprocess && opts.postprocess.length > 0) {
    console.log(pc.dim(`Postproc: ${opts.postprocess.join(" → ")}`));
  }
  if (opts.segmentLength) {
    console.log(pc.dim(`SegLen :  ${opts.segmentLength}`));
  }
  if (opts.wordTimestamps) {
    console.log(pc.dim(`Words :   word-level timestamps enabled`));
  }
  if (opts.prompt) {
    const preview = opts.prompt.length > 60 ? `${opts.prompt.slice(0, 57)}...` : opts.prompt;
    console.log(pc.dim(`Prompt:   ${preview}`));
  }
  if (opts.vad) {
    const th = typeof opts.vadThreshold === "number" ? opts.vadThreshold : 0.5;
    console.log(pc.dim(`VAD   :   enabled (threshold=${th})`));
  }
  console.log("");

  const tmpRoot = await mkdtemp(join(tmpdir(), "audio2text-"));

  const spinner = ora("Starting...").start();
  let result: TranscriptionResult;
  try {
    result = await transcribe(
      inputPath,
      {
        model: opts.model,
        language: opts.language,
        modelRootPath: opts.modelRootPath,
        segmentLength: opts.segmentLength,
        wordTimestamps: opts.wordTimestamps,
        preprocess: opts.preprocess,
        prompt: opts.prompt,
        postprocess: opts.postprocess,
        paragraphGapSec: opts.paragraphGapSec,
        vad: opts.vad,
        vadThreshold: opts.vadThreshold,
      },
      {
        tmpDir: tmpRoot,
        onProgress: (msg) => {
          spinner.text = msg;
        },
      },
    );
    spinner.succeed(
      `Transcribed: ${result.segments.length} segments, ${Math.round(result.duration)}s, language=${result.language}`,
    );
  } catch (err) {
    spinner.fail("Transcription failed");
    if (!opts.keepTempFiles) await rm(tmpRoot, { recursive: true, force: true });
    throw err;
  }

  const writeSpinner = ora("Writing output file...").start();
  try {
    const content = formatOutput(result, opts.format, {
      inputPath,
      title: opts.title,
      generatedAt: new Date(),
    });
    await mkdir(dirname(outputPath), { recursive: true });
    await writeFile(outputPath, content, "utf-8");
    writeSpinner.succeed(`Wrote ${outputPath}`);
  } catch (err) {
    writeSpinner.fail("Failed to write output");
    throw err;
  } finally {
    if (opts.keepTempFiles) {
      console.log(pc.dim(`Temp files kept at: ${tmpRoot}`));
    } else {
      await rm(tmpRoot, { recursive: true, force: true });
    }
  }

  console.log("");
  console.log(pc.green(`Done. Output: ${outputPath}`));
  if (opts.format === "md") {
    console.log(
      pc.dim(
        "Tip: open the .md in Claude and ask it to fill the 'Summary Hooks' section to build a knowledge map.",
      ),
    );
  }
}

async function readPromptFile(promptFile: string): Promise<string> {
  const text = await readFile(promptFile, "utf-8");
  return text.trim();
}

async function main(): Promise<void> {
  const program = new Command();

  program
    .name("audio2text")
    .description(
      "Transcribe long-form audio (e.g. 2-hour conversations) locally with whisper.cpp.\nNo API key required, fully offline.",
    )
    .version("0.4.0");

  program
    .command("models")
    .description("List supported Whisper models with pros and cons")
    .action(() => {
      console.log(formatModelTable());
    });

  program
    .argument("[input]", "Path to the input audio/video file")
    .option(
      "-f, --format <format>",
      `Output format (${SUPPORTED_FORMATS.join("|")})`,
      "md",
    )
    .option("-o, --output <path>", "Output file path (default: alongside input)")
    .option(
      "-l, --language <code>",
      "Language code (e.g. 'ja', 'en'). When set, whisper.cpp skips auto-detect",
    )
    .option(
      "-m, --model <name>",
      `Whisper model id (run \`audio2text models\` for the full list)`,
      DEFAULT_MODEL,
    )
    .option("-t, --title <text>", "Title for the markdown output (default: filename)")
    .option(
      "--model-root <path>",
      "Directory to store Whisper models (default: ~/.audio2text/models)",
    )
    .option(
      "--segment-length <n>",
      "Max tokens per transcript segment (whisper.cpp -ml). Default: 20. Recommended: 40-50 for summary use",
      (v) => Number.parseInt(v, 10),
    )
    .option(
      "--word-timestamps",
      "Emit per-word timestamps (forces -ml 1, segment-length is ignored)",
      false,
    )
    .option(
      "--preprocess <steps>",
      `Comma-separated audio preprocess pipeline (${PREPROCESS_STEPS.join("|")}). e.g. 'silence-trim,normalize'`,
    )
    .option(
      "--postprocess <steps>",
      `Comma-separated transcript postprocess pipeline (${POSTPROCESS_STEPS.join("|")}). e.g. 'dedupe,paragraphs'`,
    )
    .option(
      "--paragraph-gap <sec>",
      "Silence (sec) between segments to count as paragraph break (used with postprocess=paragraphs)",
      (v) => Number.parseFloat(v),
      2.0,
    )
    .option(
      "-p, --prompt <text>",
      "Whisper context prompt (proper nouns, jargon, style hints). Goes via whisper-cli --prompt",
    )
    .option(
      "--prompt-file <path>",
      "Read --prompt content from a file (overrides --prompt if both given)",
    )
    .option(
      "--vad",
      "Enable Voice Activity Detection (Silero VAD). Suppresses hallucination loops in silent / noisy regions.",
      false,
    )
    .option(
      "--vad-threshold <n>",
      "VAD threshold (0.0-1.0). Higher = stricter speech detection. Default 0.5",
      (v) => Number.parseFloat(v),
    )
    .option("--list-models", "Print supported models with pros/cons and exit")
    .option("--keep-temp", "Keep temporary wav/json files for debugging", false)
    .action(async (input: string | undefined, raw: Record<string, unknown>) => {
      try {
        if (raw.listModels) {
          console.log(formatModelTable());
          return;
        }
        if (!input) {
          throw new Error(
            `Missing <input> file. Use \`audio2text --help\` for usage, or \`audio2text models\` for the model list.`,
          );
        }

        const format = parseFormat(raw.format as string);
        const model = (raw.model as string) ?? DEFAULT_MODEL;
        if (!SUPPORTED_MODELS.includes(model as (typeof SUPPORTED_MODELS)[number])) {
          throw new Error(
            `Unknown model: ${model}\nRun \`audio2text models\` to see supported models.`,
          );
        }

        const preprocess = parsePreprocess(raw.preprocess as string | undefined);
        const postprocess = parsePostprocess(raw.postprocess as string | undefined);

        const paragraphGapRaw = raw.paragraphGap as number | undefined;
        const paragraphGapSec =
          typeof paragraphGapRaw === "number" && Number.isFinite(paragraphGapRaw) && paragraphGapRaw >= 0
            ? paragraphGapRaw
            : 2.0;

        const segmentLengthRaw = raw.segmentLength as number | undefined;
        const segmentLength =
          typeof segmentLengthRaw === "number" && Number.isFinite(segmentLengthRaw) && segmentLengthRaw > 0
            ? segmentLengthRaw
            : undefined;

        let prompt = (raw.prompt as string | undefined) ?? undefined;
        const promptFile = raw.promptFile as string | undefined;
        if (promptFile) {
          prompt = await readPromptFile(promptFile);
        }

        const vadThresholdRaw = raw.vadThreshold as number | undefined;
        const vadThreshold =
          typeof vadThresholdRaw === "number" && Number.isFinite(vadThresholdRaw) && vadThresholdRaw > 0
            ? vadThresholdRaw
            : undefined;

        await run({
          inputPath: input,
          outputPath: raw.output as string | undefined,
          format,
          language: raw.language as string | undefined,
          model,
          keepTempFiles: Boolean(raw.keepTemp),
          modelRootPath: raw.modelRoot as string | undefined,
          title: raw.title as string | undefined,
          segmentLength,
          wordTimestamps: Boolean(raw.wordTimestamps),
          preprocess,
          prompt,
          postprocess,
          paragraphGapSec,
          vad: Boolean(raw.vad),
          vadThreshold,
        });
      } catch (err) {
        console.error(pc.red(`\nError: ${(err as Error).message}`));
        process.exitCode = 1;
      }
    });

  await program.parseAsync(process.argv);
}

main().catch((err) => {
  console.error(pc.red(`Fatal: ${(err as Error).message}`));
  process.exit(1);
});
