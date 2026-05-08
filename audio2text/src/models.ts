import type { ModelName } from "./transcriber.js";

export interface ModelDescriptor {
  /** ggml モデルファイルのおおよそのサイズ */
  size: string;
  /** 推論時に必要な RAM の目安 */
  ram: string;
  /** パラメータ数 */
  params: string;
  /** 速度感（音声長に対する処理速度の倍率, M1 CPU 目安） */
  speed: string;
  /** 多言語対応かどうか */
  multilingual: boolean;
  /** 日本語精度（×: 厳しい / △: 限定的 / ○: 実用 / ◎: 高精度） */
  japanese: "×" | "△" | "○" | "◎" | "—";
  /** 一行サマリ */
  tagline: string;
  /** メリット */
  pros: string[];
  /** デメリット */
  cons: string[];
  /** こういうケースで選ぶ */
  bestFor: string;
}

export const MODEL_INFO: Record<ModelName, ModelDescriptor> = {
  tiny: {
    size: "~75MB",
    ram: "~390MB",
    params: "39M",
    speed: "~32x rt",
    multilingual: true,
    japanese: "×",
    tagline: "最小・最速。プレビュー用途",
    pros: [
      "起動・推論が爆速、低スペックマシンでも動く",
      "モデルサイズが小さくダウンロード時間が短い",
      "リアルタイム書き起こしのプロトタイプ向き",
    ],
    cons: [
      "精度が低く、誤認識が多い",
      "日本語などの非英語はほぼ実用にならない",
      "話者の言い直しや専門用語に弱い",
    ],
    bestFor: "音声がきれいで内容のあたりをつけたいだけの英語音声、低スペック環境でのテスト",
  },
  "tiny.en": {
    size: "~75MB",
    ram: "~390MB",
    params: "39M",
    speed: "~32x rt",
    multilingual: false,
    japanese: "—",
    tagline: "英語専用 tiny",
    pros: [
      "tiny より英語精度が向上（多言語層を切り捨てた分）",
      "英語限定でリアルタイム/低レイテンシ用途に好適",
    ],
    cons: [
      "英語以外は使えない",
      "それでも複雑な英語会話では誤認識が多い",
    ],
    bestFor: "英語のみのライブ字幕プレビュー、開発時のスモークテスト",
  },
  base: {
    size: "~142MB",
    ram: "~500MB",
    params: "74M",
    speed: "~16x rt",
    multilingual: true,
    japanese: "△",
    tagline: "デフォルト。軽量・標準",
    pros: [
      "軽量でダウンロードが速く、初回セットアップに優しい",
      "英語なら一定の精度を保ちつつ高速",
      "2時間音声を約7〜10分で処理（M1基準）",
    ],
    cons: [
      "日本語精度は限定的、固有名詞や専門用語は誤りがち",
      "雑音や複数話者がいる環境ではやや弱い",
    ],
    bestFor: "とりあえず動かしてみたい時、英語のミーティング録音",
  },
  "base.en": {
    size: "~142MB",
    ram: "~500MB",
    params: "74M",
    speed: "~16x rt",
    multilingual: false,
    japanese: "—",
    tagline: "英語専用 base",
    pros: [
      "base より英語精度が高い",
      "英語の日常会話・ポッドキャスト書き起こしに十分",
    ],
    cons: [
      "英語以外は使えない",
      "コードネームや略語など固有表現は弱い",
    ],
    bestFor: "英語のみで現実的な精度と速度のバランスがほしい場面",
  },
  small: {
    size: "~466MB",
    ram: "~1GB",
    params: "244M",
    speed: "~6x rt",
    multilingual: true,
    japanese: "○",
    tagline: "多言語の実用ライン",
    pros: [
      "日本語でも実用的な精度に届く",
      "サイズと精度のバランスが良い",
      "M1/M2 で 2時間音声を 約20分で処理",
    ],
    cons: [
      "medium / large に比べると専門用語の誤認識は残る",
      "RAM 1GB 程度を消費するので低スペック環境では重め",
    ],
    bestFor: "日本語の打ち合わせを実用的に文字起こししたい時の最小ライン",
  },
  "small.en": {
    size: "~466MB",
    ram: "~1GB",
    params: "244M",
    speed: "~6x rt",
    multilingual: false,
    japanese: "—",
    tagline: "英語専用 small",
    pros: [
      "英語の精度が small より明確に向上",
      "業務用途に耐える英語書き起こしを高速で得られる",
    ],
    cons: [
      "英語以外は使えない",
    ],
    bestFor: "英語インタビュー・カンファレンス録画の業務利用",
  },
  medium: {
    size: "~1.5GB",
    ram: "~2.6GB",
    params: "769M",
    speed: "~2x rt",
    multilingual: true,
    japanese: "◎",
    tagline: "多言語の高精度ライン",
    pros: [
      "日本語含む多言語で高精度、固有名詞も拾いやすい",
      "長尺の会話でも安定したセグメント分割",
    ],
    cons: [
      "ファイルサイズが大きく初回DLが重い",
      "推論時間が長め（M1で2時間 ≈ 1〜1.5時間）",
      "RAM 2.6GB 必要",
    ],
    bestFor: "日本語の本番運用、会議議事録、インタビュー書き起こし",
  },
  "medium.en": {
    size: "~1.5GB",
    ram: "~2.6GB",
    params: "769M",
    speed: "~2x rt",
    multilingual: false,
    japanese: "—",
    tagline: "英語専用 medium",
    pros: [
      "英語の精度はトップクラス",
      "ノイズや訛りの多い英語にも強い",
    ],
    cons: [
      "英語以外は使えない",
      "推論時間とサイズは medium と同等",
    ],
    bestFor: "英語の高品質書き起こし。large はオーバースペックな時",
  },
  "large-v1": {
    size: "~3GB",
    ram: "~4.7GB",
    params: "1550M",
    speed: "~1x rt",
    multilingual: true,
    japanese: "○",
    tagline: "旧世代 large（後方互換用）",
    pros: [
      "large 系の元祖モデル",
      "v2/v3 と挙動を比較したい時の参照用",
    ],
    cons: [
      "v2/v3 に比べ精度が劣る",
      "サイズと推論時間は最新 large と同等で旨味が薄い",
      "新規プロジェクトで選ぶ理由はほぼ無い",
    ],
    bestFor: "再現性の検証、過去ワークフローとの整合性確認",
  },
  large: {
    size: "~3GB",
    ram: "~4.7GB",
    params: "1550M",
    speed: "~1x rt",
    multilingual: true,
    japanese: "◎",
    tagline: "最高精度（large-v3 相当）",
    pros: [
      "現行で最も高精度の多言語モデル",
      "ノイズ・訛り・専門用語に強い",
      "話者交代の検出も比較的安定",
    ],
    cons: [
      "ファイルサイズ ~3GB、RAM ~4.7GB と重い",
      "推論時間が長い（M1で2時間 ≈ 2〜3時間以上）",
      "GPUがないと現実的でない場面もある",
    ],
    bestFor: "精度最優先・時間に余裕がある業務用書き起こし",
  },
  "large-v3-turbo": {
    size: "~1.6GB",
    ram: "~2.5GB",
    params: "809M",
    speed: "~8x rt",
    multilingual: true,
    japanese: "◎",
    tagline: "large-v3 を蒸留した高速版・実質バランス最強",
    pros: [
      "large-v3 にほぼ匹敵する精度を保ちつつ大幅高速化",
      "サイズも RAM も medium 級まで削減",
      "2026 年現在の実用ベストバランス",
    ],
    cons: [
      "ごく一部のドメイン（音楽、極端な訛り）で large-v3 にわずかに劣る",
      "比較的新しいモデルなので情報が少なめ",
    ],
    bestFor: "迷ったらこれ。日本語の長尺会話を高精度かつ現実的な時間で処理したい時",
  },
};

