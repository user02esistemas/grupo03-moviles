/// Espejo de la tabla `rol` de la BD (IDs fijos: 1 cliente, 2 recepcionista,
/// 3 administrador). Se usa para el ruteo por rol y para reglas de UI.
enum Rol {
  cliente(1, 'cliente'),
  recepcionista(2, 'recepcionista'),
  administrador(3, 'administrador');

  const Rol(this.id, this.nombre);

  final int id;
  final String nombre;

  /// El personal (recepción + admin) ve el panel de administración.
  bool get esPersonal => this == recepcionista || this == administrador;

  static Rol fromId(int id) => switch (id) {
        1 => Rol.cliente,
        2 => Rol.recepcionista,
        3 => Rol.administrador,
        _ => throw ArgumentError('id_rol desconocido: $id'),
      };

  /// Acepta tanto el nombre ("cliente") como el id ("1") según cómo lo
  /// devuelva FastAPI en el JSON del usuario.
  static Rol fromJson(Object? value) {
    if (value is int) return fromId(value);
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null) return fromId(asInt);
      return Rol.values.firstWhere(
        (r) => r.nombre == value,
        orElse: () => throw ArgumentError('rol desconocido: $value'),
      );
    }
    throw ArgumentError('valor de rol inválido: $value');
  }
}