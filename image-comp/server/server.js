const express = require("express");
const multer = require("multer");
const cors = require("cors");

const app = express();
const PORT = Number.parseInt(process.env.PORT || "3001", 10);
const MAX_FILE_SIZE = 25 * 1024 * 1024;

app.use(cors());

const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: MAX_FILE_SIZE,
    files: 2,
    fields: 0,
    parts: 4,
    fieldNameSize: 100,
    headerPairs: 50,
  },
  fileFilter: (_req, file, callback) => {
    if (!file.mimetype.startsWith("image/")) {
      return callback(new multer.MulterError("LIMIT_UNEXPECTED_FILE", file.fieldname));
    }
    callback(null, true);
  },
});

app.post(
  "/upload",
  upload.fields([
    { name: "original", maxCount: 1 },
    { name: "compressed", maxCount: 1 },
  ]),
  (req, res) => {
    if (!req.files || Object.keys(req.files).length === 0) {
      return res.status(400).json({ error: "No files uploaded" });
    }

    const result = {};
    for (const [fieldName, files] of Object.entries(req.files)) {
      result[fieldName] = {
        originalName: files[0].originalname,
        size: files[0].size,
      };
    }

    res.json({ success: true, files: result });
  }
);

app.use((error, _req, res, next) => {
  if (!(error instanceof multer.MulterError)) {
    return next(error);
  }

  const status = error.code === "LIMIT_FILE_SIZE" ? 413 : 400;
  return res.status(status).json({ error: error.message, code: error.code });
});

app.use((_error, _req, res, _next) => {
  res.status(500).json({ error: "Internal server error" });
});

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
