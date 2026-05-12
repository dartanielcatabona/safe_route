import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/route_history_service.dart';
import '../providers/auth_provider.dart';
import '../models/transit_route.dart';

class RouteHistoryScreen extends StatefulWidget {
  const RouteHistoryScreen({super.key});

  @override
  State<RouteHistoryScreen> createState() => _RouteHistoryScreenState();
}

class _RouteHistoryScreenState extends State<RouteHistoryScreen> {
  List<RouteHistoryEntry> _routeHistory = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRouteHistory();
  }

  Future<void> _loadRouteHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    try {
      final history = await RouteHistoryService.getUserHistory(userId);
      setState(() {
        _routeHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load route history: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _clearHistory() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text(
            'Are you sure you want to clear all route history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await RouteHistoryService.deleteAllUserHistory(userId);
        _loadRouteHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Route history cleared'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to clear history: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  List<RouteHistoryEntry> get _filteredHistory {
    if (_searchQuery.isEmpty) return _routeHistory;

    return _routeHistory.where((item) {
      final query = _searchQuery.toLowerCase();
      return item.startAddress.toLowerCase().contains(query) ||
          item.endAddress.toLowerCase().contains(query) ||
          (item.segments.isNotEmpty
              ? item.segments.first.mode.name.toLowerCase().contains(query)
              : false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route History'),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed:
                _isLoading || _routeHistory.isEmpty ? null : _clearHistory,
            tooltip: 'Clear History',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _routeHistory.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search route history...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        onChanged: (value) {
                          setState(() => _searchQuery = value);
                        },
                      ),
                    ),

                    // History List
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredHistory.length,
                        itemBuilder: (context, index) {
                          final item = _filteredHistory[index];
                          return _buildHistoryItem(item);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Route History',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your navigation history will appear here',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Navigate to map
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Start navigating to build history!')),
              );
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Start Navigating'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue[700],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(RouteHistoryEntry item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Icon(
            _getTransitIcon(item.segments.isNotEmpty
                ? item.segments.first.mode
                : TransitMode.p2pBus),
            color: Colors.blue[700],
          ),
        ),
        title: Text(
          '${item.startAddress} → ${item.endAddress}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildChip(
                    Icons.access_time, '${item.actualMinutes ?? 'N/A'} min'),
                const SizedBox(width: 8),
                _buildChip(Icons.attach_money,
                    '₱${item.actualFare?.toStringAsFixed(0) ?? 'N/A'}'),
                const SizedBox(width: 8),
                _buildChip(Icons.security,
                    '${item.safetyScore.toStringAsFixed(1)}/10'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(item.startedAt),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'reuse':
                Navigator.pop(context);
                // TODO: Navigate with this route
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reusing route...')),
                );
                break;
              case 'save':
                Navigator.pop(context);
                // TODO: Save this route
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Saving route...')),
                );
                break;
              case 'delete':
                _deleteHistoryItem(item.id);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'reuse',
              child: Row(
                children: [
                  Icon(Icons.navigation),
                  SizedBox(width: 8),
                  Text('Reuse Route'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'save',
              child: Row(
                children: [
                  Icon(Icons.bookmark),
                  SizedBox(width: 8),
                  Text('Save Route'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () {
          // TODO: Show route details
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Route details coming soon!')),
          );
        },
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getTransitIcon(TransitMode mode) {
    switch (mode) {
      case TransitMode.p2pBus:
      case TransitMode.carouselBus:
      case TransitMode.cityBus:
        return Icons.directions_bus;
      case TransitMode.mrt:
        return Icons.subway;
      case TransitMode.lrt:
        return Icons.tram;
      case TransitMode.jeepney:
        return Icons.local_taxi;
      case TransitMode.modernJeepney:
        return Icons.electric_rickshaw;
      case TransitMode.uvExpress:
        return Icons.airport_shuttle;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) return 'Yesterday';
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _deleteHistoryItem(String itemId) async {
    try {
      await RouteHistoryService.deleteHistoryEntry(itemId);
      _loadRouteHistory();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('History item deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete item: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
