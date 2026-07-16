import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_sign_in_button_stub.dart'
    if (dart.library.js_util) 'google_sign_in_button_web.dart';

const apiUrl = String.fromEnvironment('API_URL',
    defaultValue: 'http://localhost:4000/api');
const googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID',
    defaultValue:
        '768062239335-bvn9psmjnpar4cijousl2nuetnj9o27d.apps.googleusercontent.com');

void main() {
  runApp(const HotelCasablancaApp());
}

class HotelColors {
  static const background = Color(0xFFEAE3D9);
  static const surface = Color(0xFFF9F6F0);
  static const ink = Color(0xFF4A3C31);
  static const muted = Color(0xFF7A6A5E);
  static const accent = Color(0xFFA2846B);
  static const border = Color(0xFFDCD3C6);
  static const dark = Color(0xFF2C241D);
}

class HotelCasablancaApp extends StatefulWidget {
  const HotelCasablancaApp({super.key});

  @override
  State<HotelCasablancaApp> createState() => _HotelCasablancaAppState();
}

class _HotelCasablancaAppState extends State<HotelCasablancaApp> {
  final api = ApiClient(apiUrl);
  bool loadingSession = true;
  String? token;
  String role = 'Cliente';

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      token = prefs.getString('token');
      role = normalizarRol(prefs.getString('rol'));
      loadingSession = false;
    });
  }

  Future<void> _saveSession(String newToken, String newRole) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', newToken);
    await prefs.setString('rol', normalizarRol(newRole));
    setState(() {
      token = newToken;
      role = normalizarRol(newRole);
    });
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('rol');
    setState(() {
      token = null;
      role = 'Cliente';
    });
    if (context.mounted) {
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Hotel Casa Blanca',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: HotelColors.accent,
          brightness: Brightness.light,
          surface: HotelColors.surface,
        ),
        scaffoldBackgroundColor: HotelColors.background,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: HotelColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: HotelColors.accent, width: 1.4),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => _page(CatalogPage(api: api, token: token)),
        '/catalogo': (_) => _page(CatalogPage(api: api, token: token)),
        '/login': (_) => _page(LoginPage(api: api, onLogin: _saveSession)),
        '/registro': (_) => _page(RegistroPage(api: api)),
        '/perfil': (_) => _protected(
              (sessionToken) => PerfilPage(api: api, token: sessionToken),
            ),
        '/mis-reservas': (_) => _protected(
              (sessionToken) => MisReservasPage(api: api, token: sessionToken),
              requiredRole: 'Cliente',
            ),
        '/admin': (_) => _protected(
              (sessionToken) =>
                  AdminReservasPage(api: api, token: sessionToken),
              requiredRole: 'Admin',
            ),
      },
    );
  }

  Widget _page(Widget child) {
    return HotelScaffold(
      token: token,
      role: role,
      onLogout: _logout,
      child: child,
    );
  }

  Widget _protected(Widget Function(String token) builder,
      {String? requiredRole}) {
    if (loadingSession) {
      return const LoadingPage();
    }
    if (token == null) {
      return _page(LoginPage(api: api, onLogin: _saveSession));
    }
    if (requiredRole != null && normalizarRol(requiredRole) != role) {
      return _page(role == 'Admin'
          ? AdminReservasPage(api: api, token: token!)
          : CatalogPage(api: api, token: token));
    }
    return _page(builder(token!));
  }
}

class HotelScaffold extends StatelessWidget {
  const HotelScaffold({
    super.key,
    required this.child,
    required this.token,
    required this.role,
    required this.onLogout,
  });

