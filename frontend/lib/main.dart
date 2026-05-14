import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8000');
const disclaimer =
    'GigOS is an independent shift, mileage, break, and earnings tracker for gig workers. Not affiliated with Uber, DoorDash, Grubhub, Instacart, Amazon Flex, or any delivery platform.';

void main() {
  runApp(const GigOSApp());
}

class GigOSApp extends StatelessWidget {
  const GigOSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xff32d583),
      brightness: Brightness.dark,
      surface: const Color(0xff151a1f),
    );
    return MaterialApp(
      title: 'GigOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xff101418),
        cardTheme: const CardTheme(
          color: Color(0xff171d23),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(8))),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xff1d252c),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
      ),
      home: const AppRoot(),
    );
  }
}

class ApiClient {
  ApiClient(this.token);
  String? token;

  Map<String, String> get headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri uri(String path) => Uri.parse('$apiBaseUrl$path');

  Future<dynamic> request(String method, String path, {Map<String, dynamic>? body}) async {
    final request = http.Request(method, uri(path));
    request.headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode >= 400) {
      String detail = 'Request failed';
      try {
        detail = jsonDecode(response.body)['detail'].toString();
      } catch (_) {}
      throw Exception(detail);
    }
    if (response.body.isEmpty) return null;
    return jsonDecode(response.body);
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  String? token;
  Map<String, dynamic>? me;
  late ApiClient api;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    api = ApiClient(null);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    api.token = token;
    if (token != null) {
      try {
        me = await api.request('GET', '/me') as Map<String, dynamic>;
      } catch (_) {
        await prefs.remove('token');
        token = null;
      }
    }
    setState(() => loading = false);
  }

  Future<void> setSession(String nextToken, Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', nextToken);
    setState(() {
      token = nextToken;
      api.token = nextToken;
      me = user;
    });
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    setState(() {
      token = null;
      api.token = null;
      me = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (token == null) {
      return AuthScreen(api: api, onSession: setSession);
    }
    return HomeShell(api: api, user: me!, onLogout: logout);
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.api, required this.onSession});
  final ApiClient api;
  final Future<void> Function(String token, Map<String, dynamic> user) onSession;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.request(
        'POST',
        register ? '/auth/register' : '/auth/login',
        body: {'email': email.text.trim(), 'password': password.text},
      ) as Map<String, dynamic>;
      await widget.onSession(data['access_token'] as String, data['user'] as Map<String, dynamic>);
    } catch (err) {
      setState(() => error = err.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('GigOS', style: TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text('Independent shift intelligence for gig work.', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 28),
                  TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: busy ? null : submit,
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                    child: Text(busy ? 'Working...' : register ? 'Create Account' : 'Login'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => register = !register),
                    child: Text(register ? 'Have an account? Login' : 'Need an account? Register'),
                  ),
                  const SizedBox(height: 20),
                  const Text(disclaimer, style: TextStyle(color: Color(0xff98a2b3), height: 1.35)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.api, required this.user, required this.onLogout});
  final ApiClient api;
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int refreshTick = 0;

  void refresh() => setState(() => refreshTick++);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: widget.api, refreshTick: refreshTick, onChanged: refresh),
      WeeklyPage(api: widget.api, refreshTick: refreshTick),
      SettingsPage(user: widget.user, onLogout: widget.onLogout),
      const PrivacyPage(),
    ];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.query_stats), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
          NavigationDestination(icon: Icon(Icons.privacy_tip_outlined), label: 'Privacy'),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, required this.refreshTick, required this.onChanged});
  final ApiClient api;
  final int refreshTick;
  final VoidCallback onChanged;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  List<dynamic> shifts = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant DashboardPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) load();
  }

  Future<void> load() async {
    setState(() => loading = true);
    try {
      shifts = await widget.api.request('GET', '/shifts') as List<dynamic>;
      error = null;
    } catch (err) {
      error = err.toString();
    }
    if (mounted) setState(() => loading = false);
  }

  Map<String, dynamic>? get activeShift {
    for (final shift in shifts) {
      if (shift['ended_at'] == null) return shift as Map<String, dynamic>;
    }
    return null;
  }

  Future<void> startShift() async {
    final platform = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => PlatformPicker(),
    );
    if (platform == null) return;
    await widget.api.request('POST', '/shifts/start', body: {'platform': platform});
    widget.onChanged();
  }

  Future<void> endShift(Map<String, dynamic> shift) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => ShiftFormPage(api: widget.api, shift: shift, endMode: true)),
    );
    if (result != null) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final active = activeShift;
    final today = shifts.where((shift) => isToday(DateTime.parse(shift['started_at'] as String))).toList();
    final grossToday = sumField(today, 'gross_earnings');
    final weekGross = sumField(shifts, 'gross_earnings');
    final weekMiles = sumField(shifts, 'miles');

    return Scaffold(
      appBar: AppBar(title: const Text('GigOS'), actions: [IconButton(onPressed: load, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            FilledButton.icon(
              onPressed: active == null ? startShift : () => endShift(active),
              icon: Icon(active == null ? Icons.play_arrow : Icons.stop),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                backgroundColor: active == null ? const Color(0xff32d583) : const Color(0xfff97066),
                foregroundColor: const Color(0xff101418),
              ),
              label: Text(active == null ? 'Start Shift' : 'End Shift', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: 16),
            if (active != null) ActiveShiftCard(api: widget.api, shift: active, onChanged: widget.onChanged),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                MetricCard(label: 'Today', value: money(grossToday), icon: Icons.today),
                MetricCard(label: 'This Week', value: money(weekGross), icon: Icons.calendar_month),
                MetricCard(label: 'Net Hourly', value: active == null ? '\$0.00' : money(active['metrics']['net_hourly']), icon: Icons.payments_outlined),
                MetricCard(label: 'Miles', value: weekMiles.toStringAsFixed(1), icon: Icons.route_outlined),
                MetricCard(label: 'Break Status', value: active == null ? 'Ready' : active['break_status']['level'], icon: Icons.coffee_outlined),
              ],
            ),
            const SizedBox(height: 18),
            Text('Recent Shifts', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            ...shifts.take(10).map((shift) => ShiftTile(api: widget.api, shift: shift as Map<String, dynamic>, onChanged: widget.onChanged)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftFormPage(api: widget.api)));
          if (result != null) widget.onChanged();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class ActiveShiftCard extends StatelessWidget {
  const ActiveShiftCard({super.key, required this.api, required this.shift, required this.onChanged});
  final ApiClient api;
  final Map<String, dynamic> shift;
  final VoidCallback onChanged;

  Future<void> startBreak() async {
    await api.request('POST', '/shifts/${shift['id']}/breaks/start', body: {'break_type': 'rest'});
    onChanged();
  }

  Future<void> endBreak(int id) async {
    await api.request('PATCH', '/breaks/$id/end', body: {});
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final breaks = shift['breaks'] as List<dynamic>;
    final activeBreak = breaks.cast<Map<String, dynamic>?>().firstWhere((item) => item?['ended_at'] == null, orElse: () => null);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active Shift', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('${shift['platform']} · ${shift['metrics']['total_minutes']} minutes online'),
            const SizedBox(height: 10),
            Text(shift['break_status']['message'], style: const TextStyle(color: Color(0xfffdb022))),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: activeBreak == null ? startBreak : () => endBreak(activeBreak['id'] as int),
              icon: Icon(activeBreak == null ? Icons.free_breakfast_outlined : Icons.timer_off_outlined),
              label: Text(activeBreak == null ? 'Log Break Start' : 'End Active Break'),
            ),
          ],
        ),
      ),
    );
  }
}

