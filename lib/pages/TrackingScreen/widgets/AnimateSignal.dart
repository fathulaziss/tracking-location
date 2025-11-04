// import 'package:flutter/material.dart';
// import 'package:flutter_signal_strength/flutter_signal_strength.dart';
// import 'dart:async';
//
// class AnimatedSignalStrength extends StatefulWidget {
//   const AnimatedSignalStrength({super.key});
//
//   @override
//   State<AnimatedSignalStrength> createState() => _AnimatedSignalStrengthState();
// }
//
// class _AnimatedSignalStrengthState extends State<AnimatedSignalStrength> {
//   double _signalStrength = 0;
//   Timer? _timer;
//
//   @override
//   void initState() {
//     super.initState();
//     _startMonitoringSignal();
//   }
//
//   void _startMonitoringSignal() {
//     _timer = Timer.periodic(const Duration(seconds: 2), (_) async {
//       try {
//         final strength = await FlutterSignalStrength.getSignalStrength();
//         setState(() {
//           _signalStrength = strength.toDouble(); // usually 0–4
//         });
//       } catch (e) {
//         debugPrint('Error reading signal strength: $e');
//       }
//     });
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     int bars = _signalStrength.round().clamp(0, 4);
//
//     return Row(
//       mainAxisSize: MainAxisSize.min,
//       children: List.generate(4, (index) {
//         final isActive = index < bars;
//         return AnimatedContainer(
//           duration: const Duration(milliseconds: 400),
//           curve: Curves.easeInOut,
//           margin: const EdgeInsets.symmetric(horizontal: 1),
//           width: 4,
//           height: 6 + (index * 5).toDouble(),
//           decoration: BoxDecoration(
//             color: isActive ? Colors.green : Colors.grey.shade400,
//             borderRadius: BorderRadius.circular(2),
//           ),
//         );
//       }),
//     );
//   }
// }
