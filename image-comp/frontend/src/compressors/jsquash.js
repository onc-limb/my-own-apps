import { encode as encodeWebP } from '@jsquash/webp';
import { encode as encodeAvif } from '@jsquash/avif';

/**
 * 画像ファイルを ImageData に変換する
 * @param {File} file
 * @returns {Promise<ImageData>}
 */
async function fileToImageData(file) {
  const bitmap = await createImageBitmap(file);
  const canvas = new OffscreenCanvas(bitmap.width, bitmap.height);
  const ctx = canvas.getContext('2d');
  ctx.drawImage(bitmap, 0, 0);
  bitmap.close();
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
}

/**
 * jsquash で画像を圧縮する
 * @param {File} file - 元画像ファイル
 * @param {'webp' | 'avif'} format - 出力形式
 * @returns {Promise<Blob>} 圧縮後の Blob
 */
export async function compress(file, format) {
  const imageData = await fileToImageData(file);

  let encoded;
  if (format === 'avif') {
    encoded = await encodeAvif(imageData);
  } else {
    encoded = await encodeWebP(imageData);
  }

  const mimeType = format === 'avif' ? 'image/avif' : 'image/webp';
  return new Blob([encoded], { type: mimeType });
}
