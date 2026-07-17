/* ============================================================================
   Reporte de pagos: GET /admin/pagos?desde&hasta
   Sin fechas, la API devuelve los pagos de hoy.
   Respuesta: { total_ingresos, cantidad_pagos?, pagos[] }
   ========================================================================== */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("pagos", usuario);

  const desde = document.getElementById("desde");
  const hasta = document.getElementById("hasta");
  const body = document.getElementById("pagosBody");
  const mTotal = document.getElementById("mTotal");
  const mCantidad = document.getElementById("mCantidad");

  desde.value = UI.hoyISO();
  hasta.value = UI.hoyISO();

  function fila(p) {
    const metodo = p.id_metodo_pago ? UI.esc(window.CAT.metodo_pago[p.id_metodo_pago] || `#${p.id_metodo_pago}`)
                                    : '<span class="muted">—</span>';
    return `<tr>
      <td><strong>${UI.esc(p.codigo_reserva)}</strong></td>
      <td>${UI.esc(p.cliente_nombre)}</td>
      <td class="num">${UI.money(p.monto)}</td>
      <td>${metodo}</td>
      <td>${UI.badge(window.CAT.estado_pago, p.id_estado_pago)}</td>
      <td>${UI.fecha(p.fecha_pago)}</td>
    </tr>`;
  }

  async function consultar() {
    if (desde.value && hasta.value && hasta.value < desde.value) {
      UI.errorToast("'Hasta' no puede ser anterior a 'Desde'"); return;
    }
    body.innerHTML = UI.skeletonRows(6);
    mTotal.textContent = "…"; mCantidad.textContent = "…";
    try {
      const data = await API.get(ROUTES.admin.pagos, {
        desde: desde.value || undefined,
        hasta: hasta.value || undefined,
      });
      mTotal.textContent = UI.money(data.total_ingresos);
      // cantidad_pagos es opcional: si falta, usar el largo del arreglo.
      const cant = (data.cantidad_pagos !== undefined && data.cantidad_pagos !== null)
        ? data.cantidad_pagos : (data.pagos ? data.pagos.length : 0);
      mCantidad.textContent = cant;

      const pagos = data.pagos || [];
      body.innerHTML = pagos.length ? pagos.map(fila).join("")
                                    : UI.vacio(6, "No hay pagos en este rango", "💳");
    } catch (err) {
      mTotal.textContent = "—"; mCantidad.textContent = "—";
      body.innerHTML = `<tr><td colspan="6"><div class="banner-error"><span>⚠ ${UI.esc(err.detail || "Error al consultar")}</span></div></td></tr>`;
    }
  }

  document.getElementById("btnConsultar").onclick = consultar;
  document.getElementById("btnHoy").onclick = () => { desde.value = UI.hoyISO(); hasta.value = UI.hoyISO(); consultar(); };

  consultar();
})();
