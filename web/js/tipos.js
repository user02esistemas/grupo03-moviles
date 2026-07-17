/* ============================================================================
   Tipos de habitación y servicios.
     Tipos:     GET/POST /admin/tipos-habitacion, PATCH/DELETE /{id},
                PUT /admin/tipos-habitacion/{id}/servicios  {servicios:[ids]}
     Servicios: GET/POST /admin/servicios, PATCH/DELETE /{id}

   Nota: la API no expone un GET con los servicios actuales de un tipo, así que
   el modal de "Servicios del tipo" arranca sin marcar y REEMPLAZA el conjunto.
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("tipos", usuario);
  UI.initModales();

  let SERVICIOS = []; // cache para los checkboxes del modal de tipo

  const tiposBody = document.getElementById("tiposBody");
  const serviciosBody = document.getElementById("serviciosBody");

  /* ======================= TIPOS ========================================== */
  async function cargarTipos() {
    tiposBody.innerHTML = UI.skeletonRows(3);
    try {
      const tipos = await API.get(ROUTES.admin.tiposHabitacion);
      if (!tipos.length) { tiposBody.innerHTML = UI.vacio(3, "No hay tipos registrados", "🏷️"); return; }
      tiposBody.innerHTML = tipos.map(filaTipo).join("");
      enlazarTipos(tipos);
    } catch (err) {
      tiposBody.innerHTML = `<tr><td colspan="3"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error")}</span></div></td></tr>`;
    }
  }

  function filaTipo(t) {
    return `<tr data-id="${t.id_tipo}">
      <td><strong>${UI.esc(t.nombre_tipo)}</strong></td>
      <td>${t.descripcion ? UI.esc(t.descripcion) : '<span class="muted">—</span>'}</td>
      <td><div class="acciones">
        <button class="btn btn--sm btn--ghost" data-a="editar">Editar</button>
        <button class="btn btn--sm btn--ghost" data-a="servicios">Servicios</button>
        <button class="btn btn--sm btn--peligro" data-a="eliminar">Eliminar</button>
      </div></td>
    </tr>`;
  }

  function enlazarTipos(tipos) {
    const porId = Object.fromEntries(tipos.map((t) => [t.id_tipo, t]));
    tiposBody.querySelectorAll("tr[data-id]").forEach((tr) => {
      const t = porId[tr.dataset.id];
      tr.querySelector('[data-a="editar"]').onclick = () => abrirTipo(t);
      tr.querySelector('[data-a="servicios"]').onclick = () => abrirServiciosTipo(t);
      tr.querySelector('[data-a="eliminar"]').onclick = () => eliminarTipo(t);
    });
  }

  const formTipo = document.getElementById("formTipo");
  const tipoId = document.getElementById("tipoId");
  const tipoNombre = document.getElementById("tipoNombre");
  const tipoDescripcion = document.getElementById("tipoDescripcion");
  const btnGuardarTipo = document.getElementById("btnGuardarTipo");

  document.getElementById("btnNuevoTipo").onclick = () => {
    UI.limpiarErrores(formTipo); formTipo.reset(); tipoId.value = "";
    document.getElementById("modalTipoTitulo").textContent = "Nuevo tipo";
    UI.abrirModal("modalTipo");
  };
  function abrirTipo(t) {
    UI.limpiarErrores(formTipo);
    document.getElementById("modalTipoTitulo").textContent = "Editar tipo";
    tipoId.value = t.id_tipo; tipoNombre.value = t.nombre_tipo; tipoDescripcion.value = t.descripcion || "";
    UI.abrirModal("modalTipo");
  }

  formTipo.onsubmit = async (e) => {
    e.preventDefault();
    UI.limpiarErrores(formTipo);
    if (!tipoNombre.value.trim()) { UI.marcarError(tipoNombre, "Requerido"); return; }
    const payload = { nombre_tipo: tipoNombre.value.trim(), descripcion: tipoDescripcion.value.trim() || null };
    UI.cargando(btnGuardarTipo, true);
    try {
      if (tipoId.value) { await API.patch(ROUTES.admin.tipoHabitacion(tipoId.value), payload); UI.ok("Tipo actualizado"); }
      else { await API.post(ROUTES.admin.tiposHabitacion, payload); UI.ok("Tipo creado"); }
      UI.cerrarModal("modalTipo"); cargarTipos();
    } catch (err) {
      if (err.status === 409) UI.marcarError(tipoNombre, "Ese nombre ya existe");
      else UI.errorToast(err.detail || "No se pudo guardar");
    } finally { UI.cargando(btnGuardarTipo, false); }
  };

  async function eliminarTipo(t) {
    if (!confirm(`¿Eliminar el tipo "${t.nombre_tipo}"?`)) return;
    try { await API.del(ROUTES.admin.tipoHabitacion(t.id_tipo)); UI.ok("Tipo eliminado"); cargarTipos(); }
    catch (err) {
      if (err.status === 409) UI.errorToast("No se puede: hay habitaciones con ese tipo");
      else UI.errorToast(err.detail || "No se pudo eliminar");
    }
  }

  /* ---- Servicios de un tipo (PUT reemplaza el conjunto) ------------------ */
  const checksServicios = document.getElementById("checksServicios");
  const btnGuardarServiciosTipo = document.getElementById("btnGuardarServiciosTipo");
  let tipoServiciosActual = null;

  function abrirServiciosTipo(t) {
    tipoServiciosActual = t;
    document.getElementById("modalServiciosTipoTitulo").textContent = `Servicios de "${t.nombre_tipo}"`;
    if (!SERVICIOS.length) {
      checksServicios.innerHTML = `<p class="muted">No hay servicios. Créalos primero en la tabla de abajo.</p>`;
    } else {
      checksServicios.innerHTML = SERVICIOS.map((s) =>
        `<label style="display:flex;align-items:center;gap:6px;font-size:14px">
           <input type="checkbox" value="${s.id_servicio}" /> ${UI.esc(s.nombre)}
         </label>`).join("");
    }
    UI.abrirModal("modalServiciosTipo");
  }

  btnGuardarServiciosTipo.onclick = async () => {
    if (!tipoServiciosActual) return;
    const ids = Array.from(checksServicios.querySelectorAll("input:checked")).map((c) => Number(c.value));
    UI.cargando(btnGuardarServiciosTipo, true);
    try {
      await API.put(ROUTES.admin.tipoHabitacionServicios(tipoServiciosActual.id_tipo), { servicios: ids });
      UI.ok("Servicios del tipo actualizados");
      UI.cerrarModal("modalServiciosTipo");
    } catch (err) {
      UI.errorToast(err.detail || "No se pudieron guardar los servicios");
    } finally { UI.cargando(btnGuardarServiciosTipo, false); }
  };

  /* ======================= SERVICIOS ====================================== */
  async function cargarServicios() {
    serviciosBody.innerHTML = UI.skeletonRows(3);
    try {
      SERVICIOS = await API.get(ROUTES.admin.servicios);
      if (!SERVICIOS.length) { serviciosBody.innerHTML = UI.vacio(3, "No hay servicios registrados", "🧩"); return; }
      serviciosBody.innerHTML = SERVICIOS.map(filaServicio).join("");
      enlazarServicios(SERVICIOS);
    } catch (err) {
      serviciosBody.innerHTML = `<tr><td colspan="3"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error")}</span></div></td></tr>`;
    }
  }

  function filaServicio(s) {
    return `<tr data-id="${s.id_servicio}">
      <td><strong>${UI.esc(s.nombre)}</strong></td>
      <td>${s.descripcion ? UI.esc(s.descripcion) : '<span class="muted">—</span>'}</td>
      <td><div class="acciones">
        <button class="btn btn--sm btn--ghost" data-a="editar">Editar</button>
        <button class="btn btn--sm btn--peligro" data-a="eliminar">Eliminar</button>
      </div></td>
    </tr>`;
  }

  function enlazarServicios(servicios) {
    const porId = Object.fromEntries(servicios.map((s) => [s.id_servicio, s]));
    serviciosBody.querySelectorAll("tr[data-id]").forEach((tr) => {
      const s = porId[tr.dataset.id];
      tr.querySelector('[data-a="editar"]').onclick = () => abrirServicio(s);
      tr.querySelector('[data-a="eliminar"]').onclick = () => eliminarServicio(s);
    });
  }

  const formServicio = document.getElementById("formServicio");
  const servicioId = document.getElementById("servicioId");
  const servicioNombre = document.getElementById("servicioNombre");
  const servicioDescripcion = document.getElementById("servicioDescripcion");
  const btnGuardarServicio = document.getElementById("btnGuardarServicio");

  document.getElementById("btnNuevoServicio").onclick = () => {
    UI.limpiarErrores(formServicio); formServicio.reset(); servicioId.value = "";
    document.getElementById("modalServicioTitulo").textContent = "Nuevo servicio";
    UI.abrirModal("modalServicio");
  };
  function abrirServicio(s) {
    UI.limpiarErrores(formServicio);
    document.getElementById("modalServicioTitulo").textContent = "Editar servicio";
    servicioId.value = s.id_servicio; servicioNombre.value = s.nombre; servicioDescripcion.value = s.descripcion || "";
    UI.abrirModal("modalServicio");
  }

  formServicio.onsubmit = async (e) => {
    e.preventDefault();
    UI.limpiarErrores(formServicio);
    if (!servicioNombre.value.trim()) { UI.marcarError(servicioNombre, "Requerido"); return; }
    const payload = { nombre: servicioNombre.value.trim(), descripcion: servicioDescripcion.value.trim() || null };
    UI.cargando(btnGuardarServicio, true);
    try {
      if (servicioId.value) { await API.patch(ROUTES.admin.servicio(servicioId.value), payload); UI.ok("Servicio actualizado"); }
      else { await API.post(ROUTES.admin.servicios, payload); UI.ok("Servicio creado"); }
      UI.cerrarModal("modalServicio"); cargarServicios();
    } catch (err) {
      if (err.status === 409) UI.marcarError(servicioNombre, "Ese nombre ya existe");
      else UI.errorToast(err.detail || "No se pudo guardar");
    } finally { UI.cargando(btnGuardarServicio, false); }
  };

  async function eliminarServicio(s) {
    if (!confirm(`¿Eliminar el servicio "${s.nombre}"?`)) return;
    try { await API.del(ROUTES.admin.servicio(s.id_servicio)); UI.ok("Servicio eliminado"); cargarServicios(); }
    catch (err) { UI.errorToast(err.detail || "No se pudo eliminar"); }
  }

  /* ---- Init: servicios primero (los usan los checkboxes del tipo) -------- */
  (async function init() {
    await cargarServicios();
    cargarTipos();
  })();
})();
