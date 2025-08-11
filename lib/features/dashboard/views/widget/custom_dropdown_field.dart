import 'package:flutter/material.dart';
import 'package:warehouse_data_autosync/core/constants/constants.dart';

class CustomDropdownField extends StatelessWidget {
  final String hint;
  final String? value;
  final List<Map<String, dynamic>> items;
  final ValueChanged<String?> onChanged;
  final bool isLoading;
  final double maxTextWidthFactor;

  const CustomDropdownField({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isLoading = false,
    this.maxTextWidthFactor = 0.7,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      hint: Text(hint),
      decoration: InputDecoration(
        labelText: hint,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
      items: items.map((doc) {
        final name = (doc[YStrings.colName] ?? '').toString().trim();
        final id = (doc[YStrings.colId] ?? '').toString();
        return DropdownMenuItem<String>(
          value: id.isNotEmpty ? id : null,
          child: Tooltip(
            message: name.isNotEmpty ? name : 'No name',
            waitDuration: const Duration(milliseconds: 500),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * maxTextWidthFactor,
              child: Text(
                name.isNotEmpty ? name : 'Unnamed',
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                softWrap: false,
                style: name.isNotEmpty
                    ? null
                    : const TextStyle(
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
              ),
            ),
          ),
        );
      }).toList(),
      onChanged: isLoading ? null : onChanged,
    );
  }

  String _shortenName(String text, {int maxLength = 30}) {
    text = text.trim();
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength ~/ 2)}...${text.substring(text.length - maxLength ~/ 2)}';
  }
}
