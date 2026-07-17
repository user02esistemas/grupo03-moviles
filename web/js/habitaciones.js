/* ============================================================================
   Habitaciones: listado operativo (GET /admin/habitaciones), CRUD
   (POST/PATCH/DELETE /admin/habitaciones), cambio de estado y consulta de
   disponibilidad (GET /habitaciones?fecha_inicio&fecha_fin&personas).
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("habitaciones", usuario);
  UI.initModales();

  const esAdmin = Number(usuario.id_rol) === window.CONFIG.ROL_ADMIN;
  let TIPOS = [];       // catálogo de tipos para el select
  const habBody = document.getElementById("habBody");

  /* ---- Cargar tipos (para el select del formulario) ---------------------- */
  async function cargarTipos() {
    try { TIPOS = await API.get(ROUTES.admin.tiposHabitacion); }
    catch { TIPOS = []; }
  }

  /* ---- Poblar selects de estado ------------------------------------------ */
  function opcionesEstado(sel, seleccionado) {
    sel.innerHTML = Object.entries(window.CAT.estado_habitacion)
      .map(([id, e]) => `<option value="${id}" ${Number(id) === Number(seleccionado) ? "selected" : ""}>${e.txt}</option>`)
      .join("");
  }

  /* ---- LISTADO ----------------------------------------------------------- */
  async function cargarLista() {
    habBody.innerHTML = UI.skeletonRows(6);
    try {
      const habs = await API.get(ROUTES.admin.habitaciones);
      if (!habs.length) { habBody.innerHTML = UI.vacio(6, "No hay habitaciones registradas", "🛏️"); return; }
      habBody.innerHTML = habs.map(filaHab).join("");
      enlazarAcciones(habs);
    } catch (err) {
      habBody.innerHTML = `<tr><td colspan="6"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error al cargar")}</span></div></td></tr>`;
    }
  }

  function filaHab(h) {
    const tipo = h.tipo_nombre || (h.tipo && h.tipo.nombre_tipo) || "—";
    return `<tr data-id="${h.id_habitacion}">
      <td><strong>${UI.esc(h.numero_habitacion)}</strong></td>
      <td>${UI.esc(tipo)}</td>
      <td class="num">${UI.money(h.precio_noche)}</td>
      <td class="num">${UI.esc(h.capacidad)}</td>
      <td>${UI.badge(window.CAT.estado_habitacion, h.id_estado_habitacion)}</td>
      <td><div class="acciones">
        <button class="btn btn--sm btn--ghost" data-accion="estado">Estado</button>
        <a class="btn btn--sm btn--ghost" href="habitacion-detalle.html?id=${h.id_habitacion}">Imágenes</a>
        <button class="btn btn--sm btn--ghost" data-accion="editar">Editar</button>
        ${esAdmin ? `<button class="btn btn--sm btn--peligro" data-accion="eliminar">Eliminar</button>` : ""}
      </div></td>
    </tr>`;
  }

  function enlazarAcciones(habs) {
    const porId = Object.fromEntries(habs.map((h) => [h.id_habitacion, h]));
    habBody.querySelectorAll("tr[data-id]").forEach((tr) => {
      const h = porId[tr.dataset.id];
      tr.querySelector('[data-accion="estado"]').onclick = () => abrirEstado(h);
      tr.querySelector('[data-accion="editar"]').onclick = () => abrirEditar(h);
      const del = tr.querySelector('[data-accion="eliminar"]');
      if (del) del.onclick = () => eliminar(h);
    });
  }

  /* ---- CREAR / EDITAR ---------------------------------------------------- */
  const modalHab = "modalHab";
  const form = document.getElementById("formHab");
  const fId = document.getElementById("habId");
  const fNumero = document.getElementById("habNumero");
  const fTipo = document.getElementById("habTipo");
  const fPrecio = document.getElementById("habPrecio");
  const fCapacidad = document.getElementById("habCapacidad");
  const fEstado = document.getElementById("habEstado");
  const fDescripcion = document.getElementById("habDescripcion");
  const rowEstado = document.getElementById("rowEstado");
  const btnGuardar = document.getElementById("btnGuardarHab");

  function llenarTipos(seleccionado) {
    if (!TIPOS.length) {
      fTipo.innerHTML = `<option value="">— No hay tipos: créalos en "Tipos y servicios" —</option>`;
      return;
    }
    fTipo.innerHTML = TIPOS.map((t) =>
      `<option value="${t.id_tipo}" ${Number(t.id_tipo) === Number(seleccionado) ? "selected" : ""}>${UI.esc(t.nombre_tipo)}</option>`
    ).join("");
  }

  document.getElementById("btnNueva").onclick = () => {
    UI.limpiarErrores(form);
    form.reset();
    fId.value = "";
    document.getElementById("modalHabTitulo").textContent = "Nueva habitación";
    rowEstado.classList.remove("hidden");
    llenarTipos();
    opcionesEstado(fEstado, 1);
    UI.abrirModal(modalHab);
  };

  function abrirEditar(h) {
    UI.limpiarErrores(form);
    document.getElementById("modalHabTitulo").textContent = `Editar habitación ${h.numero_habitacion}`;
    fId.value = h.id_habitacion;
    fNumero.value = h.numero_habitacion;
    fPrecio.value = h.precio_noche;
    fCapacidad.value = h.capacidad;
    fDescripcion.value = h.descripcion || "";
    // En edición no se cambia el estado desde aquí (se usa el botón "Estado").
    rowEstado.classList.add("hidden");
    const idTipo = h.id_tipo || (h.tipo && h.tipo.id_tipo);
    llenarTipos(idTipo);
    UI.abrirModal(modalHab);
  }

  function validarHab() {
    UI.limpiarErrores(form);
    let ok = true;
    if (!fNumero.value.trim()) { UI.marcarError(fNumero, "Requerido"); ok = false; }
    else if (fNumero.value.trim().length > 10) { UI.marcarError(fNumero, "Máximo 10 caracteres"); ok = false; }
    if (!fTipo.value) { UI.marcarError(fTipo, "Selecciona un tipo"); ok = false; }
    const precio = parseFloat(fPrecio.value);
    if (fPrecio.value === "" || isNaN(precio) || precio < 0) { UI.marcarError(fPrecio, "Precio ≥ 0"); ok = false; }
    const cap = parseInt(fCapacidad.value, 10);
    if (isNaN(cap) || cap < 1) { UI.marcarError(fCapacidad, "Capacidad ≥ 1"); ok = false; }
    return ok;
  }

  form.onsubmit = async (e) => {
    e.preventDefault();
    if (!validarHab()) return;
    const esEdicion = !!fId.value;
    const payload = {
      id_tipo: Number(fTipo.value),
      numero_habitacion: fNumero.value.trim(),
      descripcion: fDescripcion.value.trim() || null,
      precio_noche: Number(parseFloat(fPrecio.value).toFixed(2)),
      capacidad: parseInt(fCapacidad.value, 10),
    };
    if (!esEdicion) payload.id_estado_habitacion = Number(fEstado.value);

    UI.cargando(btnGuardar, true);
    try {
      if (esEdicion) {
        await API.patch(ROUTES.admin.habitacion(fId.value), payload);
        UI.ok("Habitación actualizada");
      } else {
        await API.post(ROUTES.admin.habitaciones, payload);
        UI.ok("Habitación creada");
      }
      UI.cerrarModal(modalHab);
      cargarLista();
    } catch (err) {
      if (err.status === 409) UI.marcarError(fNumero, "Ese número ya existe");
      else UI.errorToast(err.detail || "No se pudo guardar");
    } finally {
      UI.cargando(btnGuardar, false);
    }
  };

  /* ---- CAMBIAR ESTADO ---------------------------------------------------- */
  const selNuevoEstado = document.getElementById("nuevoEstado");
  const btnGuardarEstado = document.getElementById("btnGuardarEstado");
  let habEstadoActual = null;

  function abrirEstado(h) {
    habEstadoActual = h;
    document.getElementById("estadoHabInfo").textContent =
      `Habitación ${h.numero_habitacion} — actual: ${window.CAT.estado_habitacion[h.id_estado_habitacion]?.txt || "—"}`;
    opcionesEstado(selNuevoEstado, h.id_estado_habitacion);
    UI.abrirModal("modalEstado");
  }

  btnGuardarEstado.onclick = async () => {
    if (!habEstadoActual) return;
    const nuevo = Number(selNuevoEstado.value);
    if (nuevo === Number(habEstadoActual.id_estado_habitacion)) { UI.cerrarModal("modalEstado"); return; }
    UI.cargando(btnGuardarEstado, true);
    try {
      await API.patch(ROUTES.admin.habitacionEstado(habEstadoActual.id_habitacion), { id_estado_habitacion: nuevo });
      UI.ok("Estado actualizado");
      UI.cerrarModal("modalEstado");
      cargarLista();
    } catch (err) {
      UI.errorToast(err.detail || "No se pudo cambiar el estado");
    } finally {
      UI.cargando(btnGuardarEstado, false);
    }
  };

  /* ---- ELIMINAR (solo administrador) ------------------------------------- */
  async function eliminar(h) {
    if (!confirm(`¿Eliminar la habitación ${h.numero_habitacion}? Esta acción no se puede deshacer.`)) return;
    try {
      await API.del(ROUTES.admin.habitacion(h.id_habitacion));
      UI.ok("Habitación eliminada");
      cargarLista();
    } catch (err) {
      if (err.status === 409) UI.errorToast("No se puede eliminar: tiene reservas asociadas");
      else if (err.status === 403) UI.errorToast("Solo un administrador puede eliminar habitaciones");
      else UI.errorToast(err.detail || "No se pudo eliminar");
    }
  }

  /* ---- DISPONIBILIDAD ---------------------------------------------------- */
  const dispIni = document.getElementById("dispIni");
  const dispFin = document.getElementById("dispFin");
  const dispPersonas = document.getElementById("dispPersonas");
  const dispResultado = document.getElementById("dispResultado");
  const dispBody = document.getElementById("dispBody");
  dispIni.value = UI.hoyISO();

  document.getElementById("btnBuscarDisp").onclick = async () => {
    if (!dispIni.value || !dispFin.value) { UI.errorToast("Elige fecha de ingreso y salida"); return; }
    if (dispFin.value <= dispIni.value) { UI.errorToast("La salida debe ser posterior al ingreso"); return; }
    dispResultado.classList.remove("hidden");
    dispBody.innerHTML = UI.skeletonRows(4, 3);
    try {
      const habs = await API.get(ROUTES.habitaciones.list, {
        fecha_inicio: dispIni.value, fecha_fin: dispFin.value,
        personas: dispPersonas.value || 1,
      });
      if (!habs.length) { dispBody.innerHTML = UI.vacio(4, "Sin habitaciones disponibles en ese rango", "🔒"); return; }
      dispBody.innerHTML = habs.map((h) =>
        `<tr><td><strong>${UI.esc(h.numero_habitacion)}</strong></td>
         <td>${UI.esc(h.tipo?.nombre_tipo || "—")}</td>
         <td class="num">${UI.esc(h.capacidad)}</td>
         <td class="num">${UI.money(h.precio_noche)}</td></tr>`
      ).join("");
    } catch (err) {
      dispBody.innerHTML = UI.vacio(4, err.detail || "Error al consultar disponibilidad", "⚠");
    }
  };
  document.getElementById("btnLimpiarDisp").onclick = () => {
    dispFin.value = ""; dispPersonas.value = 1; dispResultado.classList.add("hidden");
  };

  /* ---- Init -------------------------------------------------------------- */
  (async function init() {
    await cargarTipos();
    cargarLista();
  })();
})();
