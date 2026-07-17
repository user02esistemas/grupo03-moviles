/* ============================================================================
   Rutas canonicas de la API REST.
   Mantener este archivo alineado con API_REST.md. Las pantallas consumen estas
   funciones para no repetir endpoints ni crear variantes incompatibles.
   ========================================================================== */
window.ROUTES = (function () {
  const withId = (base, id, suffix = "") => `${base}/${encodeURIComponent(id)}${suffix}`;

  return {
    auth: {
      register: "/auth/register",
      login: "/auth/login",
      google: "/auth/google",
      refresh: "/auth/refresh",
      me: "/auth/me",
    },

    habitaciones: {
      list: "/habitaciones",
      detail: (id) => withId("/habitaciones", id),
    },

    reservas: {
      create: "/reservas",
      mine: "/reservas/mias",
      cancel: (id) => withId("/reservas", id, "/cancelar"),
    },

    pagos: {
      intencion: "/pagos/intencion",
      detail: (id) => withId("/pagos", id),
    },

    notificaciones: {
      list: "/notificaciones",
      read: (id) => withId("/notificaciones", id, "/leer"),
      readAll: "/notificaciones/leer-todas",
    },

    usuarios: {
      me: "/usuarios/me",
      password: "/usuarios/me/password",
    },

    admin: {
      dashboard: "/admin/dashboard",
      reservas: "/admin/reservas",
      reservaEstado: (id) => withId("/admin/reservas", id, "/estado"),
      habitaciones: "/admin/habitaciones",
      habitacion: (id) => withId("/admin/habitaciones", id),
      habitacionEstado: (id) => withId("/admin/habitaciones", id, "/estado"),
      habitacionImagenes: (id) => withId("/admin/habitaciones", id, "/imagenes"),
      imagen: (id) => withId("/admin/imagenes", id),
      imagenPrincipal: (id) => withId("/admin/imagenes", id, "/principal"),
      pagos: "/admin/pagos",
      clientes: "/admin/clientes",
      cliente: (id) => withId("/admin/clientes", id),
      tiposHabitacion: "/admin/tipos-habitacion",
      tipoHabitacion: (id) => withId("/admin/tipos-habitacion", id),
      tipoHabitacionServicios: (id) => withId("/admin/tipos-habitacion", id, "/servicios"),
      servicios: "/admin/servicios",
      servicio: (id) => withId("/admin/servicios", id),
    },
  };
})();
