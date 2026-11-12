import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/firestore_models.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../widgets/nays_widgets.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({required this.service, super.key});

  final FirestoreCbtService service;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _subjectId = 'overall';

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Leaderboard')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
          child: StreamBuilder<List<NaysSubject>>(
            stream: widget.service.watchActiveSubjects(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('Could not load subjects: ${snapshot.error}');
              }
              final subjects = snapshot.data ?? const <NaysSubject>[];
              return DropdownButtonFormField<String>(
                initialValue: _subjectId,
                decoration: const InputDecoration(labelText: 'Rankings'),
                items: [
                  const DropdownMenuItem(
                    value: 'overall',
                    child: Text('Overall'),
                  ),
                  ...subjects.map(
                    (subject) => DropdownMenuItem(
                      value: subject.subjectId,
                      child: Text(subject.subjectName),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _subjectId = value);
                },
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<NaysLeaderboardEntry>>(
            key: ValueKey(_subjectId),
            stream: widget.service.watchLeaderboard(subjectId: _subjectId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Could not load leaderboard: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final entries = snapshot.data!;
              if (entries.isEmpty) {
                return const Center(
                  child: Text('No completed examinations are ranked yet.'),
                );
              }
              final uid = FirebaseAuth.instance.currentUser?.uid;
              final ownRank = entries.indexWhere(
                (entry) => entry.userId == uid,
              );
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  const PageHeading(
                    eyebrow: 'REAL EXAM PERFORMANCE',
                    title: 'Leaderboard',
                    subtitle:
                        'Ranked by average percentage, then completed attempts.',
                  ),
                  if (ownRank >= 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'Your position: #${ownRank + 1}',
                        style: const TextStyle(
                          color: AppTheme.forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  for (var index = 0; index < entries.length; index++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SurfaceCard(
                        color: entries[index].userId == uid
                            ? const Color(0xFFE8F1EB)
                            : null,
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundImage: entries[index].avatarUrl.isEmpty
                                ? null
                                : NetworkImage(entries[index].avatarUrl),
                            child: entries[index].avatarUrl.isEmpty
                                ? Text('${index + 1}')
                                : null,
                          ),
                          title: Text(entries[index].displayName),
                          subtitle: Text(
                            '${entries[index].totalExams} completed examinations',
                          ),
                          trailing: Text(
                            '${entries[index].averagePercentage.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AppTheme.forest,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    ),
  );
}
