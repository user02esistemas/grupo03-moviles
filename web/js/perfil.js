/* ============================================================================
   Mi perfil (staff):
     PATCH /usuarios/me           {nombre, apellido, telefono}  (correo no editable)
     PATCH /usuarios/me/password  {password_actual, password_nueva}  -> 401 si actual incorrecta
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("perfil", usuario);

  /* ---- Datos personales -------------------------------------------------- */
  const formPerfil = document.getElementById("formPerfil");
  const pNombre = document.getElementById("pNombre");
  const pApellido = document.getElementById("pApellido");
  const pCorreo = document.getElementById("pCorreo");
  const pTelefono = document.getElementById("pTelefono");
  const btnGuardarPerfil = document.getElementById("btnGuardarPerfil");

  // Precargar desde la sesión guardada.
  pNombre.value = usuario.nombre || "";
  pApellido.value = usuario.apellido || "";
  pCorreo.value = usuario.correo || "";
  pTelefono.value = usuario.telefono || "";

  formPerfil.onsubmit = async (e) => {
    e.preventDefault();
    UI.limpiarErrores(formPerfil);
    let ok = true;
    if (!pNombre.value.trim()) { UI.marcarError(pNombre, "Requerido"); ok = false; }
    if (!pApellido.value.trim()) { UI.marcarError(pApellido, "Requerido"); ok = false; }
    if (!ok) return;

    UI.cargando(btnGuardarPerfil, true);
    try {
      const actualizado = await API.patch(ROUTES.usuarios.me, {
        nombre: pNombre.value.trim(),
        apellido: pApellido.value.trim(),
        telefono: pTelefono.value.trim() || null,
      });
      // Refrescar la sesión y la barra lateral con los datos nuevos.
      const nuevo = Object.assign({}, usuario, actualizado || {});
      API.setUsuario(nuevo);
      const pie = document.querySelector(".sidebar__pie .usuario");
      if (pie) pie.textContent = `${nuevo.nombre} ${nuevo.apellido}`;
      UI.ok("Perfil actualizado");
    } catch (err) {
      UI.errorToast(err.detail || "No se pudo actualizar el perfil");
    } finally {
      UI.cargando(btnGuardarPerfil, false);
    }
  };

  /* ---- Cambio de contraseña ---------------------------------------------- */
  const formPassword = document.getElementById("formPassword");
  const passActual = document.getElementById("passActual");
  const passNueva = document.getElementById("passNueva");
  const passRepite = document.getElementById("passRepite");
  const btnGuardarPassword = document.getElementById("btnGuardarPassword");

  formPassword.onsubmit = async (e) => {
    e.preventDefault();
    UI.limpiarErrores(formPassword);
    let ok = true;
    if (!passActual.value) { UI.marcarError(passActual, "Requerido"); ok = false; }
    if (!passNueva.value) { UI.marcarError(passNueva, "Requerido"); ok = false; }
    else if (passNueva.value.length < 8) { UI.marcarError(passNueva, "Mínimo 8 caracteres"); ok = false; }
    else if (passNueva.value === passActual.value) { UI.marcarError(passNueva, "Debe ser distinta a la actual"); ok = false; }
    if (passRepite.value !== passNueva.value) { UI.marcarError(passRepite, "No coincide"); ok = false; }
    if (!ok) return;

    UI.cargando(btnGuardarPassword, true);
    try {
      await API.patch(ROUTES.usuarios.password, {
        password_actual: passActual.value,
        password_nueva: passNueva.value,
      });
      UI.ok("Contraseña actualizada");
      formPassword.reset();
    } catch (err) {
      if (err.status === 401) UI.marcarError(passActual, "La contraseña actual es incorrecta");
      else UI.errorToast(err.detail || "No se pudo cambiar la contraseña");
    } finally {
      UI.cargando(btnGuardarPassword, false);
    }
  };
})();
