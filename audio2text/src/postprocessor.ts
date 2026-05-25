import type {
  PostprocessStep,
  Segment,
  TranscriptionResult,
} from "./types.js";

/**
 * 日本語のフィラー語。長いものから先にマッチさせるため長さ降順で並べる。
 * 「あの」「その」のように本動詞・連体詞と紛らわしいものは前後の文脈に依存するため、
 * 句読点・空白・行頭/行末に隣接する場合のみ除去する保守的な戦略を採る。
 */
const FILLERS_JA = [
  "えーっと",
  "えーと",
  "えっと",
  "えーー",
  "えー",
  "あのー",
  "あのう",
  "あー",
  "あぁ",
  "うーん",
  "うんっと",
  "うんと",
  "んーー",
  "んー",
  "んっと",
  "んん",
  "そのー",
  "まあ",
  "まー",
  "ねー",
];

const FILLERS_EN = [
  "you know",
  "i mean",
  "uhm",
  "umm",
  "uh",
  "um",
  "erm",
  "er",
  "ahh",
  "ah",
];

function escapeRegex(s: string): string {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * 1つの segment テキストからフィラーを除去する。
 *
 * 戦略:
 *  - 日本語: 句読点 / 空白 / 行頭/行末に隣接するフィラーのみ削除
 *  - 英語: 単語境界 (\b) 基準で削除
 *  - 連続空白は単一空白に圧縮、両端トリム
 */
function removeFillersFromText(text: string, language?: string): string {
  let result = text;
  const lang = (language ?? "").toLowerCase();
  const isEnglish = lang.startsWith("en");

  const fillers = isEnglish ? FILLERS_EN : FILLERS_JA;

  for (const filler of fillers) {
    const escaped = escapeRegex(filler);
    if (isEnglish) {
      // 英語: 単語境界
      result = result.replace(new RegExp(`\\b${escaped}\\b[,.!?]?`, "gi"), "");
    } else {
      // 日本語: 文頭/句読点/空白の直後 + 句読点/空白/文末の直前 で挟まれているもの
      const re = new RegExp(
        `(^|[\\s、,。.!?！？「」『』])${escaped}(?=[\\s、,。.!?！？「」『』]|$)`,
        "g",
      );
      result = result.replace(re, "$1");
    }
  }

  // 連続空白の圧縮、両端トリム、句読点直前の空白除去
  return result
    .replace(/[ \t]+/g, " ")
    .replace(/\s+([、,。.!?！？])/g, "$1")
    .trim();
}

function normalizeForCompare(text: string): string {
  return text
    .normalize("NFKC")
    .replace(/[\s、,。.!?！？「」『』\-—_]+/g, "")
    .toLowerCase();
}

/**
 * 連続する重複セグメントを 1 つに集約する。
 * Whisper の繰り返し幻覚（"ご視聴ありがとうございました" の連発など）を抑える。
 *
 * - 完全一致だけでなく、正規化後の比較で一致するものを対象とする
 * - 集約された segment は最初のセグメントの start と最後のセグメントの end を持つ
 */
function dedupeSegments(segments: Segment[]): Segment[] {
  const result: Segment[] = [];
  for (const seg of segments) {
    const last = result[result.length - 1];
    if (last && normalizeForCompare(seg.text) === normalizeForCompare(last.text)) {
      last.end = Math.max(last.end, seg.end);
      continue;
    }
    result.push({ ...seg });
  }
  return result;
}

/**
 * セグメント間の無音 gap >= gapSec のところで段落区切りを入れる。
 * 各 segment に paragraphStart フラグを立てる（既存値は上書き）。
 */
function annotateParagraphs(
  segments: Segment[],
  gapSec: number,
): Segment[] {
  return segments.map((seg, idx) => {
    if (idx === 0) {
      return { ...seg, paragraphStart: true };
    }
    const prev = segments[idx - 1];
    const gap = seg.start - prev.end;
    return { ...seg, paragraphStart: gap >= gapSec };
  });
}

export interface PostprocessOptions {
  steps: PostprocessStep[];
  language?: string;
  paragraphGapSec?: number;
}

/**
 * TranscriptionResult に対して指定順に後処理を適用する。
 * 入力は変更せず、新しい TranscriptionResult を返す（純関数寄り）。
 */
export function applyPostprocess(
  result: TranscriptionResult,
  opts: PostprocessOptions,
): TranscriptionResult {
  if (!opts.steps || opts.steps.length === 0) return result;

  // 重複ステップは最初の出現位置のみ採用（同じ処理を2回かける意味は薄い）
  const seen = new Set<PostprocessStep>();
  const ordered = opts.steps.filter((s) => {
    if (seen.has(s)) return false;
    seen.add(s);
    return true;
  });

  let segments = result.segments.map((s) => ({ ...s }));

  for (const step of ordered) {
    switch (step) {
      case "dedupe":
        segments = dedupeSegments(segments);
        break;
      case "fillers":
        segments = segments
          .map((seg) => ({
            ...seg,
            text: removeFillersFromText(seg.text, opts.language ?? result.language),
          }))
          .filter((seg) => seg.text.length > 0);
        break;
      case "paragraphs":
        segments = annotateParagraphs(segments, opts.paragraphGapSec ?? 2.0);
        break;
      default: {
        const _exhaustive: never = step;
        throw new Error(`Unknown postprocess step: ${String(_exhaustive)}`);
      }
    }
  }

  // id を再採番（dedupe / fillers で要素が減っている場合があるため）
  segments = segments.map((seg, idx) => ({ ...seg, id: idx }));

  return {
    ...result,
    segments,
    text: segments.map((s) => s.text).join("\n"),
  };
}
