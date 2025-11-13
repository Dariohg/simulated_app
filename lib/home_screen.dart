import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma Educativa'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Bienvenido, Alumno',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.history_edu_rounded, color: Colors.blue),
              title: const Text('Lección 1: Historia de la IA'),
              subtitle: const Text('Duración: 20 min'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded),
              onTap: () {
                // Al tocar, navegamos a la pantalla de la lección
                Navigator.pushNamed(context, '/lesson');
              },
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.calculate_rounded, color: Colors.grey),
              title: const Text('Lección 2: Matemáticas (Bloqueado)'),
              subtitle: const Text('Duración: 30 min'),
              onTap: null, // Deshabilitado
            ),
          ),
        ],
      ),
    );
  }
}