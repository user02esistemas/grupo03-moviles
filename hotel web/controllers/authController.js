const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');
const { OAuth2Client } = require('google-auth-library');
const db = require('../db');

const googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);
const regexCorreo = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const regexTelefono = /^[0-9+()\-\s]{7,20}$/;

const limpiarTexto = (valor) => (typeof valor === 'string' ? valor.trim() : '');
const normalizarCorreo = (correo) => limpiarTexto(correo).toLowerCase();
const normalizarRol = (rol) => {
    const valor = String(rol || '').toLowerCase();
    return valor === 'admin' || valor === 'administrador' ? 'Admin' : 'Cliente';
};

const idRolSql = (nombre) => `(SELECT id_rol FROM rol WHERE LOWER(nombre) = '${nombre}' LIMIT 1)`;

const firmarToken = (usuario) => {
    if (!process.env.JWT_SECRET) {
        throw new Error('JWT_SECRET no esta configurado.');
    }

    const rol = normalizarRol(usuario.rol);
    return jwt.sign(
        { id: usuario.id_usuario, rol },
        process.env.JWT_SECRET,
        { expiresIn: '24h' }
    );
};

const registrar = async (req, res) => {
    const nombre = limpiarTexto(req.body.nombre);
    const apellido = limpiarTexto(req.body.apellido);
    const correo = normalizarCorreo(req.body.correo);
    const telefono = limpiarTexto(req.body.telefono);
    const contrasena = String(req.body.contrasena || '');

    if (!nombre || !apellido || !correo || !telefono || !contrasena) {
        return res.status(400).json({ error: 'Todos los campos son obligatorios.' });
    }

    if (!regexCorreo.test(correo)) {
        return res.status(400).json({ error: 'El formato de correo electronico no es valido.' });
    }

    if (!regexTelefono.test(telefono)) {
        return res.status(400).json({ error: 'El telefono debe tener entre 7 y 20 caracteres validos.' });
    }

    if (contrasena.length < 6) {
        return res.status(400).json({ error: 'La contrasena debe tener al menos 6 caracteres.' });
    }

    try {
        const existe = await db.query(
            'SELECT id_usuario FROM usuario WHERE LOWER(correo::text) = $1 AND deleted_at IS NULL',
            [correo]
        );
        if (existe.rows.length > 0) {
            return res.status(409).json({ error: 'El correo electronico ya se encuentra registrado.' });
        }

        const hash = await bcrypt.hash(contrasena, 10);
        const query = `
            INSERT INTO usuario (nombre, apellido, correo, telefono, password_hash, id_rol, proveedor)
            VALUES ($1, $2, $3, $4, $5, ${idRolSql('cliente')}, 'local')
            RETURNING id_usuario, nombre, apellido, correo
        `;
        const result = await db.query(query, [nombre, apellido, correo, telefono, hash]);

        res.status(201).json({
            mensaje: 'Usuario registrado con exito',
            usuario: { ...result.rows[0], rol: 'Cliente' },
        });
    } catch (error) {
        res.status(500).json({ error: 'Error al registrar usuario: ' + error.message });
    }
};

const login = async (req, res) => {
    const correo = normalizarCorreo(req.body.correo);
    const contrasena = String(req.body.contrasena || '');

    if (!correo || !contrasena) {
        return res.status(400).json({ error: 'Por favor, introduce tu correo y contrasena.' });
    }

    try {
        const result = await db.query(
            `SELECT u.*, r.nombre AS rol_nombre, eu.nombre AS estado_usuario
             FROM usuario u
             JOIN rol r ON u.id_rol = r.id_rol
             JOIN estado_usuario eu ON u.id_estado_usuario = eu.id_estado_usuario
             WHERE LOWER(u.correo::text) = $1 AND u.deleted_at IS NULL`,
            [correo]
        );
        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Correo o contrasena incorrectos.' });
        }

        const usuario = result.rows[0];
        if (usuario.estado_usuario !== 'activo' || !usuario.password_hash) {
            return res.status(401).json({ error: 'Correo o contrasena incorrectos.' });
        }

        const coincide = await bcrypt.compare(contrasena, usuario.password_hash);
        if (!coincide) {
            return res.status(401).json({ error: 'Correo o contrasena incorrectos.' });
        }

        const rol = normalizarRol(usuario.rol_nombre);
        const token = firmarToken({ ...usuario, rol });

        res.json({
            mensaje: 'Login exitoso',
            token,
            rol,
            nombre: usuario.nombre,
        });
    } catch (error) {
        res.status(500).json({ error: 'Error en el servidor: ' + error.message });
    }
};

