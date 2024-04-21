import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:torn_pda/providers/chain_status_provider.dart';
import 'package:torn_pda/providers/webview_provider.dart';

class StatusColorCounter extends StatefulWidget {
  const StatusColorCounter({
    Key? key,
  }) : super(key: key);

  @override
  State<StatusColorCounter> createState() => StatusColorCounterState();
}

class StatusColorCounterState extends State<StatusColorCounter> {
  late ChainStatusProvider _chainStatusProvider;
  bool _providerInitialised = false;

  bool _newKnownTimestamp = false;
  int _newTimeStampCount = 0;

  String? _formattedUntil;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _chainStatusProvider = Provider.of<ChainStatusProvider>(context, listen: false);
    _updateFormattedUntil(_chainStatusProvider.statusColorUntil);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _chainStatusProvider = Provider.of<ChainStatusProvider>(context, listen: true);
    if (!_providerInitialised) {
      // Activate API queries from the ChainStatusProvider if they are not already active
      _chainStatusProvider.startStatusColorRequests();
      _providerInitialised = true;
    }

    bool showNew = false;
    String newText = "HOSP";
    if (_newKnownTimestamp && _newTimeStampCount < 6 && _newTimeStampCount.isEven) {
      showNew = true;
    }

    Color statusColor = Colors.red.shade700;
    switch (_chainStatusProvider.statusColorCurrent) {
      case PlayerStatusColor.jail:
        statusColor = Colors.brown.shade700;
        newText = "JAIL";
        break;
      case PlayerStatusColor.travel:
        statusColor = Colors.blue.shade700;
        newText = "TRVL";
        break;
      default:
        break;
    }

    return _formattedUntil == null
        ? Container()
        : SizedBox(
            width: 35,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Container(
                color: _formattedUntil == null ? Colors.transparent : statusColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1, horizontal: 2),
                  child: Text(
                    showNew ? newText : _formattedUntil ?? "",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          );
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      // Make sure that we are updating from the provider whenever the browser is open
      String currentSource = context.read<ChainStatusProvider>().statusUpdateSource;
      bool browserOnTop = context.read<WebViewProvider>().browserShowInForeground;
      if (browserOnTop && currentSource != "provider") {
        context.read<ChainStatusProvider>().statusUpdateSource = "provider";
      }

      // Creates a count so that we can blink the condition (e.g.: "HOSP") whenever it's encountered
      if (_newKnownTimestamp && _newTimeStampCount < 5) {
        _newTimeStampCount++;
      } else if (_newKnownTimestamp && _newTimeStampCount >= 5) {
        _newKnownTimestamp = false;
        _newTimeStampCount = 0;
      }

      // Updates the timer string in the widget
      _updateFormattedUntil(_chainStatusProvider.statusColorUntil);
    });
  }

  void _updateFormattedUntil(int colorUntil) {
    // Trigger new timestamp blinking letters
    if (colorUntil != _chainStatusProvider.lastWidgetKnownTimeStamp) {
      log("New timestamp for status color widget!");
      _newKnownTimestamp = true;
      _newTimeStampCount = 0;
      _chainStatusProvider.lastWidgetKnownTimeStamp = colorUntil;
    }

    final int currentTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final int untilSeconds = colorUntil - currentTime;

    // If time has finished, show "END" for one minute longer
    if (untilSeconds <= 0 && untilSeconds > -60) {
      setState(() {
        _formattedUntil = "END";
      });

      return;
    } else if (untilSeconds < -60) {
      _formattedUntil = null;

      // Ensure we are not just returning an empty widget, but also hiding the widget (to ensure proper padding
      // measurement) even if no API calls have been performed from the Provider since then
      // (e.g.: if the app was in the background)
      if (_chainStatusProvider.statusColorIsShown) {
        _chainStatusProvider.statusColorIsShown = false;
      }

      return;
    }

    final double days = untilSeconds / (24 * 3600);
    final double remainingHours = (untilSeconds % (24 * 3600)) / 3600;

    if (days >= 1) {
      final formattedDays = days.toStringAsFixed(1);
      final formattedDaysWithoutDecimal =
          formattedDays.endsWith('.0') ? formattedDays.substring(0, formattedDays.length - 2) : formattedDays;
      setState(() {
        _formattedUntil = "$formattedDaysWithoutDecimal d";
      });
    } else if (untilSeconds <= 5999) {
      // If less than 100 minutes remaining, show in mm:ss format
      final int minutes = untilSeconds ~/ 60;
      final int seconds = untilSeconds % 60;
      setState(() {
        _formattedUntil = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      });
    } else {
      final formattedHours = remainingHours.toStringAsFixed(1);
      final formattedHoursWithoutDecimal =
          formattedHours.endsWith('.0') ? formattedHours.substring(0, formattedHours.length - 2) : formattedHours;
      setState(() {
        _formattedUntil = "$formattedHoursWithoutDecimal h";
      });
    }
  }
}