  final Widget child;
  final String? token;
  final String role;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            HotelNavBar(token: token, role: role, onLogout: onLogout),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class HotelNavBar extends StatelessWidget {
  const HotelNavBar({
    super.key,
    required this.token,
    required this.role,
    required this.onLogout,
  });

  final String? token;
  final String role;
  final Future<void> Function(BuildContext context) onLogout;

  @override
  Widget build(BuildContext context) {
    final isAdmin = token != null && role == 'Admin';
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: HotelColors.surface,
        border: Border(bottom: BorderSide(color: HotelColors.border)),
        boxShadow: [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 2))
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 900;
                final links = isAdmin
                    ? <Widget>[
                        _navLink(context, 'Panel', '/admin', strong: true),
                        _outlineAction(context, 'Salir', Icons.logout,
                            () => onLogout(context)),
                      ]
                    : <Widget>[
                        _navLink(context, 'Catálogo', '/catalogo'),
                        if (token != null) ...[
                          _navLink(context, 'Mi Perfil', '/perfil',
                              strong: true),
                          _navLink(context, 'Mis Reservas', '/mis-reservas'),
                          _outlineAction(context, 'Salir', Icons.logout,
                              () => onLogout(context)),
                        ] else ...[
                          _navLink(context, 'Entrar', '/login'),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(context)
                                .pushReplacementNamed('/registro'),
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('Registrarse'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: HotelColors.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                          ),
                        ],
                      ];

                return Flex(
                  direction: narrow ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: narrow
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    InkWell(
                      onTap: () => Navigator.of(context)
                          .pushReplacementNamed('/catalogo'),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Casa Blanca',
                            style: TextStyle(
                              color: HotelColors.ink,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'HOTEL & RETIRO',
                            style: TextStyle(
                              color: HotelColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: narrow ? 12 : 0, width: narrow ? 0 : 18),
                    Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: links),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _navLink(BuildContext context, String label, String route,
      {bool strong = false}) {
    return TextButton(
      onPressed: () => Navigator.of(context).pushReplacementNamed(route),
      child: Text(
        label,
        style: TextStyle(
          color: strong ? HotelColors.accent : HotelColors.ink,
          fontSize: 13,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _outlineAction(BuildContext context, String label, IconData icon,
      VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: HotelColors.accent,
        side: const BorderSide(color: HotelColors.accent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    );
  }
}

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.api, required this.token});

  final ApiClient api;
  final String? token;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  late DateTime checkIn;
  late DateTime checkOut;
  String selectedTipo = '';
  bool loading = true;
  List<Map<String, dynamic>> rooms = [];
  List<Map<String, dynamic>> types = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    checkIn = DateTime(today.year, today.month, today.day);
    checkOut = checkIn.add(const Duration(days: 1));
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final loadedTypes = await widget.api.list('/habitaciones/tipos');
      final params = {
        'fecha_ingreso': isoDate(checkIn),
        'fecha_salida': isoDate(checkOut),
        if (selectedTipo.isNotEmpty) 'id_tipo': selectedTipo,
      };
      final loadedRooms =
          await widget.api.list('/habitaciones/disponibles', query: params);
      if (!mounted) return;
      setState(() {
        types = loadedTypes;
        rooms = loadedRooms;
      });
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickDate({required bool isCheckIn}) async {
    final current = isCheckIn ? checkIn : checkOut;
    final firstDate =
        isCheckIn ? DateTime.now() : checkIn.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(firstDate) ? firstDate : current,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        checkIn = DateTime(picked.year, picked.month, picked.day);
        if (!checkOut.isAfter(checkIn)) {
          checkOut = checkIn.add(const Duration(days: 1));
        }
      } else {
        checkOut = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _startBooking(Map<String, dynamic> room) async {
    if (widget.token == null) {
      showSnack(context,
          'Por favor, inicia sesión o regístrate para poder reservar.');
      Navigator.of(context).pushReplacementNamed('/login');
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => BookingDialog(
        room: room,
        initialCheckIn: checkIn,
        initialCheckOut: checkOut,
        api: widget.api,
        token: widget.token!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 26, 16, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Nuestras Habitaciones',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: HotelColors.ink,
                    fontSize: 42,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Encuentra el espacio perfecto para tu descanso, diseñado con armonía y calidez.',
                textAlign: TextAlign.center,
                style: TextStyle(color: HotelColors.muted, fontSize: 17),
              ),
              const SizedBox(height: 28),
              FilterPanel(
                checkIn: checkIn,
                checkOut: checkOut,
                selectedTipo: selectedTipo,
                types: types,
                onCheckIn: () => _pickDate(isCheckIn: true),
                onCheckOut: () => _pickDate(isCheckIn: false),
                onTipoChanged: (value) =>
                    setState(() => selectedTipo = value ?? ''),
                onSearch: _load,
              ),
              const SizedBox(height: 28),
              if (loading)
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (rooms.isEmpty)
                const EmptyState(
                    text:
                        'No encontramos habitaciones disponibles para las fechas solicitadas.')
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final columns = width >= 1040 ? 3 : (width >= 680 ? 2 : 1);
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: columns == 1 ? 0.92 : 0.72,
                      ),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        return RoomCard(
                          api: widget.api,
                          room: rooms[index],
                          onBook: () => _startBooking(rooms[index]),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FilterPanel extends StatelessWidget {
  const FilterPanel({
    super.key,
    required this.checkIn,
    required this.checkOut,
    required this.selectedTipo,
    required this.types,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onTipoChanged,
    required this.onSearch,
  });

  final DateTime checkIn;
  final DateTime checkOut;
  final String selectedTipo;
  final List<Map<String, dynamic>> types;
  final VoidCallback onCheckIn;
  final VoidCallback onCheckOut;
  final ValueChanged<String?> onTipoChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 780;
          return Flex(
            direction: narrow ? Axis.vertical : Axis.horizontal,
            crossAxisAlignment: narrow
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.center,
            children: [
              ExpandedOrPlain(
                enabled: !narrow,
                child: ExpandedDateButton(
                    label: 'Llegada',
                    value: displayDate(isoDate(checkIn)),
                    onTap: onCheckIn),
              ),
              SizedBox(width: narrow ? 0 : 12, height: narrow ? 12 : 0),
              ExpandedOrPlain(
                enabled: !narrow,
                child: ExpandedDateButton(
                    label: 'Salida',
                    value: displayDate(isoDate(checkOut)),
                    onTap: onCheckOut),
              ),
              SizedBox(width: narrow ? 0 : 12, height: narrow ? 12 : 0),
              ExpandedOrPlain(
                enabled: !narrow,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(selectedTipo),
                  initialValue: selectedTipo,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Ambiente'),
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Todos los espacios')),
                    ...types.map(
                      (type) => DropdownMenuItem(
                        value: textValue(type, 'id_tipo'),
                        child: Text(textValue(type, 'nombre_tipo')),
                      ),
                    ),
                  ],
                  onChanged: onTipoChanged,
                ),
              ),
              SizedBox(width: narrow ? 0 : 12, height: narrow ? 12 : 0),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: onSearch,
                  icon: const Icon(Icons.search),
                  label: const Text('Buscar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: HotelColors.ink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class ExpandedDateButton extends StatelessWidget {
  const ExpandedDateButton(
      {super.key,
      required this.label,
      required this.value,
      required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard(
      {super.key, required this.api, required this.room, required this.onBook});

  final ApiClient api;
  final Map<String, dynamic> room;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    final services = listStrings(room['servicios']);
    final image = textValue(room, 'imagen');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: HotelColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HotelColors.border.withValues(alpha: 0.8)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 4,
            child: image.isEmpty
                ? const RoomImageFallback()
                : Image.network(
                    api.absoluteUrl(image),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const RoomImageFallback(),
                  ),
          ),
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          textValue(room, 'tipo_habitacion', 'Retiro Boutique')
                              .toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: HotelColors.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text('Máx: ${intValue(room, 'capacidad')}'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: HotelColors.background,
                        side: const BorderSide(color: HotelColors.border),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Habitación ${textValue(room, 'numero_habitacion')}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HotelColors.ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Text(
                      textValue(room, 'descripcion'),
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                          color: HotelColors.muted, height: 1.35),
                    ),
                  ),
                  if (services.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: services
                          .take(4)
                          .map((service) => ServiceChip(service))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Por noche',
                                style: TextStyle(
                                    color: HotelColors.muted, fontSize: 12)),
                            Text(
                              'S/ ${money(numValue(room, 'precio_noche'))}',
                              style: const TextStyle(
                                  color: HotelColors.ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: onBook,
                        icon: const Icon(Icons.hotel, size: 18),
                        label: const Text('Reservar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: HotelColors.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingDialog extends StatefulWidget {
  const BookingDialog({
    super.key,
    required this.room,
    required this.initialCheckIn,
    required this.initialCheckOut,
    required this.api,
    required this.token,
  });

  final Map<String, dynamic> room;
  final DateTime initialCheckIn;
  final DateTime initialCheckOut;
  final ApiClient api;
  final String token;

  @override
  State<BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<BookingDialog> {
  late DateTime checkIn;
  late DateTime checkOut;
  late int guests;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    checkIn = widget.initialCheckIn;
    checkOut = widget.initialCheckOut;
    guests = 1;
  }

  int get nights => math.max(0, checkOut.difference(checkIn).inDays);
  double get subtotal => nights * numValue(widget.room, 'precio_noche');
  double get igv => subtotal * 0.18;
  double get total => subtotal + igv;

  Future<void> _pick({required bool isCheckIn}) async {
    final current = isCheckIn ? checkIn : checkOut;
    final firstDate =
        isCheckIn ? DateTime.now() : checkIn.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(firstDate) ? firstDate : current,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        checkIn = DateTime(picked.year, picked.month, picked.day);
        if (!checkOut.isAfter(checkIn)) {
          checkOut = checkIn.add(const Duration(days: 1));
        }
      } else {
        checkOut = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _confirm() async {
    final capacity = intValue(widget.room, 'capacidad');
    if (guests > capacity) {
      showSnack(context, 'Esta habitación permite máximo $capacity personas.');
      return;
    }
    setState(() => saving = true);
    try {
      await widget.api.post(
        '/reservas',
        {
          'id_habitacion': intValue(widget.room, 'id_habitacion'),
          'fecha_ingreso': isoDate(checkIn),
          'fecha_salida': isoDate(checkOut),
          'cantidad_personas': guests,
        },
        token: widget.token,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).pushReplacementNamed('/mis-reservas');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: HotelColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Completar estadía',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: HotelColors.ink,
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close)),
                ],
              ),
              Text(
                'Habitación ${textValue(widget.room, 'numero_habitacion')} · Máx. ${intValue(widget.room, 'capacidad')} huéspedes',
                style: const TextStyle(color: HotelColors.muted),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: HotelColors.border),
                ),
                child: Column(
                  children: [
                    SummaryRow(
                        'Tipo', textValue(widget.room, 'tipo_habitacion')),
                    SummaryRow('Precio por noche',
                        'S/ ${money(numValue(widget.room, 'precio_noche'))}'),
                    SummaryRow('Noches', '$nights'),
                    SummaryRow('Subtotal', 'S/ ${money(subtotal)}'),
                    SummaryRow('IGV 18%', 'S/ ${money(igv)}'),
                    const Divider(),
                    SummaryRow('Total estimado', 'S/ ${money(total)}',
                        strong: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ExpandedDateButton(
                  label: 'Fecha de ingreso',
                  value: displayDate(isoDate(checkIn)),
                  onTap: () => _pick(isCheckIn: true)),
              const SizedBox(height: 12),
              ExpandedDateButton(
                  label: 'Fecha de salida',
                  value: displayDate(isoDate(checkOut)),
                  onTap: () => _pick(isCheckIn: false)),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: guests.toString(),
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Número de huéspedes'),
                onChanged: (value) => guests = int.tryParse(value) ?? 1,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                        onPressed:
                            saving ? null : () => Navigator.of(context).pop(),
                        child: const Text('Atrás')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: saving ? null : _confirm,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: HotelColors.ink,
                          foregroundColor: Colors.white),
                      child: Text(saving ? 'Guardando...' : 'Confirmar'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});

  final ApiClient api;
  final Future<void> Function(String token, String role) onLogin;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  final googleSignIn = GoogleSignIn(
    scopes: ['email'],
    clientId: googleClientId,
  );
  StreamSubscription<GoogleSignInAccount?>? googleSubscription;
  bool loading = false;
  bool googleLoading = false;
  bool googleLoginInFlight = false;

  @override
  void initState() {
    super.initState();
    googleSubscription =
        googleSignIn.onCurrentUserChanged.listen((account) {
      if (account != null) {
        unawaited(_completeGoogleLogin(account));
      }
    }, onError: (error) {
      if (mounted) showSnack(context, error.toString());
    });
    unawaited(googleSignIn.signInSilently());
  }

  @override
  void dispose() {
    googleSubscription?.cancel();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => loading = true);
    try {
      final response = await widget.api.post('/auth/login', {
        'correo': email.text.trim(),
        'contrasena': password.text,
      });
      final token = textValue(response, 'token');
      final role = normalizarRol(response['rol']);
      await widget.onLogin(token, role);
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(role == 'Admin' ? '/admin' : '/catalogo');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _completeGoogleLogin(GoogleSignInAccount account) async {
    if (googleLoginInFlight) return;
    googleLoginInFlight = true;
    setState(() => googleLoading = true);
    try {
      final authentication = await account.authentication;
      final credential = authentication.idToken;
      if (credential == null || credential.isEmpty) {
        throw ApiException('Google no devolvio un token valido.');
      }

      final response = await widget.api.post('/auth/google', {
        'credential': credential,
      });
      final token = textValue(response, 'token');
      final role = normalizarRol(response['rol']);
      await widget.onLogin(token, role);
      if (!mounted) return;
      Navigator.of(context)
          .pushReplacementNamed(role == 'Admin' ? '/admin' : '/catalogo');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
      await googleSignIn.signOut();
    } finally {
      googleLoginInFlight = false;
      if (mounted) setState(() => googleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Bienvenido de nuevo',
      subtitle: 'Ingresa tus credenciales para continuar',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Correo electrónico')),
          const SizedBox(height: 14),
          TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: loading || googleLoading ? null : _submit,
            icon: const Icon(Icons.login),
            label: Text(loading ? 'Procesando...' : 'Ingresar'),
            style: primaryButtonStyle(),
          ),
          const SizedBox(height: 10),
          AbsorbPointer(
            absorbing: loading || googleLoading,
            child: SizedBox(
              height: 44,
              child: googleSignInButton(minimumWidth: 400),
            ),
          ),
          if (googleLoading) ...[
            const SizedBox(height: 8),
            const Center(child: Text('Conectando con Google...')),
          ],
          const SizedBox(height: 18),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/registro'),
            child: const Text('¿No tienes cuenta? Regístrate aquí'),
          ),
        ],
      ),
    );
  }
}

class RegistroPage extends StatefulWidget {
  const RegistroPage({super.key, required this.api});

  final ApiClient api;

  @override
  State<RegistroPage> createState() => _RegistroPageState();
}

class _RegistroPageState extends State<RegistroPage> {
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final telefono = TextEditingController();
  final correo = TextEditingController();
  final password = TextEditingController();
  bool loading = false;

  @override
  void dispose() {
    nombre.dispose();
    apellido.dispose();
    telefono.dispose();
    correo.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final letters = RegExp(r"^[\p{L}\s.'-]+$", unicode: true);
    final phone = RegExp(r'^[0-9+()\-\s]{7,20}$');
    final mail = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    if (!letters.hasMatch(nombre.text.trim()) ||
        !letters.hasMatch(apellido.text.trim())) {
      showSnack(
          context, 'El nombre y el apellido solo pueden contener letras.');
      return;
    }
    if (!phone.hasMatch(telefono.text.trim())) {
      showSnack(context, 'Ingresa un número de teléfono válido.');
      return;
    }
    if (!mail.hasMatch(correo.text.trim())) {
      showSnack(context, 'Ingresa un correo electrónico válido.');
      return;
    }
    if (password.text.length < 6) {
      showSnack(context, 'La contraseña debe tener al menos 6 caracteres.');
      return;
    }

    setState(() => loading = true);
    try {
      await widget.api.post('/auth/registro', {
        'nombre': nombre.text.trim(),
        'apellido': apellido.text.trim(),
        'telefono': telefono.text.trim(),
        'correo': correo.text.trim(),
        'contrasena': password.text,
      });
      if (!mounted) return;
      showSnack(context, 'Cuenta creada. Ahora inicia sesión.');
      Navigator.of(context).pushReplacementNamed('/login');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Crear cuenta',
      subtitle: 'Únete a Casa Blanca',
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final twoColumns = constraints.maxWidth > 420;
              final fields = [
                TextField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                TextField(
                    controller: apellido,
                    decoration: const InputDecoration(labelText: 'Apellido')),
              ];
              return Flex(
                direction: twoColumns ? Axis.horizontal : Axis.vertical,
                children: [
                  ExpandedOrPlain(enabled: twoColumns, child: fields[0]),
                  SizedBox(
                      width: twoColumns ? 12 : 0, height: twoColumns ? 0 : 12),
                  ExpandedOrPlain(enabled: twoColumns, child: fields[1]),
                ],
              );
            },
          ),
          const SizedBox(height: 14),
          TextField(
              controller: telefono,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono')),
          const SizedBox(height: 14),
          TextField(
              controller: correo,
              keyboardType: TextInputType.emailAddress,
              decoration:
                  const InputDecoration(labelText: 'Correo electrónico')),
          const SizedBox(height: 14),
          TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: loading ? null : _submit,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(loading ? 'Registrando...' : 'Registrarme'),
              style: primaryButtonStyle(),
            ),
          ),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pushReplacementNamed('/login'),
            child: const Text('¿Ya tienes cuenta? Inicia sesión'),
          ),
        ],
      ),
    );
  }
}

class PerfilPage extends StatefulWidget {
  const PerfilPage({super.key, required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  State<PerfilPage> createState() => _PerfilPageState();
}

class _PerfilPageState extends State<PerfilPage> {
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final telefono = TextEditingController();
  final correo = TextEditingController();
  String role = 'Cliente';
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nombre.dispose();
    apellido.dispose();
    telefono.dispose();
    correo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final profile = await widget.api.get('/auth/perfil', token: widget.token);
      if (!mounted) return;
      nombre.text = textValue(profile, 'nombre');
      apellido.text = textValue(profile, 'apellido');
      telefono.text = textValue(profile, 'telefono') == 'No especificado'
          ? ''
          : textValue(profile, 'telefono');
      correo.text = textValue(profile, 'correo');
      role = normalizarRol(profile['rol']);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await widget.api.put(
          '/auth/perfil',
          {
            'nombre': nombre.text.trim(),
            'apellido': apellido.text.trim(),
            'telefono': telefono.text.trim(),
          },
          token: widget.token);
      if (mounted) {
        showSnack(context, 'Tus datos han sido actualizados con éxito.');
      }
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const LoadingPage(message: 'Cargando tu información...');
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: CardShell(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CircleAvatar(
                  radius: 42,
                  backgroundColor: HotelColors.border,
                  child: Text(
                    '${firstLetter(nombre.text)}${firstLetter(apellido.text)}',
                    style: const TextStyle(
                        color: HotelColors.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Mi Perfil',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Center(child: ServiceChip(role)),
                const SizedBox(height: 22),
                TextField(
                    controller: nombre,
                    decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 14),
                TextField(
                    controller: apellido,
                    decoration: const InputDecoration(labelText: 'Apellido')),
                const SizedBox(height: 14),
                TextField(
                    controller: telefono,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Teléfono')),
                const SizedBox(height: 14),
                TextField(
                  controller: correo,
                  enabled: false,
                  decoration:
                      const InputDecoration(labelText: 'Correo electrónico'),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: saving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'Actualizando...' : 'Guardar cambios'),
                  style: primaryButtonStyle(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MisReservasPage extends StatefulWidget {
  const MisReservasPage({super.key, required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  State<MisReservasPage> createState() => _MisReservasPageState();
}

class _MisReservasPageState extends State<MisReservasPage> {
  bool loading = true;
  List<Map<String, dynamic>> reservations = [];
  int? voucherReservation;
  int? qrReservation;
  int? payingReservation;
  String method = '';
  PlatformFile? pickedFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data =
          await widget.api.list('/reservas/mis-reservas', token: widget.token);
      if (mounted) setState(() => reservations = data);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() => pickedFile = result.files.first);
  }

  Future<void> _uploadVoucher(int reservationId) async {
    if (method.isEmpty) {
      showSnack(context, 'Selecciona un método de pago.');
      return;
    }
    if (pickedFile?.bytes == null) {
      showSnack(context, 'Selecciona una imagen o PDF de tu voucher.');
      return;
    }
    try {
      await widget.api.uploadVoucher(
        token: widget.token,
        reservationId: reservationId,
        method: method,
        file: pickedFile!,
      );
      if (!mounted) return;
      showSnack(context, 'Voucher enviado con éxito.');
      setState(() {
        voucherReservation = null;
        pickedFile = null;
        method = '';
      });
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _payOnline(int reservationId) async {
    setState(() => payingReservation = reservationId);
    try {
      final response = await widget.api.post(
          '/pagos/crear-preferencia', {'id_reserva': reservationId},
          token: widget.token);
      final url = textValue(response, 'init_point');
      if (!mounted) return;
      if (url.isEmpty) {
        showSnack(context, 'Mercado Pago no devolvió un enlace de pago.');
        return;
      }
      await launchUrl(Uri.parse(url), mode: LaunchMode.platformDefault);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => payingReservation = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageTitle('Mis Reservas'),
              if (loading)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()))
              else if (reservations.isEmpty)
                const EmptyState(text: 'No tienes reservas registradas.')
              else
                ...reservations.map((reservation) => ReservationCard(
                      reservation: reservation,
                      api: widget.api,
                      voucherReservation: voucherReservation,
                      qrReservation: qrReservation,
                      paying: payingReservation ==
                          intValue(reservation, 'id_reserva'),
                      selectedMethod: method,
                      pickedFile: pickedFile,
                      onMethodChanged: (value) =>
                          setState(() => method = value ?? ''),
                      onPickFile: _pickFile,
                      onSubmitVoucher: () =>
                          _uploadVoucher(intValue(reservation, 'id_reserva')),
                      onToggleVoucher: () => setState(() {
                        voucherReservation = voucherReservation ==
                                intValue(reservation, 'id_reserva')
                            ? null
                            : intValue(reservation, 'id_reserva');
                        qrReservation = null;
                        pickedFile = null;
                      }),
                      onToggleQr: () => setState(() {
                        qrReservation =
                            qrReservation == intValue(reservation, 'id_reserva')
                                ? null
                                : intValue(reservation, 'id_reserva');
                        voucherReservation = null;
                      }),
                      onPayOnline: () =>
                          _payOnline(intValue(reservation, 'id_reserva')),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class ReservationCard extends StatelessWidget {
  const ReservationCard({
    super.key,
    required this.reservation,
    required this.api,
    required this.voucherReservation,
    required this.qrReservation,
    required this.paying,
    required this.selectedMethod,
    required this.pickedFile,
    required this.onMethodChanged,
    required this.onPickFile,
    required this.onSubmitVoucher,
    required this.onToggleVoucher,
    required this.onToggleQr,
    required this.onPayOnline,
  });

  final Map<String, dynamic> reservation;
  final ApiClient api;
  final int? voucherReservation;
  final int? qrReservation;
  final bool paying;
  final String selectedMethod;
  final PlatformFile? pickedFile;
  final ValueChanged<String?> onMethodChanged;
  final VoidCallback onPickFile;
  final VoidCallback onSubmitVoucher;
  final VoidCallback onToggleVoucher;
  final VoidCallback onToggleQr;
  final VoidCallback onPayOnline;

  @override
  Widget build(BuildContext context) {
    final id = intValue(reservation, 'id_reserva');
    final base = numValue(reservation, 'monto_total');
    final igv = base * 0.18;
    final total = base + igv;
    final pending =
        textValue(reservation, 'estado_reserva').toLowerCase() == 'pendiente';
    final comprobante = textValue(reservation, 'imagen_comprobante');

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: CardShell(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 760;
            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Habitación ${textValue(reservation, 'numero_habitacion')}',
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: HotelColors.ink),
                    ),
                    ServiceChip(textValue(reservation, 'tipo_habitacion')),
                  ],
                ),
                const SizedBox(height: 10),
                InfoGrid(items: {
                  'Código': textValue(reservation, 'codigo_reserva'),
                  'Estado': textValue(reservation, 'estado_reserva'),
                  'Ingreso':
                      displayDate(textValue(reservation, 'fecha_ingreso')),
                  'Salida': displayDate(textValue(reservation, 'fecha_salida')),
                  'Noches': textValue(reservation, 'noches'),
                  'Huéspedes':
                      '${textValue(reservation, 'cantidad_personas')} de ${textValue(reservation, 'capacidad')}',
                  'Pago': textValue(reservation, 'estado_pago', 'Pendiente'),
                  'Método':
                      textValue(reservation, 'metodo_pago', 'Sin registrar'),
                }),
                if (comprobante.isNotEmpty)
                  TextButton.icon(
                    onPressed: () =>
                        launchUrl(Uri.parse(api.absoluteUrl(comprobante))),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Ver comprobante enviado'),
                  ),
              ],
            );

            final payment = PaymentBox(
              base: base,
              igv: igv,
              total: total,
              pending: pending,
              reservationId: id,
              voucherOpen: voucherReservation == id,
              qrOpen: qrReservation == id,
              paying: paying,
              selectedMethod: selectedMethod,
              pickedFile: pickedFile,
              onMethodChanged: onMethodChanged,
              onPickFile: onPickFile,
              onSubmitVoucher: onSubmitVoucher,
              onToggleVoucher: onToggleVoucher,
              onToggleQr: onToggleQr,
              onPayOnline: onPayOnline,
            );

            return Flex(
              direction: narrow ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpandedOrPlain(enabled: !narrow, child: details),
                SizedBox(width: narrow ? 0 : 18, height: narrow ? 18 : 0),
                SizedBox(width: narrow ? double.infinity : 320, child: payment),
              ],
            );
          },
        ),
      ),
    );
  }
}

class PaymentBox extends StatelessWidget {
  const PaymentBox({
    super.key,
    required this.base,
    required this.igv,
    required this.total,
    required this.pending,
    required this.reservationId,
    required this.voucherOpen,
    required this.qrOpen,
    required this.paying,
    required this.selectedMethod,
    required this.pickedFile,
    required this.onMethodChanged,
    required this.onPickFile,
    required this.onSubmitVoucher,
    required this.onToggleVoucher,
    required this.onToggleQr,
    required this.onPayOnline,
  });

  final double base;
  final double igv;
  final double total;
  final bool pending;
  final int reservationId;
  final bool voucherOpen;
  final bool qrOpen;
  final bool paying;
  final String selectedMethod;
  final PlatformFile? pickedFile;
  final ValueChanged<String?> onMethodChanged;
  final VoidCallback onPickFile;
  final VoidCallback onSubmitVoucher;
  final VoidCallback onToggleVoucher;
  final VoidCallback onToggleQr;
  final VoidCallback onPayOnline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HotelColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SummaryRow('Subtotal', 'S/ ${money(base)}'),
          SummaryRow('IGV 18%', 'S/ ${money(igv)}'),
          const Divider(),
          SummaryRow('Total', 'S/ ${money(total)}', strong: true),
          const SizedBox(height: 12),
          if (!pending)
            const Text('Reserva procesada',
                textAlign: TextAlign.center,
                style:
                    TextStyle(color: Colors.green, fontWeight: FontWeight.w800))
          else ...[
            ElevatedButton.icon(
              onPressed: paying ? null : onPayOnline,
              icon: const Icon(Icons.credit_card),
              label: Text(paying ? 'Abriendo...' : 'Pagar online'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF009EE3),
                  foregroundColor: Colors.white),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onToggleQr,
              icon: const Icon(Icons.qr_code_2),
              label: Text(qrOpen ? 'Ocultar QR' : 'Pagar con QR'),
            ),
            if (qrOpen) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.asset('assets/qr_alex_yape.JPG',
                    height: 220, fit: BoxFit.contain),
              ),
              const SizedBox(height: 8),
              const Text('Después de pagar, sube tu comprobante.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: HotelColors.muted)),
            ],
            if (!qrOpen) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: onToggleVoucher,
                icon: const Icon(Icons.upload_file),
                label:
                    Text(voucherOpen ? 'Cerrar voucher' : 'Tengo un voucher'),
              ),
            ],
            if (voucherOpen) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey(selectedMethod),
                initialValue: selectedMethod.isEmpty ? null : selectedMethod,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Método'),
                items: const [
                  DropdownMenuItem(value: 'Yape', child: Text('Yape')),
                  DropdownMenuItem(value: 'Plin', child: Text('Plin')),
                  DropdownMenuItem(
                      value: 'Transferencia', child: Text('Transferencia')),
                ],
                onChanged: onMethodChanged,
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(pickedFile == null
                    ? 'Seleccionar comprobante'
                    : pickedFile!.name),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: onSubmitVoucher,
                icon: const Icon(Icons.send),
                label: const Text('Enviar'),
                style: primaryButtonStyle(),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class AdminReservasPage extends StatefulWidget {
  const AdminReservasPage({super.key, required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  State<AdminReservasPage> createState() => _AdminReservasPageState();
}

class _AdminReservasPageState extends State<AdminReservasPage> {
  bool loading = true;
  List<Map<String, dynamic>> reservations = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final data = await widget.api
          .list('/reservas/admin/reservas', token: widget.token);
      if (mounted) setState(() => reservations = data);
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _changeStatus(int id, String status) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar reserva'),
        content: Text('¿Deseas marcar esta reserva como $status?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api.put(
          '/reservas/admin/reservas/$id', {'estado_reserva': status},
          token: widget.token);
      await _load();
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _releaseRoom(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Liberar habitación'),
        content: const Text(
            '¿Deseas liberar esta habitación por salida anticipada? La reserva quedará completada.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No')),
          ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sí, liberar')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await widget.api
          .put('/reservas/admin/reservas/$id/liberar', {}, token: widget.token);
      await _load();
      if (mounted) showSnack(context, 'Habitación liberada con éxito.');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    }
  }

  Future<void> _openReservationDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AdminBookingDialog(api: widget.api, token: widget.token),
    );
    if (created == true) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageTitle('Panel de Control',
                  subtitle: 'Gestión de reservas y pagos'),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: _openReservationDialog,
                  icon: const Icon(Icons.add_business),
                  label: const Text('Registrar reserva'),
                  style: primaryButtonStyle(),
                ),
              ),
              const SizedBox(height: 18),
              if (loading)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()))
              else if (reservations.isEmpty)
                const EmptyState(
                    text: 'No hay reservas registradas en el sistema.')
              else
                ...reservations.map((reservation) {
                  final id = intValue(reservation, 'id_reserva');
                  final pending =
                      textValue(reservation, 'estado_reserva').toLowerCase() ==
                          'pendiente';
                  final voucher = textValue(reservation, 'imagen');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: CardShell(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final narrow = constraints.maxWidth < 840;
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text('Reserva #$id',
                                      style: const TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800)),
                                  StatusChip(
                                      textValue(reservation, 'estado_reserva')),
                                ],
                              ),
                              const SizedBox(height: 10),
                              InfoGrid(items: {
                                'Cliente':
                                    '${textValue(reservation, 'nombre_cliente')} (${textValue(reservation, 'correo_cliente')})',
                                'Habitación':
                                    'N° ${textValue(reservation, 'numero_habitacion')} - ${textValue(reservation, 'tipo_habitacion')}',
                                'F. ingreso': displayDate(
                                    textValue(reservation, 'fecha_ingreso')),
                                'F. salida': displayDate(
                                    textValue(reservation, 'fecha_salida')),
                                'Noches': textValue(reservation, 'noches'),
                                'Huéspedes':
                                    '${textValue(reservation, 'cantidad_personas')} de ${textValue(reservation, 'capacidad')}',
                                'Monto base':
                                    'S/ ${money(numValue(reservation, 'monto_total'))}',
                                'Total con IGV':
                                    'S/ ${money(numValue(reservation, 'monto_total') * 1.18)}',
                                'Pago': textValue(
                                    reservation, 'estado_pago', 'Pendiente'),
                                'Método': textValue(reservation, 'metodo_pago',
                                    'Sin registrar'),
                              }),
                            ],
                          );
                          final actions = Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (voucher.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: () => launchUrl(Uri.parse(
                                      widget.api.absoluteUrl(voucher))),
                                  icon: const Icon(Icons.receipt_long),
                                  label: const Text('Ver comprobante'),
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: HotelColors.background,
                                      foregroundColor: HotelColors.ink),
                                )
                              else
                                const Text('Sin comprobante aún',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: HotelColors.muted)),
                              if (pending) ...[
                                const SizedBox(height: 10),
                                if (voucher.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: () =>
                                        _changeStatus(id, 'Confirmada'),
                                    icon:
                                        const Icon(Icons.check_circle_outline),
                                    label: const Text('Aprobar'),
                                    style: primaryButtonStyle(),
                                  ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      _changeStatus(id, 'Cancelada'),
                                  icon: const Icon(Icons.cancel_outlined),
                                  label: const Text('Cancelar'),
                                  style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red.shade700),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: () => _releaseRoom(id),
                                  icon: const Icon(Icons.meeting_room_outlined),
                                  label: const Text('Liberar habitación'),
                                ),
                              ],
                            ],
                          );
                          return Flex(
                            direction: narrow ? Axis.vertical : Axis.horizontal,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExpandedOrPlain(enabled: !narrow, child: details),
                              SizedBox(
                                  width: narrow ? 0 : 18,
                                  height: narrow ? 18 : 0),
                              SizedBox(
                                  width: narrow ? double.infinity : 240,
                                  child: actions),
                            ],
                          );
                        },
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminBookingDialog extends StatefulWidget {
  const AdminBookingDialog({super.key, required this.api, required this.token});

  final ApiClient api;
  final String token;

  @override
  State<AdminBookingDialog> createState() => _AdminBookingDialogState();
}

