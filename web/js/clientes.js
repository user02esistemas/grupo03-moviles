/* ============================================================================
   Clientes / huéspedes:
     GET    /admin/clientes?q&page&page_size
     POST   /admin/clientes
     PATCH  /admin/clientes/{id}
     DELETE /admin/clientes/{id}   (baja lógica; 409 si tiene reservas activas)
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("clientes", usuario);
  UI.initModales();

  const PAGE_SIZE = 20;
  let page = 1;
  let q = "";
  let ultimaCantidad = 0;

  const body = document.getElementById("clientesBody");
  const buscar = document.getElementById("buscar");
  const pagInfo = document.getElementById("pagInfo");
  const btnPrev = document.getElementById("btnPrev");
  const btnNext = document.getElementById("btnNext");

  /* ---- LISTAR ------------------------------------------------------------ */
  async function cargar() {
    body.innerHTML = UI.skeletonRows(4);
    try {
      const data = await API.get(ROUTES.admin.clientes, { q: q || undefined, page, page_size: PAGE_SIZE });
      ultimaCantidad = data.length;
      if (!data.length) {
        body.innerHTML = UI.vacio(4, page > 1 ? "No hay más resultados" : "No hay clientes registrados", "👥");
      } else {
        body.innerHTML = data.map(fila).join("");
        enlazar(data);
      }
      pagInfo.textContent = `Página ${page}`;
      btnPrev.disabled = page <= 1;
      btnNext.disabled = data.length < PAGE_SIZE;
    } catch (err) {
      body.innerHTML = `<tr><td colspan="4"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error al cargar")}</span></div></td></tr>`;
    }
  }

  function fila(c) {
    return `<tr data-id="${c.id_usuario}">
      <td><strong>${UI.esc(c.nombre)} ${UI.esc(c.apellido)}</strong></td>
      <td>${UI.esc(c.correo)}</td>
      <td>${c.telefono ? UI.esc(c.telefono) : '<span class="muted">—</span>'}</td>
      <td><div class="acciones">
        <button class="btn btn--sm btn--ghost" data-a="editar">Editar</button>
        <button class="btn btn--sm btn--peligro" data-a="baja">Dar de baja</button>
      </div></td>
    </tr>`;
  }

  function enlazar(clientes) {
    const porId = Object.fromEntries(clientes.map((c) => [c.id_usuario, c]));
    body.querySelectorAll("tr[data-id]").forEach((tr) => {
      const c = porId[tr.dataset.id];
      tr.querySelector('[data-a="editar"]').onclick = () => abrirEditar(c);
      tr.querySelector('[data-a="baja"]').onclick = () => darBaja(c);
    });
  }

  /* ---- Búsqueda / paginación --------------------------------------------- */
  function aplicarBusqueda() { q = buscar.value.trim(); page = 1; cargar(); }
  document.getElementById("btnBuscar").onclick = aplicarBusqueda;
  buscar.addEventListener("keydown", (e) => { if (e.key === "Enter") aplicarBusqueda(); });
  document.getElementById("btnLimpiar").onclick = () => { buscar.value = ""; q = ""; page = 1; cargar(); };
  btnPrev.onclick = () => { if (page > 1) { page--; cargar(); } };
  btnNext.onclick = () => { if (ultimaCantidad >= PAGE_SIZE) { page++; cargar(); } };

  /* ---- CREAR / EDITAR ---------------------------------------------------- */
  const form = document.getElementById("formCliente");
  const fId = document.getElementById("cliId");
  const fNombre = document.getElementById("cliNombre");
  const fApellido = document.getElementById("cliApellido");
  const fCorreo = document.getElementById("cliCorreo");
  const fTelefono = document.getElementById("cliTelefono");
  const fPassword = document.getElementById("cliPassword");
  const rowPassword = document.getElementById("rowPassword");
  const btnGuardar = document.getElementById("btnGuardarCli");

  document.getElementById("btnNuevo").onclick = () => {
    UI.limpiarErrores(form); form.reset(); fId.value = "";
    document.getElementById("modalClienteTitulo").textContent = "Nuevo huésped";
    fCorreo.disabled = false;
    rowPassword.classList.remove("hidden");
    UI.abrirModal("modalCliente");
  };

  function abrirEditar(c) {
    UI.limpiarErrores(form);
    document.getElementById("modalClienteTitulo").textContent = "Editar huésped";
    fId.value = c.id_usuario;
    fNombre.value = c.nombre;
    fApellido.value = c.apellido;
    fCorreo.value = c.correo;
    fCorreo.disabled = true; // el correo no se edita (igual que en el perfil)
    fTelefono.value = c.telefono || "";
    rowPassword.classList.add("hidden"); // el cambio de contraseña no está en este endpoint
    UI.abrirModal("modalCliente");
  }

  function validar(esEdicion) {
    UI.limpiarErrores(form);
    let ok = true;
    if (!fNombre.value.trim()) { UI.marcarError(fNombre, "Requerido"); ok = false; }
    if (!fApellido.value.trim()) { UI.marcarError(fApellido, "Requerido"); ok = false; }
    if (!esEdicion) {
      const re = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
      if (!fCorreo.value.trim()) { UI.marcarError(fCorreo, "Requerido"); ok = false; }
      else if (!re.test(fCorreo.value.trim())) { UI.marcarError(fCorreo, "Correo no válido"); ok = false; }
      if (fPassword.value && fPassword.value.length < 8) { UI.marcarError(fPassword, "Mínimo 8 caracteres"); ok = false; }
    }
    return ok;
  }

  form.onsubmit = async (e) => {
    e.preventDefault();
    const esEdicion = !!fId.value;
    if (!validar(esEdicion)) return;
    UI.cargando(btnGuardar, true);
    try {
      if (esEdicion) {
        await API.patch(ROUTES.admin.cliente(fId.value), {
          nombre: fNombre.value.trim(),
          apellido: fApellido.value.trim(),
          telefono: fTelefono.value.trim() || null,
        });
        UI.ok("Huésped actualizado");
      } else {
        const payload = {
          nombre: fNombre.value.trim(),
          apellido: fApellido.value.trim(),
          correo: fCorreo.value.trim(),
          telefono: fTelefono.value.trim() || null,
        };
        if (fPassword.value) payload.password = fPassword.value;
        await API.post(ROUTES.admin.clientes, payload);
        UI.ok("Huésped registrado");
      }
      UI.cerrarModal("modalCliente");
      cargar();
    } catch (err) {
      if (err.status === 409) UI.marcarError(fCorreo, "Ese correo ya está registrado");
      else UI.errorToast(err.detail || "No se pudo guardar");
    } finally {
      UI.cargando(btnGuardar, false);
    }
  };

  /* ---- BAJA LÓGICA ------------------------------------------------------- */
  async function darBaja(c) {
    if (!confirm(`¿Dar de baja a ${c.nombre} ${c.apellido}? Se ocultará de los listados.`)) return;
    try {
      await API.del(ROUTES.admin.cliente(c.id_usuario));
      UI.ok("Huésped dado de baja");
      cargar();
    } catch (err) {
      if (err.status === 409) UI.errorToast("No se puede: el cliente tiene reservas activas");
      else UI.errorToast(err.detail || "No se pudo dar de baja");
    }
  }

  cargar();
})();
