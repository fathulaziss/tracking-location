import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tracking_location/helper/local_storage_helper.dart';
import 'package:tracking_location/widgets/TextWidgets.dart';

// Convert to StatefulWidget to manage and load data
class ListInformation extends StatefulWidget {
  final Function(int minutes)? onIntervalChanged;

  const ListInformation({super.key, this.onIntervalChanged});

  @override
  State<ListInformation> createState() => ListInformationState();
}

class ListInformationState extends State<ListInformation> {
  // 1. State variable to hold the fetched records
  List<Map<String, dynamic>> _trackingRecords = [];

  // 2. Load data when the widget is initialized
  @override
  void initState() {
    super.initState();
    loadTrackingRecords();
  }

  // 3. Async function to fetch data from LocalStorageHelper
  Future<void> loadTrackingRecords() async {
    final records = await LocalStorageHelper.getAllTrackingHistory();
    // Sort by attempted_at time in descending order (newest first)
    records.sort((a, b) {
      final aTime = DateTime.parse(a['attempted_at'] as String);
      final bTime = DateTime.parse(b['attempted_at'] as String);
      return bTime.compareTo(aTime);
    });

    if (mounted) {
      setState(() {
        _trackingRecords = records;
      });
    }
  }

  // Helper to get color/icon for status
  Widget _getStatusIndicator(String status) {
    Color color;
    IconData icon;
    String text;

    switch (status) {
      case 'sent':
        color = Colors.green;
        icon = Icons.check_circle_outline;
        text = 'Sent';
        break;
      case 'pending':
        color = Colors.orange;
        icon = Icons.warning_amber_rounded;
        text = 'Pending';
        break;
      default:
        color = Colors.grey;
        icon = Icons.help_outline;
        text = 'Unknown';
    }

    return Tooltip(
      message: 'Status: $text',
      child: Icon(icon, color: color, size: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    // You can call _loadTrackingRecords() here too if you need to refresh
    // when the sheet is opened, but be careful with performance.

    return DraggableScrollableSheet(
      initialChildSize: 0.35,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              // Drag handle and header (pinned)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const Textwidgets(
                        "Track Information",
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      const SizedBox(height: 12),
                      DropdownContainer(
                        onChangedCallback: widget.onIntervalChanged,
                      ),
                      const SizedBox(height: 20),
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Textwidgets(
                            "Time / Status",
                            fontWeight: FontWeight.w600,
                          ),
                          Textwidgets(
                            "Latitude, Longitude",
                            fontWeight: FontWeight.w600,
                          ),
                        ],
                      ),
                      const Divider(),
                    ],
                  ),
                ),
              ),

              // Scrollable list using fetched records
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = _trackingRecords[index];
                    final locationData = record['data'] as Map<String, dynamic>;
                    final latitude = locationData['latitude'];
                    final longitude = locationData['longitude'];
                    final status = record['status'] as String;
                    final attemptedAt = DateTime.parse(
                      record['attempted_at'] as String,
                    );
                    final formattedTime = DateFormat(
                      'HH:mm:ss',
                    ).format(attemptedAt.toLocal());

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Textwidgets(formattedTime),
                              const SizedBox(width: 8),
                              _getStatusIndicator(status),
                            ],
                          ),
                          Textwidgets(
                            "${latitude?.toStringAsFixed(6)}, ${longitude?.toStringAsFixed(6)}",
                            fontSize: 13,
                          ),
                        ],
                      ),
                    );
                  },
                  childCount:
                      _trackingRecords.length, // Use the actual list length
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
