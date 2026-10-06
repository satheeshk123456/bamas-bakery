import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../app_theme.dart';
import '../models/order.dart';
import '../services/order_service.dart';

/// Date-wise order lookup + CSV download for the shop's own records --
/// e.g. "everything from last month". Separate from the Pending/
/// Accepted/Completed tabs on the main Orders screen, which are for
/// day-to-day triage; this is for looking back and exporting.
class OrdersReportScreen extends StatefulWidget {
  const OrdersReportScreen({super.key});

  @override
  State<OrdersReportScreen> createState() => _OrdersReportScreenState();
}

class _OrdersReportScreenState extends State<OrdersReportScreen> {
  static final _apiFormat = DateFormat('yyyy-MM-dd');
  static final _displayFormat = DateFormat('MMM d, yyyy');

  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  String? _status; // null = all statuses
  List<Order>? _orders;
  bool _loading = false;
  bool _exporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runQuery();
  }

  void _setRange(int days) {
    setState(() {
      _to = DateTime.now();
      _from = _to.subtract(Duration(days: days));
    });
    _runQuery();
  }

  void _setThisMonth() {
    final now = DateTime.now();
    setState(() {
      _from = DateTime(now.year, now.month, 1);
      _to = now;
    });
    _runQuery();
  }

  void _setLastMonth() {
    final now = DateTime.now();
    final lastMonthEnd = DateTime(now.year, now.month, 1).subtract(const Duration(days: 1));
    setState(() {
      _from = DateTime(lastMonthEnd.year, lastMonthEnd.month, 1);
      _to = lastMonthEnd;
    });
    _runQuery();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
    _runQuery();
  }

  Future<void> _runQuery() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final orders = await orderService.listOrders(
        status: _status,
        fromDate: _apiFormat.format(_from),
        toDate: _apiFormat.format(_to),
        limit: 5000,
      );
      setState(() => _orders = orders);
    } catch (e) {
      setState(() => _error = 'Could not load orders: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download() async {
    setState(() => _exporting = true);
    try {
      final bytes = await orderService.exportCsv(
        status: _status,
        fromDate: _apiFormat.format(_from),
        toDate: _apiFormat.format(_to),
      );
      final dir = await getTemporaryDirectory();
      final fileName = 'orders_${_apiFormat.format(_from)}_to_${_apiFormat.format(_to)}.csv';
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: 'Order export ($fileName)'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not export: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  double get _total => (_orders ?? []).fold(0, (sum, o) => sum + o.totalAmount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order Reports')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActionChip(label: const Text('Last 7 days'), onPressed: () => _setRange(7)),
                      ActionChip(label: const Text('Last 30 days'), onPressed: () => _setRange(30)),
                      ActionChip(label: const Text('This month'), onPressed: _setThisMonth),
                      ActionChip(label: const Text('Last month'), onPressed: _setLastMonth),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isFrom: true),
                          child: Text('From ${_displayFormat.format(_from)}'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _pickDate(isFrom: false),
                          child: Text('To ${_displayFormat.format(_to)}'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    value: _status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All statuses')),
                      DropdownMenuItem(value: 'pending', child: Text('Pending')),
                      DropdownMenuItem(value: 'accepted', child: Text('Accepted')),
                      DropdownMenuItem(value: 'completed', child: Text('Completed')),
                      DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                    ],
                    onChanged: (v) {
                      setState(() => _status = v);
                      _runQuery();
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 24),
            if (_loading) const Expanded(child: Center(child: CircularProgressIndicator())),
            if (!_loading && _error != null)
              Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))),
            if (!_loading && _error == null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_orders?.length ?? 0} order(s) • ₹${_total.toStringAsFixed(0)} total',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: (_exporting || (_orders?.isEmpty ?? true)) ? null : _download,
                      icon: _exporting
                          ? const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.file_download_outlined, size: 18),
                      label: const Text('Download CSV'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: (_orders?.isEmpty ?? true)
                    ? const Center(child: Text('No orders in this range.', style: TextStyle(color: AppBranding.textMuted)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: _orders!.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final o = _orders![i];
                          final when = o.createdAt != null ? DateTime.tryParse(o.createdAt!)?.toLocal() : null;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(o.customerName, overflow: TextOverflow.ellipsis),
                            subtitle: Text(
                              '${o.itemCount} item(s) • ₹${o.totalAmount.toStringAsFixed(0)} • ${o.status}'
                              '${when != null ? ' • ${DateFormat('MMM d, h:mm a').format(when)}' : ''}',
                            ),
                          );
                        },
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
