/* Dashboard: métricas del día (GET /admin/dashboard). */
(function () {
  const usuario = AUTH.protegerPagina();
  if (!usuario) return;
  AUTH.montarLayout("dashboard", usuario);

  document.getElementById("fechaHoy").textContent =
    new Date().toLocaleDateString("es-PE", { weekday: "long", year: "numeric", month: "long", day: "numeric" });

  const grid = document.getElementById("gridMetricas");

  function skeleton() {
    grid.innerHTML = Array(4).fill(0).map(() =>
      `<div class="metrica"><div class="metrica__label"><div class="skeleton" style="width:60%"></div></div>
       <div class="metrica__valor"><div class="skeleton" style="width:40%;height:28px;margin-top:8px"></div></div></div>`
    ).join("");
  }

  function pintar(d) {
    const cards = [
      { label: "Reservas activas", valor: d.reservas_activas, acento: false },
      { label: "Check-ins de hoy", valor: d.checkins_hoy, acento: false },
      { label: "Ingresos de hoy", valor: UI.money(d.ingresos_hoy), acento: true },
      { label: "Habitaciones disponibles", valor: d.habitaciones_disponibles, acento: false },
    ];
    grid.innerHTML = cards.map((c) =>
      `<div class="metrica ${c.acento ? "metrica--acento" : ""}">
         <div class="metrica__label">${c.label}</div>
         <div class="metrica__valor">${UI.esc(c.valor)}</div>
       </div>`
    ).join("");
  }

  async function cargar() {
    skeleton();
    try {
      const d = await API.get(ROUTES.admin.dashboard);
      pintar(d);
    } catch (err) {
      UI.banner(document.getElementById("zonaMetricas"), err.detail || "No se pudieron cargar las métricas", cargar);
    }
  }

  cargar();
})();
