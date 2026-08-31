import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrack/models/asset.dart';
import 'package:lifetrack/models/liability.dart';

void main() {
  test('asset stores the entered name and value', () {
    const asset = Asset(
      name: 'Laptop',
      type: 'Other',
      value: 25000,
      updatedAt: '2026-08-27T00:00:00.000Z',
    );

    expect(asset.toMap()['name'], 'Laptop');
    expect(asset.toMap()['value'], 25000);
    expect(asset.toMap()['updated_at'], '2026-08-27T00:00:00.000Z');
  });

  test('liability stores the entered name and amount', () {
    const liability = Liability(
      name: 'Phone loan',
      type: 'Other',
      amount: 12000,
      updatedAt: '2026-08-27T00:00:00.000Z',
    );

    expect(liability.toMap()['name'], 'Phone loan');
    expect(liability.toMap()['amount'], 12000);
    expect(
      liability.toMap()['updated_at'],
      '2026-08-27T00:00:00.000Z',
    );
  });
}
