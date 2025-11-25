import 'package:flutter_test/flutter_test.dart';
import 'package:gofi/utils/converters.dart';

void main() {
  group('UnitConverter Tests', () {
    
    test('Powinien poprawnie wyświetlać wagę w systemie metrycznym (bez zmian)', () {
      final converter = UnitConverter(unitSystem: 'metric');
      
      // 100 kg -> 100 kg
      expect(converter.displayWeight(100.0), 100.0);
      // Zaokrąglanie
      expect(converter.displayWeight(80.56), 80.6);
    });

    test('Powinien poprawnie konwertować KG na LBS (system imperialny)', () {
      final converter = UnitConverter(unitSystem: 'imperial');
      
      // 1 kg ~ 2.20462 lbs. 
      // 10 kg -> 22.0 lbs (zaokrąglone do 1 miejsca)
      expect(converter.displayWeight(10.0), 22.0);
      
      // 100 kg -> 220.5 lbs
      expect(converter.displayWeight(100.0), 220.5);
    });

    test('Powinien poprawnie przeliczać LBS na KG przy zapisie do bazy', () {
      final converter = UnitConverter(unitSystem: 'imperial');
      
      // Użytkownik wpisuje 220.5 lbs
      // Oczekujemy ok. 100 kg w bazie
      final saved = converter.saveWeight(220.5);
      
      // Używamy "moreOrLessEquals" bo operacje zmiennoprzecinkowe mogą mieć drobne odchylenia
      expect(saved, closeTo(100.0, 0.1));
    });

    test('Powinien zwracać poprawną etykietę', () {
      expect(UnitConverter(unitSystem: 'metric').unitLabel, 'kg');
      expect(UnitConverter(unitSystem: 'imperial').unitLabel, 'lbs');
    });
  });
}