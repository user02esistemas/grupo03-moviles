/* ============================================================================
   Cliente HTTP de la API. Añade Authorization: Bearer, maneja el refresh
   automático (una sola vez) ante un 401 y normaliza los errores a ApiError
   con { status, detail }.
   ========================================================================== */
window.API = (function () {
  const { API_BASE_URL, STORAGE_KEYS } = window.CONFIG;

  /* ---- Sesión en localStorage ------------------------------------------- */
  const getAccess = () => localStorage.getItem(STORAGE_KEYS.ACCESS);
  const getRefresh = () => localStorage.getItem(STORAGE_KEYS.REFRESH);
  function setTokens(access, refresh) {
    if (access) localStorage.setItem(STORAGE_KEYS.ACCESS, access);
    if (refresh) localStorage.setItem(STORAGE_KEYS.REFRESH, refresh);
  }
  function setUsuario(u) { localStorage.setItem(STORAGE_KEYS.USUARIO, JSON.stringify(u)); }
  function getUsuario() {
    try { return JSON.parse(localStorage.getItem(STORAGE_KEYS.USUARIO) || "null"); }
    catch { return null; }
  }
  function limpiarSesion() {
    localStorage.removeItem(STORAGE_KEYS.ACCESS);
    localStorage.removeItem(STORAGE_KEYS.REFRESH);
    localStorage.removeItem(STORAGE_KEYS.USUARIO);
  }

  /* ---- Error tipado ------------------------------------------------------ */
  class ApiError extends Error {
    constructor(status, detail) { super(detail || "Error"); this.status = status; this.detail = detail; }
  }

  /* ---- Extrae {detail} de FastAPI (incluye lista de validación 422) ------ */
  async function leerError(resp) {
    let cuerpo = null;
    try { cuerpo = await resp.json(); } catch { /* sin cuerpo JSON */ }
    if (cuerpo && typeof cuerpo.detail === "string") return cuerpo.detail;
    if (cuerpo && Array.isArray(cuerpo.detail) && cuerpo.detail.length) {
      return cuerpo.detail[0].msg || "Datos inválidos";
    }
    const genericos = {
      400: "Solicitud inválida", 401: "No autenticado", 403: "No autorizado",
      404: "Recurso no encontrado", 409: "Conflicto con el estado actual",
      413: "El archivo es demasiado grande", 415: "Tipo de archivo no permitido",
      422: "Datos inválidos", 500: "Error interno del servidor",
    };
    return genericos[resp.status] || `Error ${resp.status}`;
  }

  /* ---- Refresh: se coordina para no lanzar varios en paralelo ------------ */
  let refreshEnCurso = null;
  async function refrescar() {
    const rt = getRefresh();
    if (!rt) throw new ApiError(401, "Sesión expirada");
    if (!refreshEnCurso) {
      refreshEnCurso = fetch(`${API_BASE_URL}${ROUTES.auth.refresh}`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ refresh_token: rt }),
      }).then(async (r) => {
        if (!r.ok) throw new ApiError(401, "Sesión expirada");
        const data = await r.json();
        setTokens(data.access_token, data.refresh_token); // refresh_token es opcional
        return data.access_token;
      }).finally(() => { refreshEnCurso = null; });
    }
    return refreshEnCurso;
  }

  /* ---- Núcleo de petición ------------------------------------------------ */
  async function pedir(metodo, ruta, { body, query, isForm, auth = true, _reintentado = false } = {}) {
    let url = API_BASE_URL + ruta;
    if (query) {
      const qs = new URLSearchParams();
      Object.entries(query).forEach(([k, v]) => {
        if (v !== undefined && v !== null && v !== "") qs.append(k, v);
      });
      const s = qs.toString();
      if (s) url += "?" + s;
    }

    const headers = {};
    if (auth) {
      const at = getAccess();
      if (at) headers["Authorization"] = "Bearer " + at;
    }
    let payload;
    if (isForm) {
      payload = body; // FormData: el navegador pone el Content-Type con boundary
    } else if (body !== undefined) {
      headers["Content-Type"] = "application/json";
      payload = JSON.stringify(body);
    }

    let resp;
    try {
      resp = await fetch(url, { method: metodo, headers, body: payload });
    } catch (e) {
      throw new ApiError(0, "No se pudo conectar con el servidor. ¿Está la API en línea?");
    }

    // Refresh automático una sola vez ante 401 en endpoint protegido.
    if (resp.status === 401 && auth && !_reintentado) {
      try {
        await refrescar();
      } catch {
        limpiarSesion();
        if (!location.pathname.endsWith("index.html") && location.pathname !== "/") {
          location.href = "index.html";
        }
        throw new ApiError(401, "Sesión expirada");
      }
      return pedir(metodo, ruta, { body, query, isForm, auth, _reintentado: true });
    }

    if (!resp.ok) throw new ApiError(resp.status, await leerError(resp));

    if (resp.status === 204) return null;
    const ct = resp.headers.get("content-type") || "";
    if (ct.includes("application/json")) return resp.json();
    return resp.text();
  }

  return {
    get: (ruta, query) => pedir("GET", ruta, { query }),
    post: (ruta, body) => pedir("POST", ruta, { body }),
    postForm: (ruta, formData) => pedir("POST", ruta, { body: formData, isForm: true }),
    put: (ruta, body) => pedir("PUT", ruta, { body }),
    putForm: (ruta, formData) => pedir("PUT", ruta, { body: formData, isForm: true }),
    patch: (ruta, body) => pedir("PATCH", ruta, { body }),
    del: (ruta) => pedir("DELETE", ruta),
    // sesión
    getAccess, getRefresh, setTokens, setUsuario, getUsuario, limpiarSesion,
    ApiError,
  };
})();
