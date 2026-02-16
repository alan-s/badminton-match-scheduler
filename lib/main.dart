import 'dart:async';
import 'dart:math';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
// import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  //   debugPaintSizeEnabled = true;
  //   debugPaintSizeEnabled = true;
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      title: "Badminton Match Scheduler",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(),
        scaffoldBackgroundColor: const Color(0xFF37BCFF),
        cardTheme: const CardThemeData(
          elevation: 2,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            backgroundColor: const Color(0xFF0F57FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        dividerTheme: const DividerThemeData(
          color: Colors.white, // your global divider colour
          thickness: 2, // optional: default thickness
          space: 20, // optional: default vertical spacing
        ),
      ),
      home: const Scheduler(),
    ),
  );
}

class Player {
  String id;
  String name;
  final Color color;
  int matchesPlayed = 0;
  DateTime? lastPlayed;

  Player(this.id, this.name, this.color);
}

class Scheduler extends StatefulWidget {
  const Scheduler({super.key});

  @override
  State<Scheduler> createState() => _SchedulerState();
}

class _SchedulerState extends State<Scheduler> {
  final Random _random = Random();

  final List<Player> allPlayers = [];
  final List<Player> waitingPlayers = [];
  final Map<int, List<Player>> courts = {1: [], 2: []};

  int? selectedCourt;
  Player? selectedWaitingPlayer;
  Player? lastAddedPlayer;
  bool showCsvPanel = false;

  final Set<String> usedIds = {};
  final TextEditingController populateController = TextEditingController();