class ShiftFormPage extends StatefulWidget {
  const ShiftFormPage({super.key, required this.api, this.shift, this.endMode = false});
  final ApiClient api;
  final Map<String, dynamic>? shift;
  final bool endMode;

  @override
  State<ShiftFormPage> createState() => _ShiftFormPageState();
}

class _ShiftFormPageState extends State<ShiftFormPage> {
  final platforms = ['Uber Eats', 'DoorDash', 'Grubhub', 'Instacart', 'Amazon Flex', 'Other'];
  late String platform;
  late final TextEditingController gross;
  late final TextEditingController tips;
  late final TextEditingController trips;
  late final TextEditingController miles;
  late final TextEditingController gas;
  late final TextEditingController other;
  late final TextEditingController active;
  late final TextEditingController notes;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    platform = widget.shift?['platform']?.toString() ?? 'Uber Eats';
    gross = controller('gross_earnings');
    tips = controller('tips');
    trips = controller('trips');
    miles = controller('miles');
    gas = controller('gas_cost');
    other = controller('other_expenses');
    active = controller('active_minutes');
    notes = TextEditingController(text: widget.shift?['notes']?.toString() ?? '');
  }

  TextEditingController controller(String field) => TextEditingController(text: widget.shift?[field]?.toString() ?? '0');

  @override
  void dispose() {
    gross.dispose();
    tips.dispose();
    trips.dispose();
    miles.dispose();
    gas.dispose();
    other.dispose();
    active.dispose();
    notes.dispose();
    super.dispose();
  }

  Future<void> save() async {
    setState(() => busy = true);
    final body = {
      'platform': platform,
      'gross_earnings': parse(gross.text),
      'tips': parse(tips.text),
      'trips': int.tryParse(trips.text) ?? 0,
      'miles': parse(miles.text),
      'gas_cost': parse(gas.text),
      'other_expenses': parse(other.text),
      'active_minutes': int.tryParse(active.text) ?? 0,
      'notes': notes.text,
    };
    if (widget.shift == null) {
      body['started_at'] = DateTime.now().subtract(const Duration(hours: 1)).toUtc().toIso8601String();
      body['ended_at'] = DateTime.now().toUtc().toIso8601String();
      await widget.api.request('POST', '/shifts', body: body);
    } else {
      final path = widget.endMode ? '/shifts/${widget.shift!['id']}/end' : '/shifts/${widget.shift!['id']}';
      await widget.api.request('PATCH', path, body: body);
    }
    if (mounted) Navigator.of(context).pop(body);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.endMode ? 'End Shift' : widget.shift == null ? 'Add Shift' : 'Edit Shift')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: platform,
            items: platforms.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: (value) => setState(() => platform = value ?? platform),
            decoration: const InputDecoration(labelText: 'Platform'),
          ),
          Field(controller: gross, label: 'Gross earnings', icon: Icons.attach_money),
          Field(controller: tips, label: 'Tips', icon: Icons.volunteer_activism_outlined),
          Field(controller: trips, label: 'Trips completed', icon: Icons.local_shipping_outlined),
          Field(controller: miles, label: 'Miles driven', icon: Icons.route_outlined),
          Field(controller: gas, label: 'Gas cost', icon: Icons.local_gas_station_outlined),
          Field(controller: other, label: 'Other expenses', icon: Icons.receipt_long_outlined),
          Field(controller: active, label: 'Active minutes', icon: Icons.timer_outlined),
          const SizedBox(height: 12),
          TextField(controller: notes, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
          const SizedBox(height: 18),
          FilledButton(onPressed: busy ? null : save, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)), child: Text(busy ? 'Saving...' : 'Save')),
        ],
      ),
    );
  }
}

