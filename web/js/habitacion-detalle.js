/* ============================================================================
   Detalle de habitación + gestión de imágenes.
   Datos: GET /habitaciones/{id}
   Imágenes:
     POST   /admin/habitaciones/{id}/imagenes   (multipart: files, es_principal, orden)
     PATCH  /admin/imagenes/{id}                (orden)
     PUT    /admin/imagenes/{id}                (multipart: file — reemplaza)
     PATCH  /admin/imagenes/{id}/principal
     DELETE /admin/imagenes/{id}
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("habitaciones", usuario);

  const id = new URLSearchParams(location.search).get("id");
  if (!id) { location.href = "habitaciones.html"; return; }

  const MAX_BYTES = 5 * 1024 * 1024;
  const MIME_OK = ["image/jpeg", "image/png", "image/webp"];

  const zonaDatos = document.getElementById("zonaDatos");
  const galeria = document.getElementById("galeria");
  const inputReemplazo = document.getElementById("inputReemplazo");
  let imagenReemplazoId = null;

  /* ---- Cargar datos + imágenes ------------------------------------------- */
  async function cargar() {
    try {
      const h = await API.get(ROUTES.habitaciones.detail(id));
      pintarDatos(h);
      pintarGaleria(h.imagenes || []);
    } catch (err) {
      if (err.status === 404) { UI.banner(zonaDatos, "La habitación no existe."); galeria.innerHTML = ""; }
      else UI.banner(zonaDatos, err.detail || "No se pudieron cargar los datos", cargar);
    }
  }

  function pintarDatos(h) {
    document.getElementById("tituloHab").textContent = `Habitación ${h.numero_habitacion}`;
    const servicios = (h.servicios || []).map((s) => `<span class="badge badge--gris">${UI.esc(s.nombre)}</span>`).join(" ") || '<span class="muted">—</span>';
    zonaDatos.innerHTML = `<div class="card">
      <div class="form-grid">
        <div><div class="metrica__label">Tipo</div><div>${UI.esc(h.tipo?.nombre_tipo || "—")}</div></div>
        <div><div class="metrica__label">Precio/noche</div><div>${UI.money(h.precio_noche)}</div></div>
        <div><div class="metrica__label">Capacidad</div><div>${UI.esc(h.capacidad)} personas</div></div>
        <div><div class="metrica__label">Estado</div><div>${UI.badge(window.CAT.estado_habitacion, h.id_estado_habitacion)}</div></div>
      </div>
      <div class="form-row" style="margin-top:14px">
        <div class="metrica__label">Descripción</div>
        <div>${h.descripcion ? UI.esc(h.descripcion) : '<span class="muted">Sin descripción</span>'}</div>
      </div>
      <div class="form-row">
        <div class="metrica__label">Servicios</div>
        <div style="margin-top:4px">${servicios}</div>
      </div>
    </div>`;
  }

  function pintarGaleria(imgs) {
    if (!imgs.length) { galeria.innerHTML = `<div class="estado-vacio" style="grid-column:1/-1"><span class="ic">🖼️</span>Aún no hay imágenes. Sube la primera.</div>`; return; }
    imgs.sort((a, b) => a.orden - b.orden);
    galeria.innerHTML = imgs.map((im) => `
      <div class="img-card" data-id="${im.id_imagen}">
        ${im.es_principal ? `<span class="badge badge--verde img-card__principal">Principal</span>` : ""}
        <img src="${UI.esc(im.url)}" alt="Imagen habitación" loading="lazy"
             onerror="this.style.opacity=.4;this.alt='No se pudo cargar'" />
        <div class="img-card__body">
          <span class="chip-orden">Orden: ${UI.esc(im.orden)}</span>
          <div class="img-card__acciones">
            ${im.es_principal ? "" : `<button class="btn btn--sm btn--ghost" data-a="principal">★ Principal</button>`}
            <button class="btn btn--sm btn--ghost" data-a="reemplazar">Reemplazar</button>
            <button class="btn btn--sm btn--ghost" data-a="orden">Orden</button>
            <button class="btn btn--sm btn--peligro" data-a="eliminar">Eliminar</button>
          </div>
        </div>
      </div>`).join("");
    enlazarGaleria(imgs);
  }

  function enlazarGaleria(imgs) {
    const porId = Object.fromEntries(imgs.map((i) => [i.id_imagen, i]));
    galeria.querySelectorAll(".img-card").forEach((card) => {
      const im = porId[card.dataset.id];
      card.querySelector('[data-a="principal"]')?.addEventListener("click", () => marcarPrincipal(im));
      card.querySelector('[data-a="reemplazar"]').addEventListener("click", () => pedirReemplazo(im));
      card.querySelector('[data-a="orden"]').addEventListener("click", () => cambiarOrden(im));
      card.querySelector('[data-a="eliminar"]').addEventListener("click", () => eliminar(im));
    });
  }

  /* ---- Validación de archivos cliente ------------------------------------ */
  function archivoValido(f) {
    if (!MIME_OK.includes(f.type)) { UI.errorToast(`"${f.name}" no es JPG/PNG/WEBP`); return false; }
    if (f.size > MAX_BYTES) { UI.errorToast(`"${f.name}" supera los 5 MB`); return false; }
    return true;
  }

  /* ---- Subir ------------------------------------------------------------- */
  const formSubir = document.getElementById("formSubir");
  const inputArchivos = document.getElementById("archivos");
  const btnSubir = document.getElementById("btnSubir");

  formSubir.onsubmit = async (e) => {
    e.preventDefault();
    const files = Array.from(inputArchivos.files || []);
    if (!files.length) { UI.errorToast("Selecciona al menos un archivo"); return; }
    if (!files.every(archivoValido)) return;

    const fd = new FormData();
    files.forEach((f) => fd.append("files", f));
    fd.append("es_principal", document.getElementById("subirPrincipal").checked ? "true" : "false");
    fd.append("orden", "0");

    UI.cargando(btnSubir, true);
    try {
      await API.postForm(ROUTES.admin.habitacionImagenes(id), fd);
      UI.ok(files.length > 1 ? "Imágenes subidas" : "Imagen subida");
      formSubir.reset();
      cargar();
    } catch (err) {
      if (err.status === 413) UI.errorToast("Algún archivo excede el tamaño permitido");
      else if (err.status === 415) UI.errorToast("Tipo de archivo no permitido");
      else UI.errorToast(err.detail || "No se pudieron subir las imágenes");
    } finally {
      UI.cargando(btnSubir, false);
    }
  };

  /* ---- Principal --------------------------------------------------------- */
  async function marcarPrincipal(im) {
    try {
      await API.patch(ROUTES.admin.imagenPrincipal(im.id_imagen));
      UI.ok("Imagen principal actualizada");
      cargar();
    } catch (err) { UI.errorToast(err.detail || "No se pudo marcar como principal"); }
  }

  /* ---- Reemplazar archivo ------------------------------------------------ */
  function pedirReemplazo(im) { imagenReemplazoId = im.id_imagen; inputReemplazo.value = ""; inputReemplazo.click(); }
  inputReemplazo.onchange = async () => {
    const f = inputReemplazo.files[0];
    if (!f || !imagenReemplazoId) return;
    if (!archivoValido(f)) return;
    const fd = new FormData();
    fd.append("file", f);
    try {
      await API.putForm(ROUTES.admin.imagen(imagenReemplazoId), fd);
      UI.ok("Imagen reemplazada");
      cargar();
    } catch (err) { UI.errorToast(err.detail || "No se pudo reemplazar"); }
    finally { imagenReemplazoId = null; }
  };

  /* ---- Cambiar orden ----------------------------------------------------- */
  async function cambiarOrden(im) {
    const val = prompt("Nuevo orden (número entero ≥ 0):", im.orden);
    if (val === null) return;
    const orden = parseInt(val, 10);
    if (isNaN(orden) || orden < 0) { UI.errorToast("Orden inválido"); return; }
    try {
      await API.patch(ROUTES.admin.imagen(im.id_imagen), { orden });
      UI.ok("Orden actualizado");
      cargar();
    } catch (err) { UI.errorToast(err.detail || "No se pudo actualizar el orden"); }
  }

  /* ---- Eliminar ---------------------------------------------------------- */
  async function eliminar(im) {
    if (!confirm("¿Eliminar esta imagen?")) return;
    try {
      await API.del(ROUTES.admin.imagen(im.id_imagen));
      UI.ok("Imagen eliminada");
      cargar();
    } catch (err) { UI.errorToast(err.detail || "No se pudo eliminar"); }
  }

  cargar();
})();
