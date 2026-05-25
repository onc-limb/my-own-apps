const express = require("express");
const multer = require("multer");
const cors = require("cors");

const app = express();
const PORT = 3001;

app.use(cors());

const upload = multer({ storage: multer.memoryStorage() });

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

app.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
