const jwt = require('jsonwebtoken');

const normalizarRol = (rol) => {
    const valor = String(rol || '').toLowerCase();
    return valor === 'admin' || valor === 'administrador' ? 'Admin' : 'Cliente';
};

const verificarToken = (req, res, next) => {
    const authHeader = req.header('Authorization');
    if (!authHeader) {
        return res.status(401).json({ error: 'Acceso denegado. No se proporciono un token.' });
    }

    const [tipo, token] = authHeader.split(' ');
    if (tipo !== 'Bearer' || !token) {
        return res.status(401).json({ error: 'Formato de autorizacion invalido.' });
    }

    try {
        const verificado = jwt.verify(token, process.env.JWT_SECRET);
        req.usuario = {
            id: verificado.id,
            rol: normalizarRol(verificado.rol),
        };
        next();
    } catch (error) {
        res.status(401).json({ error: 'El token no es valido o ha expirado.' });
    }
};

const esAdmin = (req, res, next) => {
    if (req.usuario.rol !== 'Admin') {
        return res.status(403).json({ error: 'Acceso denegado. Se requieren privilegios de administrador.' });
    }
    next();
};

module.exports = { verificarToken, esAdmin };
