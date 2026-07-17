/* ============================================================================
   Autenticación y armazón de páginas protegidas.
   - login(): POST /auth/login + guard de rol staff.
   - protegerPagina(): redirige a login si no hay sesión válida.
   - montarLayout(): inyecta barra lateral, resalta la activa y arma logout.
   ========================================================================== */
window.AUTH = (function () {
  const { ROLES_STAFF } = window.CONFIG;

  function esStaff(usuario) {
    return usuario && ROLES_STAFF.includes(Number(usuario.id_rol));
  }

  async function login(correo, password) {
    const data = await API.post(ROUTES.auth.login, { correo, password });
    if (!esStaff(data.usuario)) {
      // No guardamos nada: este panel es solo para personal.
      throw new API.ApiError(403, "Esta cuenta no tiene acceso al panel administrativo.");
    }
    API.setTokens(data.access_token, data.refresh_token);
    API.setUsuario(data.usuario);
    return data.usuario;
  }

  function logout() {
    API.limpiarSesion();
    location.href = "index.html";
  }

  // Guard: llamar al inicio de cada página protegida. Devuelve el usuario.
  function protegerPagina() {
    const u = API.getUsuario();
    if (!API.getAccess() || !esStaff(u)) {
      location.href = "index.html";
      return null;
    }
    return u;
  }

  // Definición de la navegación superior. `activa` = clave de la página actual.
  const NAV = [
    { key: "dashboard", href: "dashboard.html", txt: "Panel" },
    { key: "habitaciones", href: "habitaciones.html", txt: "Habitaciones" },
    { key: "reservas", href: "reservas.html", txt: "Reservas" },
    { key: "clientes", href: "clientes.html", txt: "Clientes" },
    { key: "tipos", href: "tipos.html", txt: "Tipos" },
    { key: "pagos", href: "pagos.html", txt: "Pagos" },
    { key: "perfil", href: "perfil.html", txt: "Perfil" },
  ];

  function montarLayout(activa, usuario) {
    const rolTxt = window.CAT.rol[usuario.id_rol] || "Personal";
    const links = NAV.map((n) =>
      `<a class="sidebar__link ${n.key === activa ? "is-active" : ""}" href="${n.href}">
         <span>${n.txt}</span></a>`
    ).join("");

    const aside = document.createElement("aside");
    aside.className = "sidebar";
    aside.innerHTML = `
      <a class="sidebar__marca" href="dashboard.html">Casa Blanca <small>HOTEL & RETIRO</small></a>
      <nav class="sidebar__nav">${links}</nav>
      <div class="sidebar__pie">
        <div class="usuario">${UI.esc(usuario.nombre)} ${UI.esc(usuario.apellido)}</div>
        <div class="rol">${UI.esc(rolTxt)}</div>
        <button class="btn btn--ghost btn--sm" id="btnLogout">Salir</button>
      </div>`;
    document.body.prepend(aside);
    // El body pasa a ser flex para que el .main quede al lado del sidebar.
    document.body.classList.add("has-sidebar");
    document.getElementById("btnLogout").addEventListener("click", logout);
  }

  return { login, logout, protegerPagina, montarLayout, esStaff };
})();
