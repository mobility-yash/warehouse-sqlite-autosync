part of 'constants.dart';

class YArrays {
  YArrays._();

  static const List<String> allTables = [
    YStrings.locations,
    YStrings.warehouses,
    YStrings.items,
    YStrings.notifications,
  ];

  static const List<String> locationDummyNames = [
    'Mumbai',
    'Pune',
    'Delhi',
    'Bengaluru',
    'Chennai',
    'Kolkata',
    'Hyderabad',
    'Jaipur',
    'Ahmedabad',
    'Surat',
  ];

  static const List<String> itemDummyNames = [
    'Rice',
    'Wheat',
    'Sugar',
    'Salt',
    'Oil',
    'Spices',
    'Tea',
    'Coffee',
    'Flour',
    'Lentils',
    'Beans',
    'Milk',
    'Butter',
    'Ghee',
    'Biscuits',
    'Soap',
    'Shampoo',
    'Toothpaste',
    'Detergent',
    'Snacks',
    'Juice',
    'Water',
  ];

  static const List<String> warehouseDummyPrefixes = [
    'Central Depot',
    'Main Storage Facility',
    'Distribution Hub',
    'Logistics Center',
    'North Block Storage',
    'Regional Stockyard',
    'Goods Handling Unit',
    'Urban Delivery Base',
    'Rural Supplies Depot',
    'Bulk Storage Area',
  ];

  static const List<String> warehouseDummySuffixes = [
    'for Dry Goods',
    'and Packaged Food',
    'Handling Agricultural Stock',
    'Near Industrial Area',
    'Behind Main Market',
    'Close to Railway Yard',
    'Next to Wholesale Market',
    'inside Commercial Complex',
    'for Essential Commodities',
    'of FMCG Distribution',
  ];
}
