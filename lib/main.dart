import 'package:flutter/material.dart';

import 'auth_api.dart';
import 'auth_screen.dart';

void main() => runApp(const CloudClubApp());

class CloudClubApp extends StatelessWidget {
  const CloudClubApp({super.key, this.authApi});
  final AuthApi? authApi;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cloud Club',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF397FA3)),
        scaffoldBackgroundColor: const Color(0xFFF0F7FC),
      ),
      home: AuthGate(
        api: authApi,
        signedInBuilder: (name, logout) =>
            CloudClubHome(name: name, onLogout: logout),
      ),
    );
  }
}

class CloudObservation {
  const CloudObservation(this.shape, this.note);
  final String shape;
  final String note;
}

class CloudClubHome extends StatefulWidget {
  const CloudClubHome({super.key, this.name, this.onLogout});
  final String? name;
  final VoidCallback? onLogout;

  @override
  State<CloudClubHome> createState() => _CloudClubHomeState();
}

class _CloudClubHomeState extends State<CloudClubHome> {
  final List<CloudObservation> _observations = [];
  int _tab = 0;

  Future<void> _add() async {
    final result = await showModalBottomSheet<CloudObservation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const ObservationForm(),
    );
    if (!mounted || result == null) return;
    setState(() {
      _observations.insert(0, result);
      _tab = 1;
    });
  }

  void _delete(CloudObservation observation) {
    final index = _observations.indexOf(observation);
    setState(() => _observations.remove(observation));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Removed "${observation.shape}"'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => setState(() {
              final position = index < _observations.length
                  ? index
                  : _observations.length;
              _observations.insert(position, observation);
            }),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Cloud Club' : 'My Collection'),
        actions: [
          if (widget.onLogout != null)
            IconButton(
              tooltip: 'Log out',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 100),
              children: _tab == 0 ? _home(context) : _collection(context),
            ),
          ),
        ),
      ),
      floatingActionButton: _tab == 1
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('New spotting'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (value) => setState(() => _tab = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark_outlined),
            label: 'Collection',
          ),
        ],
      ),
    );
  }

  List<Widget> _home(BuildContext context) => [
    if (widget.name != null) Text('Hello, ${widget.name}!'),
    const Icon(Icons.cloud_outlined, size: 100, color: Color(0xFF397FA3)),
    const SizedBox(height: 24),
    Text('What do you see?', style: Theme.of(context).textTheme.headlineLarge),
    const SizedBox(height: 12),
    const Text(
      'A sleeping dragon? A whale in the sky? Look up and '
      'record your own cloud discovery.',
    ),
    const SizedBox(height: 24),
    FilledButton.icon(
      onPressed: _add,
      icon: const Icon(Icons.add),
      label: const Text('Record a cloud spotting'),
    ),
    const SizedBox(height: 12),
    const Text(
      'Entries last for this session and disappear when the app '
      'restarts. Photos and AI guesses are coming later.',
    ),
    const SizedBox(height: 32),
    Text('A little inspiration', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    const Text(
      'Look for an animal, a familiar object, or a scene from '
      'a story. There is no wrong answer.',
    ),
    const SizedBox(height: 32),
    Text('Your discoveries', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 8),
    Text(
      _observations.isEmpty
          ? 'Your first cloud story starts with a glance at the sky.'
          : '${_observations.length} cloud '
                '${_observations.length == 1 ? 'spotting' : 'spottings'} '
                'recorded this session.',
    ),
    if (_observations.isNotEmpty)
      TextButton(
        onPressed: () => setState(() => _tab = 1),
        child: const Text('Open my collection'),
      ),
  ];

  List<Widget> _collection(BuildContext context) => [
    const Text('Your cloud stories, collected one glance at a time.'),
    const SizedBox(height: 8),
    const Text('Session only: entries disappear when the app restarts.'),
    const SizedBox(height: 24),
    if (_observations.isEmpty) ...[
      const Icon(Icons.cloud_queue, size: 80, color: Color(0xFF397FA3)),
      const SizedBox(height: 16),
      Text(
        'A sky full of possibilities',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text(
        'Record what a cloud looks like to start your collection.',
        textAlign: TextAlign.center,
      ),
    ],
    for (final observation in _observations)
      Card(
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: const Icon(Icons.cloud_outlined),
          title: Text(observation.shape),
          subtitle: observation.note.isEmpty ? null : Text(observation.note),
          trailing: IconButton(
            tooltip: 'Delete spotting',
            onPressed: () => _delete(observation),
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      ),
  ];
}

class ObservationForm extends StatefulWidget {
  const ObservationForm({super.key});

  @override
  State<ObservationForm> createState() => _ObservationFormState();
}

class _ObservationFormState extends State<ObservationForm> {
  final _formKey = GlobalKey<FormState>();
  final _shape = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _shape.dispose();
    _note.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context)
        .pop(CloudObservation(_shape.text.trim(), _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What did you spot?',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Give your cloud a shape and a little story.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _shape,
                autofocus: true,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Cloud shape',
                  hintText: 'A sleeping dragon',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter the shape you see.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 300,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Its tail stretched across the evening sky.',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _save,
                child: const Text('Add to collection'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
