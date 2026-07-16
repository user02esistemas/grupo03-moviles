const express = require('express');
const router = express.Router();
const pagoController = require('../controllers/pagoController');
const upload = require('../middlewares/upload');
const { verificarToken } = require('../middlewares/authMiddleware');

router.post('/comprobante', verificarToken, upload.single('comprobante'), pagoController.subirComprobante);
router.post('/crear-preferencia', verificarToken, pagoController.crearPreferencia);
router.post('/webhook', pagoController.recibirNotificacion);

module.exports = router;
