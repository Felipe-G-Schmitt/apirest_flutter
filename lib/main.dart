import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Consulta CEP e Posts',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _paginas = const [
    CepPage(),
    PostsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _paginas[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Consultar CEP',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'Posts',
          ),
        ],
      ),
    );
  }
}

class Endereco {
  final String cep;
  final String logradouro;
  final String bairro;
  final String localidade;
  final String uf;

  Endereco({
    required this.cep,
    required this.logradouro,
    required this.bairro,
    required this.localidade,
    required this.uf,
  });

  factory Endereco.fromJson(Map<String, dynamic> json) {
    return Endereco(
      cep: json['cep'] as String? ?? '',
      logradouro: json['logradouro'] as String? ?? '',
      bairro: json['bairro'] as String? ?? '',
      localidade: json['localidade'] as String? ?? '',
      uf: json['uf'] as String? ?? '',
    );
  }
}

Future<Endereco> buscarCep(String cep) async {
  final uri = Uri.parse('https://viacep.com.br/ws/$cep/json/');

  http.Response response;

  try {
    response = await http.get(uri).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    throw Exception('Tempo limite excedido. Verifique sua conexão.');
  } catch (e) {
    throw Exception('Sem conexão com a internet.');
  }

  if (response.statusCode != 200) {
    throw Exception('Erro do servidor: ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;

  if (json.containsKey('erro')) {
    throw Exception('CEP não encontrado.');
  }

  return Endereco.fromJson(json);
}

class CepPage extends StatefulWidget {
  const CepPage({super.key});

  @override
  State<CepPage> createState() => _CepPageState();
}

class _CepPageState extends State<CepPage> {
  final _cepController = TextEditingController();

  bool _isLoading = false;
  String? _erro;
  Endereco? _endereco;

  @override
  void dispose() {
    _cepController.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final cep = _cepController.text.trim();

    if (cep.length != 8 || int.tryParse(cep) == null) {
      setState(() {
        _erro = 'O CEP deve ter exatamente 8 dígitos numéricos.';
        _endereco = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _erro = null;
      _endereco = null;
    });

    try {
      final resultado = await buscarCep(cep);
      setState(() => _endereco = resultado);
    } catch (e) {
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultar CEP'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _cepController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: const InputDecoration(
                labelText: 'CEP',
                hintText: 'Ex: 89201900',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _buscar(),
            ),
            const SizedBox(height: 12),

            ElevatedButton(
              onPressed: _isLoading ? null : _buscar,
              child: const Text('Buscar'),
            ),
            const SizedBox(height: 20),

            if (_isLoading) const Center(child: CircularProgressIndicator()),

            if (_erro != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  border: Border.all(color: Colors.red.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _erro!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),

            if (_endereco != null) ...[
              const SizedBox(height: 8),
              _CampoResultado(label: 'CEP', valor: _endereco!.cep),
              _CampoResultado(label: 'Logradouro', valor: _endereco!.logradouro),
              _CampoResultado(label: 'Bairro', valor: _endereco!.bairro),
              _CampoResultado(label: 'Cidade', valor: _endereco!.localidade),
              _CampoResultado(label: 'UF', valor: _endereco!.uf),
            ],
          ],
        ),
      ),
    );
  }
}

class _CampoResultado extends StatelessWidget {
  final String label;
  final String valor;

  const _CampoResultado({required this.label, required this.valor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: TextEditingController(text: valor),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade100,
        ),
      ),
    );
  }
}

class Post {
  final int id;
  final String title;
  final String body;

  Post({required this.id, required this.title, required this.body});

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }
}

Future<List<Post>> fetchPosts() async {
  final uri = Uri.https('jsonplaceholder.typicode.com', '/posts');

  http.Response response;

  try {
    response = await http.get(uri).timeout(const Duration(seconds: 10));
  } on TimeoutException {
    throw Exception('Tempo limite excedido. Verifique sua conexão.');
  } catch (e) {
    throw Exception('Sem conexão com a internet.');
  }

  if (response.statusCode != 200) {
    throw Exception('Erro do servidor: ${response.statusCode}');
  }

  final data = jsonDecode(response.body) as List<dynamic>;
  return data
      .map((item) => Post.fromJson(item as Map<String, dynamic>))
      .toList();
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});

  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  late Future<List<Post>> _postsFuture;

  @override
  void initState() {
    super.initState();
    _postsFuture = fetchPosts();
  }

  void _recarregar() {
    setState(() => _postsFuture = fetchPosts());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Posts'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _recarregar,
            tooltip: 'Recarregar',
          ),
        ],
      ),
      body: FutureBuilder<List<Post>>(
        future: _postsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off, size: 48, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      snapshot.error
                          .toString()
                          .replaceFirst('Exception: ', ''),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _recarregar,
                      child: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            );
          }

          final posts = snapshot.data ?? [];
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _postsFuture = fetchPosts());
              await _postsFuture;
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: posts.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final post = posts[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(post.id.toString())),
                  title: Text(post.title),
                  subtitle: Text(
                    post.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}