class _AdminBookingDialogState extends State<AdminBookingDialog> {
  final nombre = TextEditingController();
  final apellido = TextEditingController();
  final correo = TextEditingController();
  final telefono = TextEditingController();
  late DateTime checkIn;
  late DateTime checkOut;
  int guests = 1;
  String initialStatus = 'Confirmada';
  int? selectedRoomId;
  bool loadingRooms = true;
  bool saving = false;
  List<Map<String, dynamic>> rooms = [];

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    checkIn = DateTime(today.year, today.month, today.day);
    checkOut = checkIn.add(const Duration(days: 1));
    _loadRooms();
  }

  @override
  void dispose() {
    nombre.dispose();
    apellido.dispose();
    correo.dispose();
    telefono.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => loadingRooms = true);
    try {
      final data = await widget.api.list('/habitaciones/disponibles', query: {
        'fecha_ingreso': isoDate(checkIn),
        'fecha_salida': isoDate(checkOut),
      });
      if (!mounted) return;
      setState(() {
        rooms = data;
        if (rooms.isEmpty) {
          selectedRoomId = null;
        } else if (selectedRoomId == null ||
            !rooms.any(
                (room) => intValue(room, 'id_habitacion') == selectedRoomId)) {
          selectedRoomId = intValue(rooms.first, 'id_habitacion');
          guests =
              math.max(1, math.min(guests, intValue(rooms.first, 'capacidad')));
        }
      });
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => loadingRooms = false);
    }
  }

  Future<void> _pick({required bool isCheckIn}) async {
    final current = isCheckIn ? checkIn : checkOut;
    final firstDate =
        isCheckIn ? DateTime.now() : checkIn.add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isBefore(firstDate) ? firstDate : current,
      firstDate: DateTime(firstDate.year, firstDate.month, firstDate.day),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isCheckIn) {
        checkIn = DateTime(picked.year, picked.month, picked.day);
        if (!checkOut.isAfter(checkIn)) {
          checkOut = checkIn.add(const Duration(days: 1));
        }
      } else {
        checkOut = DateTime(picked.year, picked.month, picked.day);
      }
    });
    await _loadRooms();
  }

  Future<void> _submit() async {
    if (selectedRoomId == null) {
      showSnack(context, 'Selecciona una habitación disponible.');
      return;
    }
    if (nombre.text.trim().isEmpty ||
        apellido.text.trim().isEmpty ||
        correo.text.trim().isEmpty ||
        telefono.text.trim().isEmpty) {
      showSnack(context, 'Completa los datos del cliente.');
      return;
    }
    final selectedRoom = rooms.firstWhere(
        (room) => intValue(room, 'id_habitacion') == selectedRoomId);
    final capacity = intValue(selectedRoom, 'capacidad');
    if (guests > capacity) {
      showSnack(context, 'Esta habitación permite máximo $capacity personas.');
      return;
    }

    setState(() => saving = true);
    try {
      await widget.api.post(
          '/reservas/admin/reservas',
          {
            'cliente': {
              'nombre': nombre.text.trim(),
              'apellido': apellido.text.trim(),
              'correo': correo.text.trim(),
              'telefono': telefono.text.trim(),
            },
            'id_habitacion': selectedRoomId,
            'fecha_ingreso': isoDate(checkIn),
            'fecha_salida': isoDate(checkOut),
            'cantidad_personas': guests,
            'estado_reserva': initialStatus,
          },
          token: widget.token);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showSnack(context, 'Reserva registrada correctamente.');
    } catch (error) {
      if (mounted) showSnack(context, error.toString());
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: HotelColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Registrar reserva',
                      style: TextStyle(
                          color: HotelColors.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 18),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth > 560;
                  return Flex(
                    direction: twoColumns ? Axis.horizontal : Axis.vertical,
                    children: [
                      ExpandedOrPlain(
                          enabled: twoColumns,
                          child: TextField(
                              controller: nombre,
                              decoration:
                                  const InputDecoration(labelText: 'Nombre'))),
                      SizedBox(
                          width: twoColumns ? 12 : 0,
                          height: twoColumns ? 0 : 12),
                      ExpandedOrPlain(
                          enabled: twoColumns,
                          child: TextField(
                              controller: apellido,
                              decoration: const InputDecoration(
                                  labelText: 'Apellido'))),
                    ],
                  );
                },
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth > 560;
                  return Flex(
                    direction: twoColumns ? Axis.horizontal : Axis.vertical,
                    children: [
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: TextField(
                          controller: correo,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                              labelText: 'Correo electrónico'),
                        ),
                      ),
                      SizedBox(
                          width: twoColumns ? 12 : 0,
                          height: twoColumns ? 0 : 12),
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: TextField(
                          controller: telefono,
                          keyboardType: TextInputType.phone,
                          decoration:
                              const InputDecoration(labelText: 'Teléfono'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth > 560;
                  return Flex(
                    direction: twoColumns ? Axis.horizontal : Axis.vertical,
                    children: [
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: ExpandedDateButton(
                          label: 'Ingreso',
                          value: displayDate(isoDate(checkIn)),
                          onTap: () => _pick(isCheckIn: true),
                        ),
                      ),
                      SizedBox(
                          width: twoColumns ? 12 : 0,
                          height: twoColumns ? 0 : 12),
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: ExpandedDateButton(
                          label: 'Salida',
                          value: displayDate(isoDate(checkOut)),
                          onTap: () => _pick(isCheckIn: false),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              if (loadingRooms)
                const Center(
                    child: Padding(
                        padding: EdgeInsets.all(18),
                        child: CircularProgressIndicator()))
              else
                DropdownButtonFormField<int>(
                  key: ValueKey(selectedRoomId),
                  initialValue: selectedRoomId,
                  isExpanded: true,
                  decoration:
                      const InputDecoration(labelText: 'Habitación disponible'),
                  items: rooms.map((room) {
                    return DropdownMenuItem(
                      value: intValue(room, 'id_habitacion'),
                      child: Text(
                        'Hab. ${textValue(room, 'numero_habitacion')} · ${textValue(room, 'tipo_habitacion')} · S/ ${money(numValue(room, 'precio_noche'))} · Máx ${intValue(room, 'capacidad')}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedRoomId = value;
                      final room = rooms.firstWhere(
                          (item) => intValue(item, 'id_habitacion') == value);
                      guests = math.max(
                          1, math.min(guests, intValue(room, 'capacidad')));
                    });
                  },
                ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth > 560;
                  return Flex(
                    direction: twoColumns ? Axis.horizontal : Axis.vertical,
                    children: [
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: TextFormField(
                          initialValue: guests.toString(),
                          keyboardType: TextInputType.number,
                          decoration:
                              const InputDecoration(labelText: 'Huéspedes'),
                          onChanged: (value) =>
                              guests = int.tryParse(value) ?? 1,
                        ),
                      ),
                      SizedBox(
                          width: twoColumns ? 12 : 0,
                          height: twoColumns ? 0 : 12),
                      ExpandedOrPlain(
                        enabled: twoColumns,
                        child: DropdownButtonFormField<String>(
                          key: ValueKey(initialStatus),
                          initialValue: initialStatus,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Estado inicial'),
                          items: const [
                            DropdownMenuItem(
                                value: 'Confirmada', child: Text('Confirmada')),
                            DropdownMenuItem(
                                value: 'Pendiente', child: Text('Pendiente')),
                          ],
                          onChanged: (value) => setState(
                              () => initialStatus = value ?? 'Confirmada'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed:
                          saving || selectedRoomId == null ? null : _submit,
                      icon: const Icon(Icons.save),
                      label: Text(saving ? 'Guardando...' : 'Registrar'),
                      style: primaryButtonStyle(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ApiClient {
  ApiClient(String url) : baseUrl = url.replaceFirst(RegExp(r'/$'), '');

  final String baseUrl;

  String get origin => baseUrl.endsWith('/api')
      ? baseUrl.substring(0, baseUrl.length - 4)
      : baseUrl;

  String absoluteUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    final clean = path.replaceAll('\\', '/').replaceFirst(RegExp(r'^/'), '');
    return '$origin/$clean';
  }

  Future<Map<String, dynamic>> get(String path,
      {String? token, Map<String, String>? query}) async {
    final response =
        await http.get(_uri(path, query), headers: _headers(token));
    return _decodeMap(response);
  }

  Future<List<Map<String, dynamic>>> list(String path,
      {String? token, Map<String, String>? query}) async {
    final response =
        await http.get(_uri(path, query), headers: _headers(token));
    final decoded = _decode(response);
    return (decoded as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body,
      {String? token}) async {
    final response = await http.post(_uri(path),
        headers: _headers(token), body: jsonEncode(body));
    return _decodeMap(response);
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body,
      {String? token}) async {
    final response = await http.put(_uri(path),
        headers: _headers(token), body: jsonEncode(body));
    return _decodeMap(response);
  }

  Future<void> uploadVoucher({
    required String token,
    required int reservationId,
    required String method,
    required PlatformFile file,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/pagos/comprobante'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['id_reserva'] = reservationId.toString();
    request.fields['metodo_pago'] = method;
    request.files.add(
      http.MultipartFile.fromBytes(
        'comprobante',
        file.bytes!,
        filename: file.name,
        contentType: mediaTypeFor(file.name),
      ),
    );
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(response));
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final clean = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$clean');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  Map<String, String> _headers(String? token) => {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Map<String, dynamic> _decodeMap(http.Response response) {
    final decoded = _decode(response);
    return decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
  }

  dynamic _decode(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return {};
      return jsonDecode(utf8.decode(response.bodyBytes));
    }
    throw ApiException(_errorMessage(response));
  }

  String _errorMessage(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map && decoded['error'] != null) {
        return decoded['error'].toString();
      }
      if (decoded is Map && decoded['mensaje'] != null) {
        return decoded['mensaje'].toString();
      }
    } catch (_) {
      // Se devuelve un mensaje generico abajo.
    }
    return 'Error ${response.statusCode} al conectar con el servidor.';
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AuthLayout extends StatelessWidget {
  const AuthLayout(
      {super.key,
      required this.title,
      required this.subtitle,
      required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: CardShell(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: HotelColors.ink)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: HotelColors.muted)),
                const SizedBox(height: 24),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CardShell extends StatelessWidget {
  const CardShell(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: HotelColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: HotelColors.border),
        boxShadow: const [
          BoxShadow(
              color: Color(0x10000000), blurRadius: 14, offset: Offset(0, 6))
        ],
      ),
      child: child,
    );
  }
}

class ExpandedOrPlain extends StatelessWidget {
  const ExpandedOrPlain(
      {super.key, required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      enabled ? Expanded(child: child) : child;
}

class SummaryRow extends StatelessWidget {
  const SummaryRow(this.label, this.value, {super.key, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: HotelColors.ink,
      fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
      fontSize: strong ? 17 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: HotelColors.muted))),
          Text(value, textAlign: TextAlign.right, style: style),
        ],
      ),
    );
  }
}

class ServiceChip extends StatelessWidget {
  const ServiceChip(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: HotelColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HotelColors.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: HotelColors.ink, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});

  final String status;

  @override
  Widget build(BuildContext context) {
    final lower = status.toLowerCase();
    final color = lower == 'confirmada'
        ? Colors.green
        : lower == 'cancelada'
            ? Colors.red
            : Colors.amber.shade800;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16)),
      child: Text(status,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class InfoGrid extends StatelessWidget {
  const InfoGrid({super.key, required this.items});

  final Map<String, String> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 620 ? 2 : 1;
        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: columns == 1 ? 8.5 : 6,
          crossAxisSpacing: 12,
          mainAxisSpacing: 4,
          children: items.entries.map((entry) {
            return RichText(
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              text: TextSpan(
                style: const TextStyle(color: HotelColors.muted, fontSize: 14),
                children: [
                  TextSpan(
                      text: '${entry.key}: ',
                      style: const TextStyle(
                          color: HotelColors.ink, fontWeight: FontWeight.w800)),
                  TextSpan(text: entry.value),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class RoomImageFallback extends StatelessWidget {
  const RoomImageFallback({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: HotelColors.border,
      alignment: Alignment.center,
      child: const Text(
        'Casa Blanca',
        style: TextStyle(
            color: HotelColors.muted,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return CardShell(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 18),
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: HotelColors.muted, fontSize: 17)),
    );
  }
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, {super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: HotelColors.ink,
                  fontSize: 34,
                  fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: HotelColors.muted, fontWeight: FontWeight.w700)),
          ],
        ],
      ),
    );
  }
}

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key, this.message = 'Cargando...'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HotelColors.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 14),
            Text(message, style: const TextStyle(color: HotelColors.ink)),
          ],
        ),
      ),
    );
  }
}

ButtonStyle primaryButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: HotelColors.ink,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(48),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  );
}

MediaType mediaTypeFor(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
  if (lower.endsWith('.png')) return MediaType('image', 'png');
  return MediaType('image', 'jpeg');
}

String normalizarRol(Object? value) {
  final role = value.toString().toLowerCase();
  return role == 'admin' || role == 'administrador' ? 'Admin' : 'Cliente';
}

String textValue(Map<String, dynamic> map, String key, [String fallback = '']) {
  final value = map[key];
  if (value == null || value.toString().isEmpty) return fallback;
  return value.toString();
}

int intValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double numValue(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> listStrings(Object? value) {
  if (value is List) return value.map((item) => item.toString()).toList();
  return const [];
}

String isoDate(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year.toString().padLeft(4, '0')}-${normalized.month.toString().padLeft(2, '0')}-${normalized.day.toString().padLeft(2, '0')}';
}

String displayDate(String value) {
  if (value.isEmpty) return '---';
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value;
  final date = parsed.isUtc ? parsed.toUtc() : parsed;
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

String money(double value) => value.toStringAsFixed(2);

String firstLetter(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '' : trimmed[0].toUpperCase();
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
