import { basename } from "node:path";
import type { OutputFormat, Segment, TranscriptionResult } from "./types.js";

function pad(n: number, width = 2): string {
  return String(Math.floor(n)).padStart(width, "0");
}

function formatTimestamp(seconds: number, withMs = false): string {
  const total = Math.max(0, seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = Math.floor(total % 60);
  if (!withMs) {
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
  }
  const ms = Math.round((total - Math.floor(total)) * 1000);
  return `${pad(h)}:${pad(m)}:${pad(s)}.${String(ms).padStart(3, "0")}`;
}

function srtTimestamp(seconds: number): string {
  const total = Math.max(0, seconds);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = Math.floor(total % 60);
  const ms = Math.round((total - Math.floor(total)) * 1000);
  return `${pad(h)}:${pad(m)}:${pad(s)},${String(ms).padStart(3, "0")}`;
}

function vttTimestamp(seconds: number): string {
  return srtTimestamp(seconds).replace(",", ".");
}

interface FormatContext {
  inputPath: string;
  title?: string;
  generatedAt: Date;
}

export function toMarkdown(
  result: TranscriptionResult,
  ctx: FormatContext,
): string {
  const title = ctx.title ?? basename(ctx.inputPath);
  const lines: string[] = [];

  // Frontmatter — Claudeが構造化情報として読みやすい
  lines.push("---");
  lines.push(`title: ${JSON.stringify(title)}`);
  lines.push(`source: ${JSON.stringify(basename(ctx.inputPath))}`);
  lines.push(`language: ${result.language}`);
  lines.push(`duration_sec: ${Math.round(result.duration)}`);
  lines.push(`duration_hms: ${formatTimestamp(result.duration)}`);
  lines.push(`segment_count: ${result.segments.length}`);
  lines.push(`generated_at: ${ctx.generatedAt.toISOString()}`);
  lines.push("---");
  lines.push("");

  lines.push(`# ${title}`);
  lines.push("");
  lines.push("> このファイルは音声からの文字起こしです。`## Transcript` セクションを要約し、知識マップを作成してください。");
  lines.push("");

  lines.push("## Metadata");
  lines.push("");
  lines.push(`- **Source file**: \`${basename(ctx.inputPath)}\``);
  lines.push(`- **Language**: ${result.language}`);
  lines.push(`- **Duration**: ${formatTimestamp(result.duration)} (${Math.round(result.duration)}s)`);
  lines.push(`- **Segments**: ${result.segments.length}`);
  lines.push("");

  lines.push("## Summary Hooks");
  lines.push("");
  lines.push("<!-- Claude: 以下の項目を埋めてください -->");
  lines.push("- **要点** (3-5項目):");
  lines.push("- **登場人物 / 話者**:");
  lines.push("- **キーワード**:");
  lines.push("- **意思決定 / アクションアイテム**:");
  lines.push("- **未解決の論点**:");
  lines.push("");

  lines.push("## Transcript");
  lines.push("");

  if (result.segments.length === 0) {
    lines.push(result.text || "_(no transcript)_");
  } else {
    for (const [idx, seg] of result.segments.entries()) {
      // postprocess の paragraphs ステップで paragraphStart=true が立ったセグメントの直前に空行を挿入
      // （先頭セグメントは除く）
      if (idx > 0 && seg.paragraphStart) {
        lines.push("");
      }
      const ts = formatTimestamp(seg.start);
      lines.push(`- \`[${ts}]\` ${seg.text}`);
    }
  }

  lines.push("");
  return lines.join("\n");
}

export function toPlainText(result: TranscriptionResult): string {
  if (result.segments.length === 0) {
    return result.text;
  }
  return result.segments.map((s) => s.text).join("\n");
}

function formatSrt(segments: Segment[]): string {
  return segments
    .map((seg, idx) => {
      const start = srtTimestamp(seg.start);
      const end = srtTimestamp(seg.end);
      return `${idx + 1}\n${start} --> ${end}\n${seg.text}\n`;
    })
    .join("\n");
}

function formatVtt(segments: Segment[]): string {
  const body = segments
    .map((seg) => {
      const start = vttTimestamp(seg.start);
      const end = vttTimestamp(seg.end);
      return `${start} --> ${end}\n${seg.text}\n`;
    })
    .join("\n");
  return `WEBVTT\n\n${body}`;
}

export function format(
  result: TranscriptionResult,
  fmt: OutputFormat,
  ctx: FormatContext,
): string {
  switch (fmt) {
    case "md":
      return toMarkdown(result, ctx);
    case "txt":
      return toPlainText(result);
    case "srt":
      return formatSrt(result.segments);
    case "vtt":
      return formatVtt(result.segments);
    case "json":
      return JSON.stringify(
        {
          source: basename(ctx.inputPath),
          title: ctx.title ?? basename(ctx.inputPath),
          generated_at: ctx.generatedAt.toISOString(),
          ...result,
        },
        null,
        2,
      );
    default: {
      const _exhaustive: never = fmt;
      throw new Error(`Unsupported format: ${String(_exhaustive)}`);
    }
  }
}

export function defaultExtension(fmt: OutputFormat): string {
  return fmt;
}
