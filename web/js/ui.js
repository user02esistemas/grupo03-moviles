/* ============================================================================
   Helpers de interfaz: toasts, formato, badges, modales, navegación,
   estados de carga/vacío/error. Todo vanilla JS.
   ========================================================================== */
window.UI = (function () {
  /* ---- Escape básico para evitar inyección de HTML en datos de la API ---- */
  function esc(v) {
    if (v === null || v === undefined) return "";
    return String(v)
      .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;").replace(/'/g, "&#39;");
  }

  /* ---- Formato de dinero (acepta número o string "180.00") --------------- */
  function money(v) {
    const n = typeof v === "number" ? v : parseFloat(v);
    if (isNaN(n)) return "—";
    return "S/ " + n.toLocaleString("es-PE", { minimumFractionDigits: 2, maximumFractionDigits: 2 });
  }

  /* ---- Fechas ------------------------------------------------------------ */
  function fecha(iso) {
    if (!iso) return "—";
    // DATE "YYYY-MM-DD": evitar desfase de zona construyendo local.
    if (/^\d{4}-\d{2}-\d{2}$/.test(iso)) {
      const [y, m, d] = iso.split("-");
      return `${d}/${m}/${y}`;
    }
    const dt = new Date(iso);
    if (isNaN(dt)) return esc(iso);
    return dt.toLocaleDateString("es-PE") + " " + dt.toLocaleTimeString("es-PE", { hour: "2-digit", minute: "2-digit" });
  }
  // "Hoy" en la zona horaria LOCAL del navegador (la del hotel), no en UTC.
  // toISOString() da UTC: de noche en Lima (UTC-5) ya devuelve el día siguiente,
  // y el reporte de pagos consultaría un día sin pagos (total S/ 0.00).
  function hoyISO() {
    const d = new Date();
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, "0");
    const dia = String(d.getDate()).padStart(2, "0");
    return `${y}-${m}-${dia}`;
  }

  /* ---- Badge desde un catálogo { txt, badge } ---------------------------- */
  function badge(cat, id) {
    const item = cat[id];
    if (!item) return `<span class="badge badge--gris">#${esc(id)}</span>`;
    return `<span class="badge badge--${item.badge}">${esc(item.txt)}</span>`;
  }

  /* ---- Toasts ------------------------------------------------------------ */
  function _toastCont() {
    let c = document.querySelector(".toasts");
    if (!c) { c = document.createElement("div"); c.className = "toasts"; document.body.appendChild(c); }
    return c;
  }
  function toast(msg, tipo = "ok", ms = 3500) {
    const el = document.createElement("div");
    el.className = "toast toast--" + tipo;
    const ic = tipo === "ok" ? "✓" : tipo === "error" ? "✕" : "ℹ";
    el.innerHTML = `<span>${ic}</span><span>${esc(msg)}</span>`;
    _toastCont().appendChild(el);
    setTimeout(() => el.remove(), ms);
  }
  const ok = (m) => toast(m, "ok");
  const errorToast = (m) => toast(m, "error", 5000);

  /* ---- Banner de error en una zona de contenido -------------------------- */
  function banner(contenedor, mensaje, onReintentar) {
    const div = document.createElement("div");
    div.className = "banner-error";
    div.innerHTML = `<span>⚠ ${esc(mensaje)}</span>`;
    if (onReintentar) {
      const b = document.createElement("button");
      b.className = "btn btn--sm btn--ghost";
      b.textContent = "Reintentar";
      b.onclick = onReintentar;
      div.appendChild(b);
    }
    contenedor.innerHTML = "";
    contenedor.appendChild(div);
  }

  /* ---- Estado vacío ------------------------------------------------------ */
  function vacio(cols, texto = "No hay datos para mostrar", ic = "📭") {
    return `<tr><td colspan="${cols}"><div class="estado-vacio"><span class="ic">${ic}</span>${esc(texto)}</div></td></tr>`;
  }

  /* ---- Skeleton de filas ------------------------------------------------- */
  function skeletonRows(cols, filas = 5) {
    let html = "";
    for (let i = 0; i < filas; i++) {
      html += "<tr>";
      for (let c = 0; c < cols; c++) html += `<td><div class="skeleton"></div></td>`;
      html += "</tr>";
    }
    return html;
  }

  /* ---- Botón en estado "cargando" ---------------------------------------- */
  function cargando(btn, on, textoOriginal) {
    if (on) {
      btn.dataset._txt = textoOriginal || btn.innerHTML;
      btn.disabled = true;
      btn.innerHTML = `<span class="spinner"></span> Procesando…`;
    } else {
      btn.disabled = false;
      if (btn.dataset._txt) { btn.innerHTML = btn.dataset._txt; delete btn.dataset._txt; }
    }
  }

  /* ---- Modales ----------------------------------------------------------- */
  function abrirModal(id) { document.getElementById(id)?.classList.add("is-open"); }
  function cerrarModal(id) { document.getElementById(id)?.classList.remove("is-open"); }
  function initModales() {
    document.querySelectorAll(".modal-overlay").forEach((ov) => {
      ov.addEventListener("mousedown", (e) => { if (e.target === ov) ov.classList.remove("is-open"); });
      ov.querySelectorAll("[data-cerrar]").forEach((b) => b.addEventListener("click", () => ov.classList.remove("is-open")));
    });
    document.addEventListener("keydown", (e) => {
      if (e.key === "Escape") document.querySelectorAll(".modal-overlay.is-open").forEach((o) => o.classList.remove("is-open"));
    });
  }

  /* ---- Validación de campos --------------------------------------------- */
  function marcarError(input, mensaje) {
    input.classList.add("is-invalid");
    let err = input.parentElement.querySelector(".campo-error");
    if (err) { err.textContent = mensaje; err.classList.add("is-visible"); }
  }
  function limpiarError(input) {
    input.classList.remove("is-invalid");
    const err = input.parentElement.querySelector(".campo-error");
    if (err) err.classList.remove("is-visible");
  }
  function limpiarErrores(form) {
    form.querySelectorAll(".is-invalid").forEach((i) => i.classList.remove("is-invalid"));
    form.querySelectorAll(".campo-error").forEach((e) => e.classList.remove("is-visible"));
  }

  return {
    esc, money, fecha, hoyISO, badge, toast, ok, errorToast, banner, vacio,
    skeletonRows, cargando, abrirModal, cerrarModal, initModales,
    marcarError, limpiarError, limpiarErrores,
  };
})();