class WeeklyPage extends StatefulWidget {
  const WeeklyPage({super.key, required this.api, required this.refreshTick});
  final ApiClient api;
  final int refreshTick;

  @override
  State<WeeklyPage> createState() => _WeeklyPageState();
}

class _WeeklyPageState extends State<WeeklyPage> {
  Map<String, dynamic>? report;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    report = await widget.api.request('GET', '/reports/weekly') as Map<String, dynamic>;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final data = report;
    return Scaffold(
      appBar: AppBar(title: const Text('Weekly Reports')),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    MetricCard(label: 'Gross', value: money(data['gross_earnings']), icon: Icons.trending_up),
                    MetricCard(label: 'Net Hourly', value: money(data['net_hourly']), icon: Icons.payments_outlined),
                    MetricCard(label: 'Miles', value: parse(data['miles']).toStringAsFixed(1), icon: Icons.route_outlined),
                    MetricCard(label: 'Tax Set Aside', value: money(data['tax_set_aside']), icon: Icons.account_balance_outlined),
                  ],
                ),
                const SizedBox(height: 16),
                ReportRow('Shifts', data['shifts'].toString()),
                ReportRow('Online hours', (data['online_minutes'] / 60).toStringAsFixed(1)),
                ReportRow('Active hours', (data['active_minutes'] / 60).toStringAsFixed(1)),
                ReportRow('Trips', data['trips'].toString()),
                ReportRow('Maintenance reserve', money(data['maintenance_reserve'])),
                ReportRow('Net profit', money(data['net_profit'])),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: () => downloadCsv(context),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Export CSV'),
                ),
              ],
            ),
    );
  }

  Future<void> downloadCsv(BuildContext context) async {
    final response = await http.get(Uri.parse('$apiBaseUrl/export/csv'), headers: widget.api.headers);
    if (response.statusCode >= 400) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV export failed')));
      }
      return;
    }
    final blob = html.Blob([response.body], 'text/csv');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = 'gigos-shifts.csv'
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key, required this.user, required this.onLogout});
  final Map<String, dynamic> user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(user['email'] as String),
              subtitle: const Text('Local GigOS account'),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Privacy first'),
              subtitle: Text('GigOS never stores delivery platform passwords and does not scrape or use third-party gig platform APIs.'),
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: onLogout, icon: const Icon(Icons.logout), label: const Text('Logout')),
        ],
      ),
    );
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('$disclaimer\n\nNo scraping. No third-party gig platform API usage. Never store platform passwords.', style: TextStyle(height: 1.45)),
          ),
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width >= 520 ? 160 : (MediaQuery.of(context).size.width - 44) / 2,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xff32d583)),
              const SizedBox(height: 12),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(color: Color(0xff98a2b3))),
            ],
          ),
        ),
      ),
    );
  }
}

