import 'package:flutter/material.dart';

class StatusTimeline extends StatelessWidget {
  final List<StatusTimelineItem> items;
  
  const StatusTimeline({
    Key? key,
    required this.items,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(items.length * 2 - 1, (index) {
        // Even indices are timeline items
        if (index % 2 == 0) {
          final itemIndex = index ~/ 2;
          return _buildTimelineItem(items[itemIndex], itemIndex < items.length - 1);
        } else {
          // Odd indices are connectors between items
          final itemIndex = index ~/ 2;
          return _buildConnector(
            items[itemIndex].isCompleted,
            items[itemIndex].statusColor,
          );
        }
      }),
    );
  }
  
  Widget _buildTimelineItem(StatusTimelineItem item, bool hasNextItem) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDot(item.isCompleted, item.statusColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: item.isCompleted ? Colors.black : Colors.grey[600],
                ),
              ),
              if (item.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    item.subtitle!,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                ),
              if (item.content != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: item.content!,
                ),
              SizedBox(height: hasNextItem ? 8 : 0),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDot(bool isCompleted, Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isCompleted ? color : Colors.grey[300],
        border: Border.all(
          color: isCompleted ? color : Colors.grey[400]!,
          width: 2,
        ),
      ),
      child: isCompleted
          ? const Icon(Icons.check, color: Colors.white, size: 16)
          : null,
    );
  }
  
  Widget _buildConnector(bool isCompleted, Color color) {
    return Row(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 11),
          child: Container(
            width: 2,
            height: 30,
            color: isCompleted ? color : Colors.grey[300],
          ),
        ),
        const Expanded(child: SizedBox()),
      ],
    );
  }
}

class StatusTimelineItem {
  final String title;
  final String? subtitle;
  final Widget? content;
  final bool isCompleted;
  final Color statusColor;
  
  StatusTimelineItem({
    required this.title,
    this.subtitle,
    this.content,
    required this.isCompleted,
    required this.statusColor,
  });
}