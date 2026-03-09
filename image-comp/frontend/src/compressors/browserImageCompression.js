import imageCompression from 'browser-image-compression';

/**
 * browser-image-compression で画像を圧縮する
 * @param {File} file - 元画像ファイル
 * @param {'webp' | 'avif'} format - 出力形式
 * @returns {Promise<Blob>} 圧縮後の Blob
 */
export async function compress(file, format) {
  const mimeType = format === 'avif' ? 'image/avif' : 'image/webp';

  const options = {
    maxSizeMB: 10,
    maxWidthOrHeight: 4096,
    useWebWorker: true,
    fileType: mimeType,
  };

  const compressed = await imageCompression(file, options);
  return compressed;
}