class ShiftTile extends StatelessWidget {
  const ShiftTile({super.key, required this.api, required this.shift, required this.onChanged});
  final ApiClient api;
  final Map<String, dynamic> shift;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        title: Text('${shift['platform']} · ${money(shift['gross_earnings'])}'),
        subtitle: Text('${DateFormat.MMMd().add_jm().format(DateTime.parse(shift['started_at'] as String).toLocal())} · ${shift['metrics']['total_minutes']} min'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () async {
          final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ShiftFormPage(api: api, shift: shift)));
          if (result != null) onChanged();
        },
      ),
    );
  }
}

class Field extends StatelessWidget {
  const Field({super.key, required this.controller, required this.label, required this.icon});
  final TextEditingController controller;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      ),
    );
  }
}

class ReportRow extends StatelessWidget {
  const ReportRow(this.label, this.value, {super.key});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class PlatformPicker extends StatelessWidget {
  PlatformPicker({super.key});
  final platforms = ['Uber Eats', 'DoorDash', 'Grubhub', 'Instacart', 'Amazon Flex', 'Other'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(title: Text('Choose platform')),
          ...platforms.map((platform) => ListTile(title: Text(platform), onTap: () => Navigator.of(context).pop(platform))),
        ],
      ),
    );
  }
}

bool isToday(DateTime date) {
  final now = DateTime.now();
  final local = date.toLocal();
  return local.year == now.year && local.month == now.month && local.day == now.day;
}

double parse(dynamic value) => double.tryParse(value.toString()) ?? 0;

double sumField(List<dynamic> items, String field) => items.fold(0, (sum, item) => sum + parse(item[field]));

String money(dynamic value) => NumberFormat.simpleCurrency().format(parse(value));
