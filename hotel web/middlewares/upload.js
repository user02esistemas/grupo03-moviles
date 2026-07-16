const multer = require('multer');
const path = require('path');

const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, 'uploads/');
    },
    filename: (req, file, cb) => {
        const extension = path.extname(file.originalname).toLowerCase();
        cb(null, `comprobante-${Date.now()}${extension}`);
    },
});

const fileFilter = (req, file, cb) => {
    const extensionesPermitidas = ['.jpeg', '.jpg', '.png', '.pdf'];
    const mimetypesPermitidos = ['image/jpeg', 'image/png', 'application/pdf'];
    const extension = path.extname(file.originalname).toLowerCase();

    if (extensionesPermitidas.includes(extension) && mimetypesPermitidos.includes(file.mimetype)) {
        return cb(null, true);
    }

    cb(new Error('Solo se permiten archivos JPEG, JPG, PNG o PDF.'));
};

const upload = multer({
    storage,
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter,
});

module.exports = upload;
