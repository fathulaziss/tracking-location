import 'package:flutter/material.dart';

class Textwidgets extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final double height;
  final double? letterSpacing;
  final TextAlign? textAlign;

  const Textwidgets(this.text,
      {super.key,
      this.fontSize = 16,
      this.fontWeight = FontWeight.w500,
      this.color = Colors.black,
      this.height = 1.2,
      this.letterSpacing,
      this.textAlign});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'Montserrat',
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      ),
    );
  }
}

class DropdownContainer extends StatefulWidget {
  // Add a callback function to notify the parent
  final Function(int minutes)? onChangedCallback;

  const DropdownContainer(
      {super.key, this.onChangedCallback}); // Update constructor

  @override
  State<DropdownContainer> createState() => _DropdownContainerState();
}

class _DropdownContainerState extends State<DropdownContainer> {
  final List<String> _timeIntervals = [
    '1 minute',
    '5 minutes',
    '10 minutes',
    '15 minutes'
  ];

  String _selectedInterval = '1 minute'; // Changed initial value to match list

  // Helper function to extract the integer minute value from the string
  int _getMinuteValue(String intervalText) {
    try {
      // Extracts the number from strings like "1 minute", "5 minutes", etc.
      return int.parse(intervalText.split(' ').first);
    } catch (e) {
      return 1; // Default to 1 minute if parsing fails
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (Container and Row unchanged)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Textwidgets("Every"),
          DropdownButton<String>(
            value: _selectedInterval,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.black),
            elevation: 16,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            underline: Container(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                // 1. Update the local state
                setState(() {
                  _selectedInterval = newValue;
                });

                // 2. Call the callback to notify the parent
                if (widget.onChangedCallback != null) {
                  final minutes = _getMinuteValue(newValue);
                  widget.onChangedCallback!(minutes);
                }
              }
            },
            items: _timeIntervals.map<DropdownMenuItem<String>>((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Textwidgets(value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
