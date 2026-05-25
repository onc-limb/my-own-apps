export type OutputFormat = "md" | "txt" | "srt" | "vtt" | "json";

export type PreprocessStep =
  | "silence-trim"
  | "normalize"
  | "denoise"
  | "voice-band";

export const PREPROCESS_STEPS: PreprocessStep[] = [
  "silence-trim",
  "normalize",
  "denoise",
  "voice-band",
];

export type PostprocessStep = "dedupe" | "fillers" | "paragraphs";

export const POSTPROCESS_STEPS: PostprocessStep[] = [
  "dedupe",
  "fillers",
  "paragraphs",
];

export interface Segment {
  id: number;
  start: number;
  end: number;
  text: string;
  /** paragraphs ステップ適用時に、この segment が新しい段落の先頭であれば true */
  paragraphStart?: boolean;
}

export interface TranscriptionResult {
  language: string;
  duration: number;
  text: string;
  segments: Segment[];
}

export interface TranscribeOptions {
  inputPath: string;
  outputPath?: string;
  format: OutputFormat;
  language?: string;
  model: string;
  modelRootPath?: string;
  keepTempFiles: boolean;
  title?: string;
  /** whisper の 1 セグメント最大長（whisper.cpp `-ml`） */
  segmentLength?: number;
  /** 単語ごとのタイムスタンプを出力 */
  wordTimestamps?: boolean;
  /** 入力音声に適用する ffmpeg 前処理ステップ（指定順に適用） */
  preprocess?: PreprocessStep[];
  /** whisper コンテキストプロンプト */
  prompt?: string;
  /** 文字起こし後処理ステップ（指定順に適用） */
  postprocess?: PostprocessStep[];
  /** paragraphs ステップで段落区切りとみなす無音時間 (秒) */
  paragraphGapSec?: number;
  /** VAD（Voice Activity Detection）を有効化。無音・環境音区間の幻聴ループを抑止する */
  vad?: boolean;
  /** VAD 閾値（0.0-1.0）。値を上げると発話判定が厳しくなる */
  vadThreshold?: number;
}

export interface ProviderContext {
  tmpDir: string;
  onProgress?: (message: string) => void;
}