  bool sortByName = false;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        setState(() {});
        web.document.title = "Badminton Match Scheduler";
      }
    });
  }

  // ================= RANDOM POPULATE =================

  void defaultPopulate() {
    setState(() {
      final totalCourts = courts.length;
      final playersNeeded = totalCourts * 4;

      for (int i = 0; i < playersNeeded; i++) {
        final p = generateRandomPlayer();
        p.lastPlayed = DateTime.now();
        waitingPlayers.add(p);
        allPlayers.add(p);
      }
    });
    lastAddedPlayer = allPlayers.isNotEmpty ? allPlayers.last : null;
  }

  Player generateRandomPlayer() {
    String id;
    do {
      id =
          "${String.fromCharCode(65 + _random.nextInt(26))}${_random.nextInt(10)}";
    } while (usedIds.contains(id));
    usedIds.add(id);

    return Player(
      id,
      "$id",
      Colors.primaries[_random.nextInt(Colors.primaries.length)],
    );
  }

  Future<void> confirmRandomPlayers() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Random Players"),
        content: const Text(
          "This will add a new batch of random players to the current session.\n\nContinue?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add Players"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      defaultPopulate();
    }
  }

  void assignNextFour() {
    if (waitingPlayers.length < 4) {
      showMessage("Not enough players in the waiting list.");
      return;
    }

    int? emptyCourt;
    courts.forEach((courtNumber, players) {
      if (emptyCourt == null && players.isEmpty) {
        emptyCourt = courtNumber;
      }
    });

    if (emptyCourt == null) {
      showMessage("No empty court available.");
      return;
    }

    setState(() {
      final courtPlayers = courts[emptyCourt]!;

      final sorted = getSortedWaitingPlayers();
      final nextFour = sorted.take(4).toList();

      for (var p in nextFour) {
        waitingPlayers.remove(p);
      }

      courtPlayers.addAll(nextFour);

      selectedCourt = emptyCourt;
    });
  }

  // ================= RESET / REMOVE =================

  Future<void> resetAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Reset"),
        content: const Text("This will reset everything. Are you sure?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      waitingPlayers.clear();
      allPlayers.clear();
      courts.forEach((k, v) => v.clear());
      usedIds.clear();
      selectedCourt = null;
      selectedWaitingPlayer = null;
      lastAddedPlayer = null;
      populateController.clear();
    });
  }

  Future<void> removeSelectedPlayer() async {
    if (selectedWaitingPlayer == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Player"),
        content: Text(
          "Are you sure you want to remove ${selectedWaitingPlayer!.name} (${selectedWaitingPlayer!.id})?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("No"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      waitingPlayers.remove(selectedWaitingPlayer);
      allPlayers.remove(selectedWaitingPlayer);
      lastAddedPlayer = allPlayers.isNotEmpty ? allPlayers.last : null;
      selectedWaitingPlayer = null;
    });
  }

  // ================= SORTING / HELPERS =================

  int comparePlayers(Player a, Player b) {
    if (sortByName) {
      final nameDiff = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (nameDiff != 0) return nameDiff;
      return a.id.compareTo(b.id);
    }

    final matchDiff = a.matchesPlayed.compareTo(b.matchesPlayed);
    if (matchDiff != 0) return matchDiff;

    final aTime = a.lastPlayed;
    final bTime = b.lastPlayed;

    if (aTime == null && bTime == null) {
      return a.id.compareTo(b.id);
    }
    if (aTime == null) return -1;
    if (bTime == null) return 1;

    final timeDiff = aTime.compareTo(bTime);
    if (timeDiff != 0) return timeDiff;

    return a.id.compareTo(b.id);
  }

  int comparePlayersForStats(Player a, Player b) {
    final matchDiff = a.matchesPlayed.compareTo(b.matchesPlayed);
    if (matchDiff != 0) return matchDiff;

    final aTime = a.lastPlayed;
    final bTime = b.lastPlayed;

    if (aTime == null && bTime == null) return a.id.compareTo(b.id);
    if (aTime == null) return -1;
    if (bTime == null) return 1;

    final timeDiff = aTime.compareTo(bTime);
    if (timeDiff != 0) return timeDiff;

    return a.id.compareTo(b.id);
  }

  Color statsColorForGames(int games) {
    if (games == 0) return Color(0xFF7F1D1D);

    const palette = [
      Color(0xFF0D1B2A),
      Color(0xFF1F2933),
      Color(0xFF3B0764),
      Color(0xFF5B21B6),
      Color(0xFFBE185D),
      Color(0xFFB91C1C),
      Color(0xFFC2410C),
      Color(0xFF92400E),
      Color(0xFF065F46),
      Color(0xFF000000),
    ];

    final index = (games - 1) % palette.length;
    return palette[index];
  }

  List<Player> getSortedWaitingPlayers() {
    final sorted = [...waitingPlayers];
    sorted.sort(comparePlayers);
    return sorted;
  }

  List<Player> getAllPlayersForStats() {
    final allPlayers = [...waitingPlayers, ...courts.values.expand((e) => e)];
    allPlayers.sort(comparePlayersForStats);
    return allPlayers;
  }

  String formatTime(DateTime? t) {
    if (t == null) return "-";
    final now = DateTime.now();
    final diff = now.difference(t).inMinutes;
    return "$diff min";
  }

  void addCourt() {
    if (courts.length >= 4) {
      showMessage("Maximum of 4 courts allowed.");
      return;
    }

    setState(() {
      final newCourtNumber = courts.length + 1;
      courts[newCourtNumber] = [];
    });
  }

  Future<void> removeCourt() async {
    if (selectedCourt == null) return;

    final courtNumber = selectedCourt!;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Court"),
        content: Text(
          "Remove Court $courtNumber?\n\n"
          "Any players currently on this court will be returned to the waiting list WIHTOUT updating stats!",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Remove"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      waitingPlayers.addAll(courts[courtNumber]!);

      courts.remove(courtNumber);

      final newCourts = <int, List<Player>>{};
      int index = 1;
      for (var entry in courts.entries) {
        newCourts[index] = entry.value;
        index++;
      }
      courts
        ..clear()
        ..addAll(newCourts);

      selectedCourt = null;
    });
  }

  void completeMatch(int courtNumber) {
    setState(() {
      for (var p in courts[courtNumber]!) {
        p.matchesPlayed++;
        p.lastPlayed = DateTime.now();
      }

      waitingPlayers.addAll(courts[courtNumber]!);
      courts[courtNumber]!.clear();

      selectedCourt = null;
    });
  }

  // ================= VALIDATION / POPULATE =================

  String? validatePlayers(String text) {
    final entries = text.split(",");
    final ids = <String>{};

    for (var entry in entries) {
      entry = entry.trim();
      if (!entry.contains(":")) {
        return "Player list is invalid. Check format and try again!";
      }

      final parts = entry.split(":");
      if (parts.length != 2) {
        return "Player list is invalid. Check format and try again!";
      }

      final id = parts[0].trim();
      final name = parts[1].trim();

      if (id.isEmpty || id.length > 2 || name.isEmpty || name.length > 12) {
        return "Player list is invalid. Check format and try again!";
      }

      if (ids.contains(id) || usedIds.contains(id)) {
        return "Player ID '$id' already exists. Fix and try again.";
      }
      ids.add(id);
    }
    return null;
  }

  void populatePlayers() {
    final error = validatePlayers(populateController.text);
    if (error != null) {
      showMessage(error);
      return;
    }

    setState(() {
      final entries = populateController.text.split(",");

      for (var entry in entries) {
        final parts = entry.trim().split(":");
        final id = parts[0].trim().toUpperCase();
        final name = parts[1].trim();

        final newPlayer = Player(
          id,
          name,
          Colors.primaries[_random.nextInt(Colors.primaries.length)],
        );

        newPlayer.lastPlayed = DateTime.now();

        usedIds.add(id);
        waitingPlayers.add(newPlayer);
        allPlayers.add(newPlayer);
      }

      populateController.clear();
    });
    lastAddedPlayer = allPlayers.isNotEmpty ? allPlayers.last : null;
  }

  void showMessage(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        content: Text(msg),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final sortedWaitingPlayers = getSortedWaitingPlayers();
    final statsPlayers = getAllPlayersForStats();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          "Badminton Match Scheduler",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          // SAME LAYOUT FOR BOTH MOBILE AND DESKTOP
          return SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Column(
              children: [
                _buildMainContent(sortedWaitingPlayers, isMobile: isMobile),

                const SizedBox(height: 20),

                // Stats panel always at the bottom
                Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: StatsPanel(
                    players: statsPlayers,
                    formatTime: formatTime,
                    colorForGames: statsColorForGames,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCsvPanel() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: populateController,
            minLines: 1,
            maxLines: null,
            decoration: InputDecoration(
              hintText: "Paste CSV List - e.g. NB:Natalie,BK:Bob,...",
              hintStyle: const TextStyle(color: Colors.white70, fontSize: 14),

              // 🔥 Custom borders
              enabledBorder: OutlineInputBorder(
                borderSide: const BorderSide(color: Colors.white54, width: 1),
                //borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: const BorderSide(
                  color: const Color(0xFF0F57FF),
                  width: 1,
                ),
              ),
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            onChanged: (_) => setState(() {}),
          ),

          const SizedBox(height: 12),

          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              FilledButton.tonal(
                onPressed: populateController.text.trim().isEmpty
                    ? null
                    : populatePlayers,
                child: const Text("Add From List"),
              ),
              FilledButton.tonal(
                onPressed: confirmRandomPlayers,
                child: const Text("Add Random Players"),
              ),

              const SizedBox(width: double.infinity),

              FilledButton.tonal(
                onPressed: addCourt,
                child: const Text("Add Court"),
              ),
              FilledButton.tonal(
                onPressed: removeCourt,
                child: const Text("Remove Court"),
              ),
              FilledButton.tonal(
                onPressed: resetAll,
                child: const Text("Reset All"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
    List<Player> sortedWaitingPlayers, {
    required bool isMobile,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        children: [
          const SizedBox(height: 10),

          // Courts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: courts.keys
                  .map(
                    (courtNumber) => Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "Court $courtNumber",
                          style: const TextStyle(
                            fontSize: 12,
                            //fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),

                        //const SizedBox(height: 4), // small gap above the card
                        CourtCard(
                          courtNumber: courtNumber,
                          players: courts[courtNumber]!,
                          isSelected: selectedCourt == courtNumber,
                          onTap: () {
                            setState(() {
                              selectedCourt = selectedCourt == courtNumber
                                  ? null
                                  : courtNumber;
                              selectedWaitingPlayer = null;
                            });
                          },
                          onComplete: courts[courtNumber]!.length == 4
                              ? () => completeMatch(courtNumber)
                              : null,
                          onPlayerTap: (player) {
                            setState(() {
                              courts[courtNumber]!.remove(player);
                              waitingPlayers.add(player);
                            });
                          },
                        ),

                        FilledButton.tonal(
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            minimumSize: const Size(
                              0,
                              32,
                            ), // prevents Flutter from forcing a wide button
                          ),
                          onPressed: courts[courtNumber]!.length == 4
                              ? () => completeMatch(courtNumber)
                              : null,
                          child: const Text("Completed"),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),

          Divider(),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              "To assign a game, select a court above and then tap four waiting players "
              "${sortByName ? "(leftmost = name sorted)" : "(leftmost = fewest games played)"}",
              style: const TextStyle(color: Color(0xFFF4F8FB)),
              softWrap: true,
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 10),

          // Waiting players
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: sortedWaitingPlayers
                .map(
                  (player) => SelectablePlayerCircle(
                    player: player,
                    isSelected: selectedWaitingPlayer == player,
                    isLastAdded: lastAddedPlayer == player,
                    onTap: () {
                      setState(() {
                        if (selectedCourt != null) {
                          final courtPlayers = courts[selectedCourt]!;
                          if (courtPlayers.length < 4) {
                            courtPlayers.add(player);
                            waitingPlayers.remove(player);

                            if (courtPlayers.length == 4) {
                              selectedCourt = null;
                            }
                          }
                        } else {
                          selectedWaitingPlayer =
                              selectedWaitingPlayer == player ? null : player;
                        }
                      });
                    },
                  ),
                )
                .toList(),
          ),

          const SizedBox(height: 12),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12, // horizontal space between buttons
            runSpacing: 12, // vertical space between lines
            children: [
              FilledButton.tonal(
                onPressed: assignNextFour,
                child: const Text("Assign Next Four"),
              ),

              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    sortByName = !sortByName;
                  });
                },
                child: Text(
                  sortByName ? "Sort by Games Played" : "Sort by Name",
                ),
              ),

              FilledButton.tonal(
                onPressed: selectedWaitingPlayer == null
                    ? null
                    : removeSelectedPlayer,
                child: const Text("Remove Player"),
              ),
            ],
          ),

          Divider(),

          GestureDetector(
            onTap: () {
              setState(() {
                showCsvPanel = !showCsvPanel;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                showCsvPanel ? "Hide Configuration ▲" : "Show Configuration ▼",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),

          ClipRect(
            child: AnimatedCrossFade(
              firstChild: _buildCsvPanel(),
              secondChild: const SizedBox.shrink(),
              crossFadeState: showCsvPanel
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              sizeCurve: Curves.easeInOut,
            ),
          ),

          Divider(),
        ],
      ),
    );
  }
}

