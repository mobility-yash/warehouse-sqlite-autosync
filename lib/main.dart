import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'core/bindings/app_bindings.dart';
import 'presentation/home/home_screen.dart';
import 'presentation/oprations/operations_screen.dart';
import 'presentation/splash/splash_screen.dart';
import 'presentation/sync/sync_screen.dart';

// Define YASH colors
const deepBlue = Color(0xFF16559c);
const yashRed = Color(0xFFe72d23);
const lightBlue = Color(0xFF6ec5fa);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const WarehouseApp());
}

class WarehouseApp extends StatelessWidget {
  const WarehouseApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Warehouse App',
      theme: ThemeData(
        primaryColor: deepBlue,
        appBarTheme: const AppBarTheme(
          backgroundColor: deepBlue,
          foregroundColor: Colors.white,
          elevation: 2,
        ),
        colorScheme: ColorScheme.fromSwatch(
          primarySwatch: Colors.blue,
          accentColor: yashRed,
          backgroundColor: Colors.white,
          cardColor: const Color(0xFFF5F7FA),
        ).copyWith(secondary: yashRed),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: deepBlue,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: yashRed,
          foregroundColor: Colors.white,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialBinding: AppBindings(),
      initialRoute: '/splash',
      getPages: [
        GetPage(name: '/splash', page: () => SplashScreen()),
        GetPage(name: '/sync', page: () => SyncScreen()),
        GetPage(name: '/home', page: () => HomeScreen()),
        GetPage(name: '/operations', page: () => OperationsScreen()),
      ],
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
//
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const PopulateFirestoreApp());
// }
//
// class PopulateFirestoreApp extends StatelessWidget {
//   const PopulateFirestoreApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Populate Firestore',
//       theme: ThemeData(primarySwatch: Colors.blue),
//       home: const PopulateItemsPage(),
//     );
//   }
// }
//
// class PopulateItemsPage extends StatefulWidget {
//   const PopulateItemsPage({super.key});
//
//   @override
//   _PopulateItemsPageState createState() => _PopulateItemsPageState();
// }
//
// class _PopulateItemsPageState extends State<PopulateItemsPage> {
//   final CollectionReference itemsCollection =
//   FirebaseFirestore.instance.collection('items');
//
//   final List<Map<String, dynamic>> sampleItems = [
//     {'name': 'Rice', 'quantity': 150},
//     {'name': 'Sugar', 'quantity': 75},
//     {'name': 'Wheat Flour', 'quantity': 100},
//     {'name': 'Cooking Oil', 'quantity': 50},
//     {'name': 'Salt', 'quantity': 200},
//     {'name': 'Lentils', 'quantity': 120},
//     {'name': 'Butter', 'quantity': 80},
//     {'name': 'Tea Leaves', 'quantity': 60},
//     {'name': 'Coffee Beans', 'quantity': 40},
//     {'name': 'Paper Towels', 'quantity': 90},
//     {'name': 'Detergent Powder', 'quantity': 110},
//     {'name': 'Toothpaste', 'quantity': 130},
//   ];
//
//   String statusMessage = "Press the button to populate items.";
//
//   @override
//   void initState() {
//     super.initState();
//     _populateItems();
//   }
//
//   Future<void> _populateItems() async {
//     setState(() {
//       statusMessage = "Populating items...";
//     });
//
//     try {
//       for (final item in sampleItems) {
//         // Use item name as doc ID so duplicates are prevented
//         await itemsCollection.doc(item['name']).set({
//           'name': item['name'],
//           'quantity': item['quantity'],
//           'lastFirebaseModified': DateTime.now().toIso8601String(),
//         });
//       }
//       setState(() {
//         statusMessage = "Items successfully populated in Firestore.";
//       });
//     } catch (e) {
//       setState(() {
//         statusMessage = "Failed to populate items: $e";
//       });
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Populate Firestore Items'),
//       ),
//       body: Center(
//         child: Padding(
//           padding: const EdgeInsets.all(24.0),
//           child: Text(
//             statusMessage,
//             textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 18),
//           ),
//         ),
//       ),
//     );
//   }
// }
