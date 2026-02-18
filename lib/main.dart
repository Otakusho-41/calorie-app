
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CalorieApp());
}

class CalorieApp extends StatelessWidget {
  const CalorieApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Calorias - Contador',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const HomePage(),
    );
  }
}

class FoodDefinition {
  final String name;
  final String type; // per_100g, per_unit, per_100ml
  final double value; // kcal

  FoodDefinition({required this.name, required this.type, required this.value});

  factory FoodDefinition.fromJson(Map<String, dynamic> j) => FoodDefinition(
      name: j['name'], type: j['type'], value: (j['value'] as num).toDouble());
}

class FoodItem {
  String name;
  double amount;
  String unit;
  double calories;

  FoodItem({required this.name, required this.amount, required this.unit, required this.calories});

  Map<String, dynamic> toJson() => {
        'name': name,
        'amount': amount,
        'unit': unit,
        'calories': calories,
      };

  factory FoodItem.fromJson(Map<String, dynamic> j) => FoodItem(
      name: j['name'],
      amount: (j['amount'] as num).toDouble(),
      unit: j['unit'],
      calories: (j['calories'] as num).toDouble());
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController amountController = TextEditingController(text: '100');
  String unit = 'g';
  List<String> units = ['mg','g','kg','ml','L','un','slice','cup','tbsp','tsp','oz','lb'];
  List<FoodDefinition> foodDb = [];
  List<FoodItem> items = [];
  List<FoodItem> savedMenu = [];

  @override
  void initState() {
    super.initState();
    loadFoodDb();
    loadSavedMenu();
  }

  Future<void> loadFoodDb() async {
    final data = await rootBundle.loadString('assets/foods.json');
    final List<dynamic> list = jsonDecode(data);
    setState(() {
      foodDb = list.map((e) => FoodDefinition.fromJson(e)).toList();
    });
  }

  double unitToGramsFactor(String unit) {
    switch(unit) {
      case 'mg': return 0.001;
      case 'g': return 1.0;
      case 'kg': return 1000.0;
      case 'oz': return 28.3495;
      case 'lb': return 453.592;
      default: return 1.0;
    }
  }

  double unitToMlFactor(String unit) {
    switch(unit) {
      case 'ml': return 1.0;
      case 'L': return 1000.0;
      default: return 1.0;
    }
  }

  // Find best matching food definition by name (simple contains, case-insensitive)
  FoodDefinition? findFoodDef(String name) {
    final q = name.toLowerCase().trim();
    for (final f in foodDb) {
      if (f.name.toLowerCase().contains(q)) return f;
    }
    return null;
  }

  double calculateCaloriesFromDef(FoodDefinition def, double amount, String unit) {
    // def.type: per_100g, per_unit, per_100ml
    if (def.type == 'per_unit') {
      // calories per unit stored (e.g., 1 banana = 89 kcal)
      return def.value * amount;
    } else if (def.type == 'per_100ml') {
      // value per 100ml
      final ml = amount * unitToMlFactor(unit);
      return (def.value/100.0) * ml;
    } else {
      // assume per_100g
      final grams = amount * unitToGramsFactor(unit);
      return (def.value/100.0) * grams;
    }
  }

