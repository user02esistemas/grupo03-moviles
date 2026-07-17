/* Login: valida, autentica y redirige al dashboard. */
(function () {
  // Si ya hay sesión de staff, saltar directo al dashboard.
  if (API.getAccess() && AUTH.esStaff(API.getUsuario())) {
    location.href = "dashboard.html";
    return;
  }

  const form = document.getElementById("formLogin");
  const correo = document.getElementById("correo");
  const password = document.getElementById("password");
  const btn = document.getElementById("btnEntrar");

  function validar() {
    UI.limpiarErrores(form);
    let ok = true;
    const re = /^[^@\s]+@[^@\s]+\.[^@\s]+$/;
    if (!correo.value.trim()) { UI.marcarError(correo, "Ingresa tu correo"); ok = false; }
    else if (!re.test(correo.value.trim())) { UI.marcarError(correo, "Correo no válido"); ok = false; }
    if (!password.value) { UI.marcarError(password, "Ingresa tu contraseña"); ok = false; }
    return ok;
  }

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    if (!validar()) return;
    UI.cargando(btn, true);
    try {
      await AUTH.login(correo.value.trim(), password.value);
      location.href = "dashboard.html";
    } catch (err) {
      UI.cargando(btn, false);
      if (err.status === 401) UI.errorToast("Correo o contraseña incorrectos");
      else if (err.status === 403) UI.errorToast(err.detail);
      else UI.errorToast(err.detail || "No se pudo iniciar sesión");
    }
  });

  [correo, password].forEach((i) => i.addEventListener("input", () => UI.limpiarError(i)));
})();