// ================= REUSABLE WIDGETS =================

class PlayerAvatarCircle extends StatelessWidget {
  final Player? player;
  final double size;
  final double borderWidth;
  final Color borderColor;

  const PlayerAvatarCircle({
    super.key,
    required this.player,
    this.size = 44,
    this.borderWidth = 1,
    this.borderColor = const Color(0xFF37BCFF),
  });

  @override
  Widget build(BuildContext context) {
    final bool highlight =
        borderColor == Colors.red || borderColor == Colors.green;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          if (highlight)
            BoxShadow(
              color: borderColor.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
        ],
      ),
      child: player == null
          ? const SizedBox.shrink()
          : CircleAvatar(
              backgroundColor: player!.color,
              child: Text(
                player!.id,
                style: const TextStyle(
                  //fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }
}

class PlayerAvatarRect extends StatelessWidget {
  final Player player;
  final double width;
  final double height;
  final double borderWidth;
  final Color borderColor;

  const PlayerAvatarRect({
    super.key,
    required this.player,
    this.width = 60,
    this.height = 36,
    this.borderWidth = 1,
    this.borderColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: player.color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Center(
        child: Text(
          player.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            //fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class SelectablePlayerCircle extends StatelessWidget {
  final Player player;
  final bool isSelected;
  final bool isLastAdded;
  final VoidCallback onTap;

  const SelectablePlayerCircle({
    super.key,
    required this.player,
    required this.isSelected,
    required this.isLastAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 700;

    Color borderColor = isSelected
        ? Colors.red
        : isLastAdded
        ? Colors.green
        : Colors.white;
    double borderWidth = isSelected
        ? 2
        : isLastAdded
        ? 3
        : 1;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onTap,
      child: AnimatedScale(
        scale: isSelected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(2),
          child: PlayerAvatarRect(
            player: player,
            borderColor: borderColor,
            borderWidth: borderWidth,
            width: isMobile ? 55 : 65,
            height: isMobile ? 32 : 38,
          ),
        ),
      ),
    );
  }
}

class _CourtLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1;

    const double pad = 6;

    final double w = size.width - pad * 2;
    final double h = size.height - pad * 2;

    final double left = pad;
    final double top = pad;

    // Vertical lines at 12.5%
    final double v1 = left + w * 0.125;
    final double v2 = left + w * 0.875;

    canvas.drawLine(Offset(v1, top), Offset(v1, top + h), paint);
    canvas.drawLine(Offset(v2, top), Offset(v2, top + h), paint);

    // Horizontal lines at 5.5%
    final double h1 = top + h * 0.055;
    final double h2 = top + h * 0.945;

    canvas.drawLine(Offset(left, h1), Offset(left + w, h1), paint);
    canvas.drawLine(Offset(left, h2), Offset(left + w, h2), paint);

    // NEW: Horizontal lines at 35% from top and bottom
    final double h35Top = top + h * 0.35;
    final double h35Bottom = top + h * 0.65;

    canvas.drawLine(Offset(left, h35Top), Offset(left + w, h35Top), paint);
    canvas.drawLine(
      Offset(left, h35Bottom),
      Offset(left + w, h35Bottom),
      paint,
    );

    // Dashed horizontal center line
    final double midY = top + h * 0.5;
    const double dashWidth = 6;
    const double dashGap = 4;

    double startX = left;
    while (startX < left + w) {
      final double endX = (startX + dashWidth).clamp(left, left + w);
      canvas.drawLine(Offset(startX, midY), Offset(endX, midY), paint);
      startX += dashWidth + dashGap;
    }

    // Center vertical partial lines
    final double midX = left + w * 0.5;

    // From bottom 5.5% line up to bottom 35% line
    canvas.drawLine(Offset(midX, h2), Offset(midX, h35Bottom), paint);

    // From top 5.5% line down to top 35% line
    canvas.drawLine(Offset(midX, h1), Offset(midX, h35Top), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CourtCard extends StatelessWidget {
  final int courtNumber;
  final List<Player> players;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onComplete;
  final void Function(Player)? onPlayerTap;

  const CourtCard({
    super.key,
    required this.courtNumber,
    required this.players,
    required this.isSelected,
    required this.onTap,
    required this.onComplete,
    this.onPlayerTap,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;

    final double width = isMobile ? 150 * 0.7 : 150;
    final double height = isMobile ? 230 * 0.7 : 230;
    final double avatarSize = isMobile ? 32 : 44;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          children: [
            // ------------------------------------------------------------
            // 1. Background card (bottom layer)
            // ------------------------------------------------------------
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              margin: const EdgeInsets.all(6),
              padding: const EdgeInsets.all(10), // ← RESTORED padding
              decoration: BoxDecoration(
                color: const Color(0xFF1773B4),
                borderRadius: BorderRadius.zero,
                border: Border.all(
                  width: isSelected ? 2 : 1,
                  color: isSelected ? const Color(0xFF1E39D4) : Colors.white,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF0d2AD1).withValues(alpha: 0.6),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  SizedBox(height: isMobile ? 10 * 0.5 : 10),
                  SizedBox(
                    height: isMobile ? 100 : 180,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildColumn(0, 2, avatarSize, isMobile),
                        _buildColumn(1, 3, avatarSize, isMobile),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ------------------------------------------------------------
            // 2. Court lines painter (middle layer)
            // ------------------------------------------------------------
            IgnorePointer(
              child: CustomPaint(
                painter: _CourtLinesPainter(),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Player column builder
  // ------------------------------------------------------------
  Widget _buildColumn(int a, int b, double avatarSize, bool isMobile) {
    return Column(
      children: [
        _buildSlot(a, avatarSize),
        SizedBox(height: isMobile ? 90 * 0.7 : 90),
        _buildSlot(b, avatarSize),
      ],
    );
  }

  // ------------------------------------------------------------
  // Player slot builder
  // ------------------------------------------------------------
  Widget _buildSlot(int index, double avatarSize) {
    final hasPlayer = players.length > index;
    final player = hasPlayer ? players[index] : null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: hasPlayer && onPlayerTap != null
          ? () => onPlayerTap!(player!)
          : null,
      child: PlayerAvatarCircle(player: player, size: avatarSize),
    );
  }
}

class StatsPanel extends StatelessWidget {
  final List<Player> players;
  final String Function(DateTime?) formatTime;
  final Color Function(int) colorForGames;

  const StatsPanel({
    super.key,
    required this.players,
    required this.formatTime,
    required this.colorForGames,
  });

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 700;
    final double fontSize = isMobile ? 12 : 14;

    final headerStyle = TextStyle(
      //fontWeight: FontWeight.bold,
      color: Colors.white, // ← your chosen color
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF37BCFF),
        //borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 6),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    "Player",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Text(
                    "Last Played",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.left,
                    style: headerStyle,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    "Played",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: headerStyle,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: players.length,
            itemBuilder: (context, index) {
              final p = players[index];
              final rowColor = colorForGames(p.matchesPlayed);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        "${p.id} - ${p.name}",
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: rowColor,
                          fontSize: fontSize,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        formatTime(p.lastPlayed),
                        textAlign: TextAlign.left,
                        style: TextStyle(color: rowColor, fontSize: fontSize),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        p.matchesPlayed.toString(),
                        textAlign: TextAlign.right,
                        style: TextStyle(color: rowColor, fontSize: fontSize),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
