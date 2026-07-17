/* ============================================================================
   Catálogos con IDs FIJOS (API_REST.md §3 y Base de datos.txt).
   Se usan como enums para traducir IDs a texto y pintar badges.
   NO cambiar los IDs: coinciden con la BD y el contrato REST del proyecto.
   ========================================================================== */
window.CAT = {
  rol: {
    1: "Cliente",
    2: "Recepcionista",
    3: "Administrador",
  },

  estado_habitacion: {
    1: { txt: "Disponible", badge: "verde" },
    2: { txt: "Ocupada", badge: "rojo" },
    3: { txt: "Reservada", badge: "azul" },
    4: { txt: "Mantenimiento", badge: "ambar" },
  },

  estado_reserva: {
    1: { txt: "Pendiente", badge: "ambar" },
    2: { txt: "Confirmada", badge: "verde" },
    3: { txt: "Cancelada", badge: "rojo" },
    4: { txt: "Completada", badge: "azul" },
    5: { txt: "No show", badge: "gris" },
  },

  metodo_pago: {
    1: "Efectivo",
    2: "Tarjeta crédito",
    3: "Tarjeta débito",
    4: "Transferencia",
    5: "Yape/Plin",
  },

  estado_pago: {
    1: { txt: "Pendiente", badge: "ambar" },
    2: { txt: "Pagado", badge: "verde" },
    3: { txt: "Rechazado", badge: "rojo" },
    4: { txt: "Reembolsado", badge: "gris" },
  },
};

// Transiciones de estado de reserva permitidas por el personal (admin_service.py).
window.TRANSICIONES_RESERVA = {
  1: [2, 3],       // pendiente  -> confirmada / cancelada
  2: [4, 5, 3],    // confirmada -> completada / no_show / cancelada
  3: [],           // cancelada  (final)
  4: [],           // completada (final)
  5: [],           // no_show    (final)
};
