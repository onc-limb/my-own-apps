import { compress as compressBIC } from './compressors/browserImageCompression.js';
import { compress as compressJsquash } from './compressors/jsquash.js';
import './style.css';

const fileInput = document.getElementById('fileInput');
const originalInfo = document.getElementById('originalInfo');
const compressBtn = document.getElementById('compressBtn');
const resultsSection = document.getElementById('results');
const statusEl = document.getElementById('status');

const resultOriginalSize = document.getElementById('resultOriginalSize');
const resultCompressedSize = document.getElementById('resultCompressedSize');
const resultRatio = document.getElementById('resultRatio');
const resultCompressTime = document.getElementById('resultCompressTime');
const resultRequestTime = document.getElementById('resultRequestTime');

function formatSize(bytes) {
  if (bytes < 1024) return `${bytes} B`;
  if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
  return `${(bytes / (1024 * 1024)).toFixed(2)} MB`;
}

function getSelectedLibrary() {
  return document.querySelector('input[name="library"]:checked').value;
}

function getSelectedFormat() {
  return document.querySelector('input[name="format"]:checked').value;
}

function setStatus(msg, isError = false) {
  statusEl.textContent = msg;
  statusEl.className = isError ? 'status error' : 'status';
}

fileInput.addEventListener('change', () => {
  const files = fileInput.files;
  if (files.length === 0) {
    originalInfo.textContent = '';
    compressBtn.disabled = true;
    return;
  }

  const totalSize = Array.from(files).reduce((sum, f) => sum + f.size, 0);
  originalInfo.textContent = `${files.length} 件選択 / 合計 ${formatSize(totalSize)}`;
  compressBtn.disabled = false;
});

compressBtn.addEventListener('click', async () => {
  const files = Array.from(fileInput.files);
  if (files.length === 0) return;

  const library = getSelectedLibrary();
  const format = getSelectedFormat();
  const compressFn = library === 'jsquash' ? compressJsquash : compressBIC;

  compressBtn.disabled = true;
  resultsSection.hidden = true;
  setStatus('圧縮中...');

  try {
    const originalTotalSize = files.reduce((sum, f) => sum + f.size, 0);

    // Compress all files
    const compressStart = performance.now();
    const compressedBlobs = await Promise.all(
      files.map((file) => compressFn(file, format))
    );
    const compressEnd = performance.now();
    const compressTime = compressEnd - compressStart;

    const compressedTotalSize = compressedBlobs.reduce((sum, b) => sum + b.size, 0);
    const ratio = ((1 - compressedTotalSize / originalTotalSize) * 100).toFixed(1);

    setStatus('サーバーに送信中...');

    // Build FormData with original and compressed files
    const formData = new FormData();
    const ext = format === 'avif' ? '.avif' : '.webp';
    files.forEach((file, i) => {
      formData.append('original', file, file.name);
      const compressedName = file.name.replace(/\.[^.]+$/, ext);
      formData.append('compressed', compressedBlobs[i], compressedName);
    });

    // Send to server
    const requestStart = performance.now();
    const response = await fetch('/api/upload', {
      method: 'POST',
      body: formData,
    });
    const requestEnd = performance.now();
    const requestTime = requestEnd - requestStart;

    if (!response.ok) {
      throw new Error(`サーバーエラー: ${response.status}`);
    }

    // Display results
    resultOriginalSize.textContent = formatSize(originalTotalSize);
    resultCompressedSize.textContent = formatSize(compressedTotalSize);
    resultRatio.textContent = `${ratio}%`;
    resultCompressTime.textContent = `${compressTime.toFixed(0)} ms`;
    resultRequestTime.textContent = `${requestTime.toFixed(0)} ms`;

    resultsSection.hidden = false;
    setStatus('');
  } catch (err) {
    setStatus(`エラー: ${err.message}`, true);
  } finally {
    compressBtn.disabled = false;
  }
});