const googleLogin = async (req, res) => {
    const credential = req.body.credential;

    if (!credential) {
        return res.status(400).json({ error: 'No se recibio la credencial de Google.' });
    }

    if (!process.env.GOOGLE_CLIENT_ID) {
        return res.status(500).json({ error: 'GOOGLE_CLIENT_ID no esta configurado.' });
    }

    try {
        const ticket = await googleClient.verifyIdToken({
            idToken: credential,
            audience: process.env.GOOGLE_CLIENT_ID,
        });
        const payload = ticket.getPayload();
        const correo = normalizarCorreo(payload.email);
        const nombre = limpiarTexto(payload.given_name) || correo.split('@')[0];
        const apellido = limpiarTexto(payload.family_name);
        const googleSub = limpiarTexto(payload.sub);

        const userResult = await db.query(
            `SELECT u.*, r.nombre AS rol_nombre
             FROM usuario u
             JOIN rol r ON u.id_rol = r.id_rol
             WHERE LOWER(u.correo::text) = $1 AND u.deleted_at IS NULL`,
            [correo]
        );
        let usuario = userResult.rows[0];

        if (!usuario) {
            const insertQuery = `
                INSERT INTO usuario (nombre, apellido, correo, telefono, id_rol, proveedor, google_sub)
                VALUES ($1, $2, $3, 'No especificado', ${idRolSql('cliente')}, 'google', $4)
                RETURNING *, 'cliente' AS rol_nombre
            `;
            const insertResult = await db.query(insertQuery, [nombre, apellido, correo, googleSub]);
            usuario = insertResult.rows[0];
        } else if (usuario.proveedor === 'google' && !usuario.google_sub && googleSub) {
            await db.query('UPDATE usuario SET google_sub = $1 WHERE id_usuario = $2', [googleSub, usuario.id_usuario]);
        }

        const rol = normalizarRol(usuario.rol_nombre);
        const token = firmarToken({ ...usuario, rol });

        res.json({ mensaje: 'Login con Google exitoso', token, rol, nombre: usuario.nombre });
    } catch (error) {
        res.status(401).json({ error: 'Token de Google invalido o expirado.' });
    }
};

const obtenerPerfil = async (req, res) => {
    try {
        const query = `
            SELECT u.nombre, u.apellido, u.correo, u.telefono, r.nombre AS rol
            FROM usuario u
            JOIN rol r ON u.id_rol = r.id_rol
            WHERE u.id_usuario = $1 AND u.deleted_at IS NULL
        `;
        const result = await db.query(query, [req.usuario.id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        res.json({ ...result.rows[0], rol: normalizarRol(result.rows[0].rol) });
    } catch (error) {
        res.status(500).json({ error: 'Error al cargar el perfil: ' + error.message });
    }
};

const actualizarPerfil = async (req, res) => {
    const nombre = limpiarTexto(req.body.nombre);
    const apellido = limpiarTexto(req.body.apellido);
    const telefono = limpiarTexto(req.body.telefono);

    if (!nombre || !apellido || !telefono) {
        return res.status(400).json({ error: 'Nombre, apellido y telefono son obligatorios.' });
    }

    if (!regexTelefono.test(telefono)) {
        return res.status(400).json({ error: 'El telefono debe tener entre 7 y 20 caracteres validos.' });
    }

    try {
        const query = `
            UPDATE usuario
            SET nombre = $1, apellido = $2, telefono = $3
            WHERE id_usuario = $4
            RETURNING nombre, apellido, correo, telefono
        `;
        const result = await db.query(query, [nombre, apellido, telefono, req.usuario.id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Usuario no encontrado' });
        }

        res.json({ mensaje: 'Perfil actualizado con exito', usuario: { ...result.rows[0], rol: req.usuario.rol } });
    } catch (error) {
        res.status(500).json({ error: 'Error al actualizar el perfil: ' + error.message });
    }
};

module.exports = { registrar, login, googleLogin, obtenerPerfil, actualizarPerfil };
