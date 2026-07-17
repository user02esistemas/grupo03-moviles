/* ============================================================================
   Configuración global del panel administrativo.
   El navegador consume la API FastAPI que corre en Docker (puerto 8000).
   ========================================================================== */
window.CONFIG = {
  // Base de la API. El navegador debe alcanzar el host donde corre Docker.
  // Si Docker corre en esta misma máquina: http://localhost:8000/api/v1
  API_BASE_URL: "http://localhost:8000/api/v1",

  // Claves de almacenamiento de sesión.
  STORAGE_KEYS: {
    ACCESS: "hcb_access_token",
    REFRESH: "hcb_refresh_token",
    USUARIO: "hcb_usuario",
  },

  // Roles con acceso al panel (recepcionista y administrador).
  ROLES_STAFF: [2, 3],
  ROL_ADMIN: 3, // eliminar habitación exige administrador
};
