/* ============================================================================
   Reservas:
     GET   /admin/reservas?estado
     PATCH /admin/reservas/{id}/estado   (transiciones: 1->2/3, 2->4/5/3)
     POST  /admin/reservas               (a nombre de un huésped)
   Apoyo para "Nueva reserva":
     GET /admin/clientes   (poblar huéspedes)
     GET /habitaciones?fecha_inicio&fecha_fin&personas  (disponibilidad)
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("reservas", usuario);
  UI.initModales();

  const body = document.getElementById("reservasBody");
  const filtroEstado = document.getElementById("filtroEstado");

  // Poblar el filtro con los estados de reserva.
  filtroEstado.innerHTML += Object.entries(window.CAT.estado_reserva)
    .map(([id, e]) => `<option value="${id}">${e.txt}</option>`).join("");

  /* ---- LISTAR ------------------------------------------------------------ */
  async function cargar() {
    body.innerHTML = UI.skeletonRows(10);
    try {
      const data = await API.get(ROUTES.admin.reservas, { estado: filtroEstado.value || undefined });
      if (!data.length) { body.innerHTML = UI.vacio(10, "No hay reservas para este filtro", "📅"); return; }
      body.innerHTML = data.map(fila).join("");
      enlazar(data);
    } catch (err) {
      body.innerHTML = `<tr><td colspan="10"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error al cargar")}</span></div></td></tr>`;
    }
  }

  function fila(r) {
    const transiciones = window.TRANSICIONES_RESERVA[r.id_estado_reserva] || [];
    const puedeCambiar = transiciones.length > 0;
    return `<tr data-id="${r.id_reserva}">
      <td><strong>${UI.esc(r.codigo_reserva)}</strong></td>
      <td>${UI.esc(r.cliente_nombre)}</td>
      <td>${UI.esc(r.numero_habitacion)}</td>
      <td>${UI.esc(r.tipo_nombre)}</td>
      <td>${UI.fecha(r.fecha_ingreso)}</td>
      <td>${UI.fecha(r.fecha_salida)}</td>
      <td class="num">${UI.esc(r.cantidad_personas)}</td>
      <td class="num">${UI.money(r.monto_total)}</td>
      <td>${UI.badge(window.CAT.estado_reserva, r.id_estado_reserva)}</td>
      <td><div class="acciones">
        ${puedeCambiar
          ? `<button class="btn btn--sm btn--ghost" data-a="estado">Cambiar estado</button>`
          : `<span class="muted" style="font-size:12px">—</span>`}
      </div></td>
    </tr>`;
  }

  function enlazar(reservas) {
    const porId = Object.fromEntries(reservas.map((r) => [r.id_reserva, r]));
    body.querySelectorAll("tr[data-id]").forEach((tr) => {
      const r = porId[tr.dataset.id];
      tr.querySelector('[data-a="estado"]')?.addEventListener("click", () => abrirEstado(r));
    });
  }

  filtroEstado.onchange = cargar;
  document.getElementById("btnRefrescar").onclick = cargar;

  /* ---- CAMBIAR ESTADO ---------------------------------------------------- */
  const selEstado = document.getElementById("nuevoEstadoRes");
  const btnGuardarEstado = document.getElementById("btnGuardarEstadoRes");
  const sinTransiciones = document.getElementById("sinTransiciones");
  let reservaActual = null;

  function abrirEstado(r) {
    reservaActual = r;
    document.getElementById("estadoResInfo").textContent =
      `Reserva ${r.codigo_reserva} — actual: ${window.CAT.estado_reserva[r.id_estado_reserva]?.txt || "—"}`;
    const permitidos = window.TRANSICIONES_RESERVA[r.id_estado_reserva] || [];
    if (!permitidos.length) {
      selEstado.innerHTML = ""; selEstado.disabled = true;
      sinTransiciones.style.display = "block"; btnGuardarEstado.disabled = true;
    } else {
      selEstado.disabled = false; sinTransiciones.style.display = "none"; btnGuardarEstado.disabled = false;
      selEstado.innerHTML = permitidos.map((id) =>
        `<option value="${id}">${window.CAT.estado_reserva[id].txt}</option>`).join("");
    }
    UI.abrirModal("modalEstadoRes");
  }

  btnGuardarEstado.onclick = async () => {
    if (!reservaActual) return;
    const nuevo = Number(selEstado.value);
    UI.cargando(btnGuardarEstado, true);
    try {
      await API.patch(ROUTES.admin.reservaEstado(reservaActual.id_reserva), { id_estado_reserva: nuevo });
      UI.ok("Estado de la reserva actualizado");
      UI.cerrarModal("modalEstadoRes");
      cargar();
    } catch (err) {
      if (err.status === 409) UI.errorToast("Confirmarla choca con otra reserva de esas fechas");
      else if (err.status === 422) UI.errorToast(err.detail || "Transición de estado no permitida");
      else if (err.status === 404) UI.errorToast("La reserva ya no existe");
      else UI.errorToast(err.detail || "No se pudo cambiar el estado");
    } finally {
      UI.cargando(btnGuardarEstado, false);
    }
  };

  /* ---- NUEVA RESERVA ----------------------------------------------------- */
  const selCliente = document.getElementById("resCliente");
  const resIngreso = document.getElementById("resIngreso");
  const resSalida = document.getElementById("resSalida");
  const resPersonas = document.getElementById("resPersonas");
  const selHabitacion = document.getElementById("resHabitacion");
  const btnBuscarHab = document.getElementById("btnBuscarHab");
  const btnCrearRes = document.getElementById("btnCrearRes");
  const formNueva = document.getElementById("formNuevaRes");

  document.getElementById("btnNueva").onclick = async () => {
    UI.limpiarErrores(formNueva);
    formNueva.reset();
    resIngreso.value = UI.hoyISO();
    resPersonas.value = 1;
    resetHabitaciones();
    UI.abrirModal("modalNuevaRes");
    await cargarClientes();
  };

  async function cargarClientes() {
    selCliente.innerHTML = `<option value="">Cargando…</option>`;
    try {
      const clientes = await API.get(ROUTES.admin.clientes, { page: 1, page_size: 100 });
      if (!clientes.length) {
        selCliente.innerHTML = `<option value="">No hay clientes registrados</option>`;
        return;
      }
      selCliente.innerHTML = `<option value="">Selecciona un huésped…</option>` +
        clientes.map((c) => `<option value="${c.id_usuario}">${UI.esc(c.nombre)} ${UI.esc(c.apellido)} — ${UI.esc(c.correo)}</option>`).join("");
    } catch {
      selCliente.innerHTML = `<option value="">Error al cargar clientes</option>`;
    }
  }

  function resetHabitaciones() {
    selHabitacion.innerHTML = `<option value="">Primero busca disponibilidad…</option>`;
    selHabitacion.disabled = true;
    btnCrearRes.disabled = true;
  }

  // Si cambian fechas o personas, hay que volver a buscar disponibilidad.
  [resIngreso, resSalida, resPersonas].forEach((el) => el.addEventListener("change", resetHabitaciones));

  function validarFechas() {
    UI.limpiarError(resIngreso); UI.limpiarError(resSalida); UI.limpiarError(resPersonas);
    let ok = true;
    if (!resIngreso.value) { UI.marcarError(resIngreso, "Requerido"); ok = false; }
    if (!resSalida.value) { UI.marcarError(resSalida, "Requerido"); ok = false; }
    if (resIngreso.value && resSalida.value && resSalida.value <= resIngreso.value) {
      UI.marcarError(resSalida, "Debe ser posterior al ingreso"); ok = false;
    }
    const p = parseInt(resPersonas.value, 10);
    if (isNaN(p) || p < 1) { UI.marcarError(resPersonas, "Mínimo 1"); ok = false; }
    return ok;
  }

  btnBuscarHab.onclick = async () => {
    if (!validarFechas()) return;
    selHabitacion.innerHTML = `<option value="">Buscando…</option>`;
    selHabitacion.disabled = true; btnCrearRes.disabled = true;
    UI.cargando(btnBuscarHab, true);
    try {
      const habs = await API.get(ROUTES.habitaciones.list, {
        fecha_inicio: resIngreso.value, fecha_fin: resSalida.value, personas: resPersonas.value,
      });
      if (!habs.length) {
        selHabitacion.innerHTML = `<option value="">Sin habitaciones disponibles</option>`;
        UI.toast("No hay habitaciones libres para ese rango/capacidad", "info");
      } else {
        selHabitacion.innerHTML = `<option value="">Selecciona una habitación…</option>` +
          habs.map((h) => `<option value="${h.id_habitacion}">N° ${UI.esc(h.numero_habitacion)} · ${UI.esc(h.tipo?.nombre_tipo || "—")} · cap ${h.capacidad} · ${UI.money(h.precio_noche)}</option>`).join("");
        selHabitacion.disabled = false;
      }
    } catch (err) {
      selHabitacion.innerHTML = `<option value="">Error al buscar</option>`;
      UI.errorToast(err.detail || "No se pudo consultar disponibilidad");
    } finally {
      UI.cargando(btnBuscarHab, false);
    }
  };

  selHabitacion.onchange = () => { btnCrearRes.disabled = !selHabitacion.value; };

  formNueva.onsubmit = async (e) => {
    e.preventDefault();
    let ok = validarFechas();
    UI.limpiarError(selCliente); UI.limpiarError(selHabitacion);
    if (!selCliente.value) { UI.marcarError(selCliente, "Selecciona un huésped"); ok = false; }
    if (!selHabitacion.value) { UI.marcarError(selHabitacion, "Selecciona una habitación"); ok = false; }
    if (!ok) return;

    UI.cargando(btnCrearRes, true);
    try {
      await API.post(ROUTES.admin.reservas, {
        id_usuario: Number(selCliente.value),
        id_habitacion: Number(selHabitacion.value),
        fecha_ingreso: resIngreso.value,
        fecha_salida: resSalida.value,
        cantidad_personas: parseInt(resPersonas.value, 10),
      });
      UI.ok("Reserva creada");
      UI.cerrarModal("modalNuevaRes");
      filtroEstado.value = "";
      cargar();
    } catch (err) {
      if (err.status === 409) UI.errorToast("La habitación ya no está disponible en esas fechas");
      else if (err.status === 422) UI.errorToast(err.detail || "Capacidad excedida o fechas inválidas");
      else if (err.status === 404) UI.errorToast("Cliente o habitación no encontrados");
      else UI.errorToast(err.detail || "No se pudo crear la reserva");
    } finally {
      UI.cargando(btnCrearRes, false);
    }
  };

  cargar();
})();