  Future<void> addItem() async {
    final name = nameController.text.trim();
    if (name.isEmpty) return;
    final amt = double.tryParse(amountController.text.replaceAll(',', '.')) ?? 0.0;
    if (amt <= 0) return;
    final def = findFoodDef(name);
    double kcal = 0.0;
    if (def != null) {
      kcal = calculateCaloriesFromDef(def, amt, unit);
    } else {
      // If not found, ask user to input kcal per unit or per 100g
      final manual = await showDialog<double>(context: context, builder: (c) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Alimento não encontrado'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Insira calorias do alimento (kcal) correspondentes à quantidade informada'), 
            TextField(controller: ctrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'kcal')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancelar')),
            TextButton(onPressed: () {
              final v = double.tryParse(ctrl.text.replaceAll(',', '.'));
              Navigator.pop(c, v);
            }, child: const Text('OK')),
          ],
        );
      });
      if (manual == null) return;
      kcal = manual;
    }

    final item = FoodItem(name: name, amount: amt, unit: unit, calories: kcal);
    setState(() {
      items.add(item);
      nameController.clear();
      amountController.text = '100';
    });
  }

  double totalCalories(List<FoodItem> list) => list.fold(0.0, (s, e) => s + e.calories);

  Future<void> saveMenu(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final menusRaw = prefs.getString('menus') ?? '[]';
    final menus = jsonDecode(menusRaw) as List;
    final menu = {
      'title': title,
      'date': DateTime.now().toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
    menus.add(menu);
    await prefs.setString('menus', jsonEncode(menus));
    await loadSavedMenu();
  }

  Future<void> loadSavedMenu() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('menus') ?? '[]';
    final list = jsonDecode(raw) as List;
    setState(() {
      savedMenu = list.map((m) {
        final itemsJson = (m['items'] as List).cast<Map<String, dynamic>>();
        final first = itemsJson.isNotEmpty ? itemsJson.first : null;
        // store as single FoodItem representing the menu summary (not perfect but for listing)
        return FoodItem(
            name: m['title'] ?? 'Cardápio',
            amount: 0,
            unit: '',
            calories: (itemsJson.fold(0.0, (s, it) => s + (it['calories'] as num).toDouble()))
        );
      }).toList();
    });
  }

  Future<void> deleteMenuAt(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('menus') ?? '[]';
    final list = jsonDecode(raw) as List;
    if (index >=0 && index < list.length) {
      list.removeAt(index);
      await prefs.setString('menus', jsonEncode(list));
      await loadSavedMenu();
    }
  }

  Future<void> showMenuDetails(int index) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('menus') ?? '[]';
    final list = jsonDecode(raw) as List;
    if (index < 0 || index >= list.length) return;
    final menu = list[index];
    final itemsJson = (menu['items'] as List).cast<Map<String, dynamic>>();
    final itemsList = itemsJson.map((e) => FoodItem.fromJson(e)).toList();
    await showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(menu['title'] ?? 'Cardápio'),
      content: SizedBox(width: double.maxFinite, child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Data: ${DateTime.parse(menu['date']).toLocal()}'),
          const SizedBox(height:8),
          ...itemsList.map((it) => ListTile(title: Text(it.name), subtitle: Text('${it.amount}${it.unit} - ${it.calories.toStringAsFixed(2)} kcal')))
        ]),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Fechar'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contador de Calorias')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome do alimento')),
          Row(children: [
            Expanded(child: TextField(controller: amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantidade'))),
            const SizedBox(width:8),
            DropdownButton<String>(value: unit, items: units.map((u) => DropdownMenuItem(value:u, child: Text(u))).toList(), onChanged: (v) => setState((){unit=v!;}))
          ]),
          const SizedBox(height:8),
          Row(children: [
            ElevatedButton.icon(onPressed: addItem, icon: const Icon(Icons.add), label: const Text('Adicionar')),
            const SizedBox(width:8),
            ElevatedButton.icon(onPressed: () async {
              if (items.isEmpty) return;
              final titleCtrl = TextEditingController(text: 'Cardápio ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}');
              final title = await showDialog<String>(context: context, builder: (c) => AlertDialog(
                title: const Text('Salvar Cardápio'),
                content: TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Título')),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, null), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(c, titleCtrl.text), child: const Text('Salvar')),
                ],
              ));
              if (title != null && title.trim().isNotEmpty) await saveMenu(title.trim());
            }, icon: const Icon(Icons.save), label: const Text('Salvar cardápio')),
          ]),
          const SizedBox(height:12),
          const Text('Itens adicionados:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: items.isEmpty ? const Center(child: Text('Nenhum item')) :
            ListView.builder(itemCount: items.length, itemBuilder: (c,i){
              final it = items[i];
              return Slidable(
                key: ValueKey(i),
                endActionPane: ActionPane(motion: const ScrollMotion(), children: [
                  SlidableAction(onPressed: (ctx){ setState(()=>items.removeAt(i)); }, backgroundColor: Colors.red, icon: Icons.delete, label: 'Excluir')
                ]),
                child: ListTile(title: Text(it.name), subtitle: Text('${it.amount}${it.unit} - ${it.calories.toStringAsFixed(2)} kcal')),
              );
            })
          ),
          const SizedBox(height:8),
          Text('Total: ${totalCalories(items).toStringAsFixed(2)} kcal', style: const TextStyle(fontSize:16, fontWeight: FontWeight.bold)),
          const Divider(),
          const Text('Cardápios salvos:', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: savedMenu.isEmpty ? const Center(child: Text('Nenhum cardápio salvo')) :
            ListView.builder(itemCount: savedMenu.length, itemBuilder: (c,i){
              final m = savedMenu[i];
              return ListTile(
                title: Text(m.name),
                subtitle: Text('${m.calories.toStringAsFixed(2)} kcal'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(icon: const Icon(Icons.remove_red_eye), onPressed: () => showMenuDetails(i)),
                  IconButton(icon: const Icon(Icons.delete_forever), onPressed: () => deleteMenuAt(i)),
                ]),
              );
            })
          )
        ]),
      ),
    );
  }
}