function pad(s: string, width: number): string {
  return s + " ".repeat(Math.max(0, width - s.length));
}

export function formatModelTable(): string {
  const lines: string[] = [];
  lines.push("Supported Whisper models");
  lines.push("");
  const header = `${pad("Model", 18)}${pad("Size", 10)}${pad("RAM", 10)}${pad("Speed", 12)}${pad("ML", 4)}${pad("JA", 4)} Tagline`;
  lines.push(header);
  lines.push("-".repeat(header.length + 30));

  for (const [name, info] of Object.entries(MODEL_INFO) as [
    string,
    ModelDescriptor,
  ][]) {
    lines.push(
      `${pad(name, 18)}${pad(info.size, 10)}${pad(info.ram, 10)}${pad(info.speed, 12)}${pad(info.multilingual ? "yes" : "no", 4)}${pad(info.japanese, 4)} ${info.tagline}`,
    );
  }

  lines.push("");
  lines.push("Legend:");
  lines.push("  Speed = realtime ratio on Apple Silicon CPU (e.g. '16x rt' = 1h audio in ~3.75min)");
  lines.push("  ML    = multilingual (yes = supports Japanese; no = English-only)");
  lines.push("  JA    = Japanese accuracy (×/△/○/◎; — = English-only)");
  lines.push("");
  lines.push("For full pros/cons of each model, see README.md.");

  return lines.join("\n");
}
